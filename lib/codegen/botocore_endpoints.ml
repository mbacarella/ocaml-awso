open! Import

(* Warning 30 complains if we have 'defaults' in multiple fields. *)
[@@@warning "-30"]

type credentialScope =
  { region : Region.t option
  ; service : string option
  }

type uri_token =
  [ `String_token of string
  | `Service_token
  | `Region_token
  | `DnsSuffix_token
  ]

type uri_pattern = uri_token list

type variant =
  { dnsSuffix : string option
  ; hostname : uri_pattern option
  ; tags : string list
  }

type properties =
  { credentialScope : credentialScope option
  ; hostname : uri_pattern option
  ; protocols : string list option
  ; sslCommonName : string option
  ; signatureVersions : [ `v2 | `v3 | `v4 | `s3 | `s3v4 ] list option
  ; variants : variant list option
  ; deprecated : bool option
  ; dnsSuffix : string option
  }

type service =
  { defaults : properties option
  ; endpoints : (string * properties) list
  ; isRegionalized : bool option
  ; partitionEndpoint : string option
  }

type region = { description : string }

type partition =
  { defaults : properties option
  ; dnsSuffix : string
  ; partition : string
  ; partitionName : string
  ; regionRegex : string
  ; regions : (string * region) list
  ; services : (string * service) list
  }

type t =
  { partitions : partition list
  ; version : int
  }

module Json0 = struct
  let uri_token buf : (uri_token option, [ `Invalid ]) result =
    match%sedlex buf with
    | "{dnsSuffix}" -> Ok (Some `DnsSuffix_token)
    | "{service}" -> Ok (Some `Service_token)
    | "{region}" -> Ok (Some `Region_token)
    | eof -> Ok None
    | Plus (Compl (Chars "{}")) -> Ok (Some (`String_token (Sedlexing.Latin1.lexeme buf)))
    | _ -> Error `Invalid
  ;;

  let parse_uri s =
    match Util.tokenize uri_token s with
    | Ok _ as x -> x
    | Error `Invalid -> Result.failf "Invalid uri: %s" s
  ;;

  (*
let constraint_ =
  Json_parser.parse_with (function
      | `List [ `String "region"; `String op; values ] ->
        let open Result.Let_syntax in
        let%bind op = parse_op op in
        let%bind values = parse_constraint_value values in
        let%map test =
          match op, values with
          | `equals, [ x ] -> Ok (`equals x)
          | `notEquals, [ x ] -> Ok (`notEquals x)
          | `startsWith, [ x ] -> Ok (`startsWith x)
          | `notStartsWith, [ x ] -> Ok (`notStartsWith x)
          | `oneOf, vals -> Ok (`oneOf vals)
          | _ -> Error "Malformed constraint"
        in
        Constraint (`Region, test)
      | `List _ -> Error "Expected array of size 3 starting with 'region' for constraint"
      | _ -> Error "Expected array for constraint")
;;
*)
  let parse_signatureVersion = function
    | "v2" -> Ok `v2
    | "v3" -> Ok `v3
    | "v4" -> Ok `v4
    | "s3" -> Ok `s3
    | "s3v4" -> Ok `s3v4
    | s -> Result.failf "Unknown signatureVersion %s" s
  ;;

  let credential_scope =
    let open Json_parser in
    record
      (let%map region = field_opt "region" (string >>| Region.of_string)
       and service = field_opt "service" string in
       { region; service })
  ;;

  let variant =
    let open Json_parser in
    record
      (let%map dnsSuffix = field_opt "dnsSuffix" string
       and hostname = field_opt "hostname" (map_result string ~f:parse_uri)
       and tags = field "tags" (list string) in
       { dnsSuffix; hostname; tags })
  ;;

  let properties =
    let open Json_parser in
    record
      (let%map signatureVersions =
         field_opt
           "signatureVersions"
           (list (map_result string ~f:parse_signatureVersion))
       and credentialScope = field_opt "credentialScope" credential_scope
       and hostname = field_opt "hostname" (map_result string ~f:parse_uri)
       and protocols = field_opt "protocols" (list string)
       and sslCommonName = field_opt "sslCommonName" string
       and variants = field_opt "variants" (list variant)
       and deprecated = field_opt "deprecated" bool
       and dnsSuffix = field_opt "dnsSuffix" string in
       { credentialScope
       ; hostname
       ; protocols
       ; sslCommonName
       ; signatureVersions
       ; variants
       ; deprecated
       ; dnsSuffix
       })
  ;;

  let region =
    let open Json_parser in
    record
      (let%map description = field "description" string in
       { description })
  ;;

  let endpoint_service =
    let open Json_parser in
    record
      (let%map defaults = field_opt "defaults" properties
       and endpoints = field "endpoints" (dict properties)
       and isRegionalized = field_opt "isRegionalized" bool
       and partitionEndpoint = field_opt "partitionEndpoint" string in
       { defaults; endpoints; isRegionalized; partitionEndpoint })
  ;;

  let partition =
    let open Json_parser in
    record
      (let%map defaults = field_opt "defaults" properties
       and dnsSuffix = field "dnsSuffix" string
       and partition = field "partition" string
       and partitionName = field "partitionName" string
       and regionRegex = field "regionRegex" string
       and regions = field "regions" (dict region)
       and services = field "services" (dict endpoint_service) in
       { defaults; dnsSuffix; partition; partitionName; regionRegex; regions; services })
  ;;
end

let of_json x =
  let t =
    x
    |> Yojson.Safe.from_string
    |> Json_parser.run_exn
         (let open Json_parser in
          record
            (let%map partitions = field "partitions" (list Json0.partition)
             and version = field "version" int in
             { partitions; version }))
  in
  let () =
    match t.version with
    | 3 -> ()
    | _ -> failwithf "unexpected version: %d" t.version ()
  in
  t
;;

module Endpoint_rules_for_precompute = struct
  module Botodata = Botodata

  let str_regexp = Memo.general Re.Perl.compile_pat

  let lookup_partition =
    Memo.general (fun (ep, region) ->
      let region_s = Region.to_string region in
      match
        List.find ep.partitions ~f:(fun partition ->
          let rex = str_regexp partition.regionRegex in
          Option.is_some (Re.exec_opt rex region_s))
      with
      | None -> failwithf "no partition found for region: %s" (Region.to_string region) ()
      | Some partition -> partition)
  ;;

  (* FIXME: botocore stopped putting newer services in endpoints.json and now
     ships a per-service endpoint-rule-set-1.json that encodes hostnames as a
     conditional tree (region/partition/fips/dualstack -> url). Maybe *somebody*
     can writes a rule enginelet for that. In the meantime we hand-patch the
     odd services whose hostname doesn't start with [endpointPrefix],
     since there are no DNS entries for those. *)
  let endpoint_prefix_shim = function
    | "sso" -> "portal.sso"
    | "geo-places" -> "places.geo"
    | "geo-maps" -> "maps.geo"
    | "geo-routes" -> "routes.geo"
    | "iot-data" -> "data.ats.iot"
    | s -> s
  ;;

  let lookup_service_properties_memo =
    Memo.general (fun (region, service, (partition : partition)) ->
      let region_s = Region.to_string region in
      let service_s = Service.to_string service in
      let service_s = endpoint_prefix_shim service_s in
      match
        List.find partition.services ~f:(fun (service_name, _service_spec) ->
          String.( = ) service_name service_s)
      with
      | None -> None, None
      | Some (_service_name, service_spec) -> (
        let service_defaults = service_spec.defaults in
        let match_endpoint =
          match service_spec.isRegionalized with
          | None | Some false -> "aws-global"
          | Some true -> region_s
        in
        match
          List.find service_spec.endpoints ~f:(fun (endpoint, _properties) ->
            String.( = ) match_endpoint endpoint)
        with
        | None -> service_defaults, None
        | Some (_endpoint, properties) -> service_defaults, Some properties))
  ;;

  let lookup_service_properties ~region ~service ~partition =
    lookup_service_properties_memo (region, service, partition)
  ;;

  let lookup_credential_scope ep ~region:orig_region service =
    let partition = lookup_partition (ep, orig_region) in
    let credential_scope =
      match lookup_service_properties ~partition ~service ~region:orig_region with
      | _, None -> None
      | _, Some properties -> properties.credentialScope
    in
    (match credential_scope with
     | None -> orig_region
     | Some { region = None; service = _ } -> orig_region
     | Some { region = Some region; service = _ } -> region)
    |> Region.to_string
  ;;

  let lookup_uri ep ~scheme ~region ~service =
    let service_s = Service.to_string service in
    let service_s = endpoint_prefix_shim service_s in
    let partition = lookup_partition (ep, region) in
    let partition_hostname =
      let partition_defaults =
        Option.value_exn
          partition.defaults
          ~message:(sprintf "no defaults for %s" partition.partitionName)
      in
      match partition_defaults.hostname with
      | None | Some [] ->
        failwithf "no default hostname schema for partition %s" partition.partitionName ()
      | Some hostname -> Some hostname
    in
    let service_properties = lookup_service_properties ~partition ~service ~region in
    let service_hostname =
      match service_properties with
      | Some service_defaults, None -> service_defaults.hostname
      | Some _, Some { hostname = Some hostname; _ } -> Some hostname
      | Some service_defaults, Some { hostname = None; _ } -> service_defaults.hostname
      | None, Some { hostname = Some hostname; _ } -> Some hostname
      | None, Some { hostname = None; _ } -> None
      | None, None -> None
    in
    let dns_suffix =
      match service_properties with
      | _, Some endpoint_props when Option.is_some endpoint_props.dnsSuffix ->
        Option.value_exn endpoint_props.dnsSuffix
      | Some service_defaults, _ when Option.is_some service_defaults.dnsSuffix ->
        Option.value_exn service_defaults.dnsSuffix
      | _ -> partition.dnsSuffix
    in
    let scheme =
      match scheme with
      | `HTTP -> "http"
      | `HTTPS -> "https"
    in
    let hostname =
      match service_hostname, partition_hostname with
      | Some h, _ -> h
      | None, Some h -> h
      | _, None -> assert false
    in
    let host =
      List.map hostname ~f:(function
        | `String_token s -> s
        | `Service_token -> service_s
        | `Region_token -> Region.to_string region
        | `DnsSuffix_token -> dns_suffix)
    in
    String.concat (scheme :: "://" :: host) ~sep:""
  ;;
end

(* You might be tempted to emit this as a big `match` table, but that takes
   minutes to compile due to some kind of quadratic behavior in the compiler with
   really gigantic match blocks. So we simply Memo.general over an a-list search
   instead, which takes seconds to compile and has negligible runtime cost.

   The scheme is split into separate tables to keep the AST literals free of
   polymorphic variants which the compiler might be unusually slow to
   unify in bulk. *)
let make_lookup_uri ep =
  let loc = !Ast_helper.default_loc in
  let pairs_for_scheme scheme =
    List.concat_map Region.all ~f:(fun region ->
      List.concat_map Service.all ~f:(fun service ->
        let uri = Endpoint_rules_for_precompute.lookup_uri ep ~scheme ~region ~service in
        [ (Region.to_string region, Service.to_string service), uri ]))
  in
  let entry_e ((region, service), uri) =
    Ast_convenience.tuple
      [ Ast_convenience.tuple [ Ast_convenience.str region; Ast_convenience.str service ]
      ; Ast_convenience.str uri
      ]
  in
  let list_e pairs = Ast_convenience.list (List.map pairs ~f:entry_e) in
  let http_list_e = list_e (pairs_for_scheme `HTTP) in
  let https_list_e = list_e (pairs_for_scheme `HTTPS) in
  [ [%stri
      let endpoint_uri_table_http : ((string * string) * string) list = [%e http_list_e]]
  ; [%stri
      let endpoint_uri_table_https : ((string * string) * string) list = [%e https_list_e]]
  ; [%stri
      let endpoint_uri_lookup =
        Memo.general (fun (scheme, key) ->
          let table =
            match scheme with
            | `HTTPS -> endpoint_uri_table_https
            | `HTTP -> endpoint_uri_table_http
          in
          List.Assoc.find table key ~equal:(fun (r1, s1) (r2, s2) ->
            String.equal r1 r2 && String.equal s1 s2))
      ;;]
  ; [%stri
      let lookup_uri ~region service scheme =
        let region = Region.to_string region in
        let service = Service.to_string service in
        match endpoint_uri_lookup (scheme, (region, service)) with
        | Some uri -> Uri.of_string uri
        | None ->
          let scheme_s =
            match scheme with
            | `HTTPS -> "https"
            | `HTTP -> "http"
          in
          failwithf "unknown endpoint for %s %s, %s" scheme_s region service ()
      ;;]
  ]
;;

let make_lookup_credential_scope ep =
  let loc = !Ast_helper.default_loc in
  let scope_pairs =
    List.concat_map Region.all ~f:(fun region ->
      List.concat_map Service.all ~f:(fun service ->
        let credential_scope =
          Endpoint_rules_for_precompute.lookup_credential_scope ep ~region service
        in
        [ (Region.to_string region, Service.to_string service), credential_scope ]))
  in
  let entry_e ((region, service), scope) =
    Ast_convenience.tuple
      [ Ast_convenience.tuple [ Ast_convenience.str region; Ast_convenience.str service ]
      ; Ast_convenience.str scope
      ]
  in
  let scope_list_e = Ast_convenience.list (List.map scope_pairs ~f:entry_e) in
  [ [%stri
      let credential_scope_table : ((string * string) * string) list = [%e scope_list_e]]
  ; [%stri
      let credential_scope_lookup =
        Memo.general (fun key ->
          List.Assoc.find credential_scope_table key ~equal:(fun (r1, s1) (r2, s2) ->
            String.equal r1 r2 && String.equal s1 s2))
      ;;]
  ; [%stri
      let lookup_credential_scope ~region service =
        let region = Region.to_string region in
        let service = Service.to_string service in
        match credential_scope_lookup (region, service) with
        | Some s -> Region.of_string s
        | None -> failwithf "unknown credential scope for %s, %s" region service ()
      ;;]
  ]
;;
