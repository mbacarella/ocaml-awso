open! Import

let request_args (service : Botodata.service) (op : Botodata.operation option) =
  let loc = !Ast_helper.default_loc in
  match op with
  | None -> [%expr None, None]
  | Some op -> (
    match op.input with
    | None -> [%expr None, None]
    | Some input -> (
      let find_shape key = List.Assoc.find_exn service.shapes key ~equal:String.equal in
      let input_shape = find_shape input.shape in
      match input_shape with
      | Float_shape _
      | Boolean_shape _
      | Long_shape _
      | Double_shape _
      | Blob_shape _
      | Integer_shape _
      | String_shape _
      | List_shape _
      | Enum_shape _
      | Map_shape _
      | Timestamp_shape _ ->
        failwithj
          ~here:()
          "Expected a Structure_shape"
          input_shape
          Botodata.yojson_of_shape
      | Structure_shape ss -> (
        let streaming_members =
          List.filter ss.members ~f:(fun (_, member) ->
            Option.equal Bool.equal member.streaming (Some true))
        in
        let regular_members =
          List.filter ss.members ~f:(fun (_, member) ->
            match member.location with
            | Some `header -> true
            | Some _ -> false
            | None -> (
              match member.streaming with
              | Some true -> false
              | _ -> true))
        in
        match streaming_members, regular_members with
        | [], [] -> [%expr None, None]
        | _ :: _ :: _, _ ->
          failwithf
            "Rest-json operation '%s' has more than one arg with streaming field on"
            input.shape
            ()
        | _ :: _, _ :: _ ->
          failwithf
            "Rest-json operation '%s' has both streaming field and body members"
            input.shape
            ()
        | [ (field_name, member) ], [] ->
          let field_e =
            Ast_helper.Exp.field
              (Ast_convenience.evar "req")
              (Ast_convenience.lid
                 (input.shape ^ "." ^ Shape.uncapitalized_id field_name))
          in
          let value x =
            Ast_convenience.app
              (Ast_convenience.evar (Shape.capitalized_id member.shape ^ ".to_header"))
              [ x ]
          in
          if Shape.structure_shape_required_field ss field_name
          then Ast_convenience.some (value field_e)
          else
            [%expr
              Option.map [%e field_e] ~f:(fun x -> [%e value (Ast_convenience.evar "x")])]
        | [], members ->
          let header_members, body_members =
            List.partition_tf members ~f:(fun (_field_name, member) ->
              match member.location with
              | Some `header -> true
              | _ -> false)
          in
          let header_values =
            List.map header_members ~f:(fun (field_name, member) ->
              let field_e =
                Ast_helper.Exp.field
                  (Ast_convenience.evar "req")
                  (Ast_convenience.lid
                     (input.shape ^ "." ^ Shape.uncapitalized_id field_name))
              in
              let to_value_e x =
                Ast_convenience.app
                  (Ast_convenience.evar
                     (Shape.capitalized_id member.shape ^ ".to_header"))
                  [ x ]
              in
              let key = Option.value member.locationName ~default:field_name in
              let pair x =
                Ast_convenience.pair (Ast_convenience.str key) (to_value_e x)
              in
              if Shape.structure_shape_required_field ss field_name
              then Ast_convenience.some (pair field_e)
              else
                [%expr
                  Option.map [%e field_e] ~f:(fun x ->
                    [%e pair (Ast_convenience.evar "x")])])
            |> Ast_convenience.list
            |> fun e -> [%expr List.filter_opt [%e e] |> Awso.Http.Headers.of_list]
          in
          let body_values =
            List.map body_members ~f:(fun (field_name, member) ->
              let field_e =
                Ast_helper.Exp.field
                  (Ast_convenience.evar "req")
                  (Ast_convenience.lid
                     (input.shape ^ "." ^ Shape.uncapitalized_id field_name))
              in
              let to_value_e x =
                Ast_convenience.app
                  (Ast_convenience.evar (Shape.capitalized_id member.shape ^ ".to_value"))
                  [ x ]
              in
              let key = Option.value member.locationName ~default:field_name in
              let pair x =
                Ast_convenience.pair (Ast_convenience.str key) (to_value_e x)
              in
              if Shape.structure_shape_required_field ss field_name
              then Ast_convenience.some (pair field_e)
              else
                [%expr
                  Option.map [%e field_e] ~f:(fun x ->
                    [%e pair (Ast_convenience.evar "x")])])
            |> Ast_convenience.list
            |> fun e -> [%expr List.filter_opt [%e e]]
          in
          [%expr
            let headers = Some [%e header_values] in
            let body =
              Some
                (`Assoc
                   (List.map [%e body_values] ~f:(fun (x, y) ->
                      let value = Awso.Botodata.Json.value_to_json_scalar y in
                      x, value))
                |> Awso.Json.to_string)
            in
            headers, body])))
;;

let to_request service data =
  let loc = !Ast_helper.default_loc in
  let e =
    data
    |> Endpoint.cases ~f:(fun endpoint ->
         match Endpoint.payload endpoint with
         | None -> (
           match Endpoint.meth endpoint with
           | `GET | `POST ->
             [%expr
               let headers, body = [%e request_args service (Endpoint.op endpoint)] in
               Awso.Http.Request.make ?headers ?body (method_of_endpoint endp)]
           | _ -> [%expr Awso.Http.Request.make (method_of_endpoint endp)])
         | Some payload ->
           Payload.convert_rest_json
             payload
             ~service
             ~op:(Endpoint.op endpoint)
             ~endpoint_name:(Endpoint.name endpoint)
             [%expr req])
    |> Ast_helper.Exp.match_ [%expr endp]
  in
  [%stri
    let to_request (type i o e) (endp : (i, o, e) t) (req : i) =
      let _req = req in
      [%e e]
    ;;]
;;

(*
let%expect_test "to_request" =
  let optional_blob =
    Payload.create
      ~is_blob:true
      ~payload_module:"OptionalBlobModule"
      ~field_name:"optional_blob_field"
      ~is_required:false
  in
  let optional_json =
    Payload.create
      ~is_blob:false
      ~payload_module:"OptionalXmlModule"
      ~field_name:"optional_xml_field"
      ~is_required:false
  in
  let required_blob =
    Payload.create
      ~is_blob:true
      ~payload_module:"RequiredBlobModule"
      ~field_name:"required_blob_field"
      ~is_required:true
  in
  let required_json =
    Payload.create
      ~is_blob:false
      ~payload_module:"RequiredXmlModule"
      ~field_name:"required_xml_field"
      ~is_required:true
  in
  [ Endpoint.create_test "NoPayload" ~payload:None
  ; Endpoint.create_test "OptionalBlobPayload" ~payload:(Some optional_blob)
  ; Endpoint.create_test "OptionalXmlPayload" ~payload:(Some optional_json)
  ; Endpoint.create_test "RequiredBlobPayload" ~payload:(Some required_blob)
  ; Endpoint.create_test "RequiredXmlPayload" ~payload:(Some required_json)
  ]
  |> to_request
  |> List.return
  |> Util.structure_to_string
  |> printf "%s%!";
  [%expect {||}]
;;
*)

let of_response data =
  let loc = !Ast_helper.default_loc in
  let body =
    data
    |> Endpoint.cases ~f:(fun endpoint ->
         let error_of_json =
           Service_endpoints_common.make_error_expression
             ~loc
             ~label:"error_of_json"
             endpoint
         in
         match Endpoint.result_decoder endpoint with
         | None -> [%expr Ok ()]
         | Some Xml -> assert false
         | Some Json ->
           let of_json =
             Endpoint.in_result_module endpoint "of_json"
             |> Option.value_exn
                  ~message:"no result module"
                  ~error:"no result module for endpoint"
           in
           [%expr
             match resp with
             | Error err -> handle_error err [%e error_of_json]
             | Ok resp -> Ok ([%e of_json] (response_to_json resp))]
         | Some (Of_header_and_body payload_opt) -> (
           let of_header_and_body =
             Endpoint.in_result_module endpoint "of_header_and_body"
             |> Option.value_exn
                  ~message:"no result module"
                  ~error:"no result module for endpoint"
           in
           match payload_opt with
           | Some payload ->
             let of_string =
               Printf.ksprintf
                 Ast_convenience.evar
                 "%s.of_string"
                 (Shape.capitalized_id payload)
             in
             [%expr
               match resp with
               | Error err -> handle_error err [%e error_of_json]
               | Ok resp ->
                 let body =
                   [%e of_string] (Awso.Http.Response.body resp)
                 in
                 let headers =
                   Awso.Http.Headers.to_list (Awso.Http.Response.headers resp)
                 in
                 Ok ([%e of_header_and_body] (headers, body))]
           | None ->
             [%expr
               match resp with
               | Error err -> handle_error err [%e error_of_json]
               | Ok resp ->
                 let headers =
                   Awso.Http.Headers.to_list (Awso.Http.Response.headers resp)
                 in
                 Ok ([%e of_header_and_body] (headers, ()))]))
    |> Ast_helper.Exp.match_ [%expr endpoint]
  in
  [%stri
    let of_response
      (type i o e)
      (endpoint : (i, o, e) t)
      (resp : (Awso.Http.Response.t, Awso.Http.Io.Error.call) result)
      : (o, [ `AWS of e | `Transport of Awso.Http.Io.Error.call ]) result
      =
      let handle_error err error_of_json =
        match err with
        | `Too_many_redirects -> Error (`Transport `Too_many_redirects)
        | `Bad_response { Awso.Http.Io.Error.code; body; x_amzn_error_type } -> (
          let generic_error () =
            Error
              (`Transport
                (`Bad_response { Awso.Http.Io.Error.code; body; x_amzn_error_type }))
          in
          match x_amzn_error_type, error_of_json, code >= 400 && code <= 599 with
          | Some error_type, Some error_of_json, true ->
            let json = Awso.Json.from_string body in
            Error (`AWS (error_of_json error_type json))
          | None, Some error_of_json, true -> (
            try
              let json = Awso.Json.from_string body in
              match json |> Awso.Json.Util.member_or_null "__type" with
              | `String error_type ->
                let error_type =
                  (* sometimes errors have names like
                     "com.amazonaws.switchboard.portal#UnauthorizedException";
                     just strip off the leading part. *)
                  match String.lsplit2 error_type ~on:'#' with
                  | Some (_, s) -> s
                  | None -> error_type
                in
                Error (`AWS (error_of_json error_type json))
              | `Null -> generic_error ()
              | _ -> failwithf "Error '__type' did not have string type: %s" body ()
            with
            | _ -> generic_error ())
          | None, _, _ | _, None, _ | _, _, false -> generic_error ())
      in
      let response_to_json resp =
        Awso.Json.from_string (Awso.Http.Response.body resp)
      in
      let _ = resp in
      let _ = handle_error in
      let _ = response_to_json in
      [%e body]
    ;;]
;;

let%expect_test "of_response" =
  [ Endpoint.create_test
      "Of_header_and_no_body"
      ~result_module:(Some "Result")
      ~result_decoder:(Some (Of_header_and_body None))
  ; Endpoint.create_test
      "Direct"
      ~result_module:(Some "DirectResult")
      ~result_decoder:(Some Json)
  ; Endpoint.create_test
      "Of_header_and_body"
      ~result_module:(Some "Result_of_header_and_body")
      ~result_decoder:(Some (Of_header_and_body (Some "Payload_module")))
  ; Endpoint.create_test "No_output" ~result_module:None ~result_decoder:None
  ]
  |> of_response
  |> List.return
  |> Util.structure_to_string
  |> printf "%s%!";
  [%expect
    {|
    let of_response (type i) (type o) (type e) (endpoint : (i, o, e) t)
      (resp : (Awso.Http.Response.t, Awso.Http.Io.Error.call) result) :
      (o, [ `AWS of e  | `Transport of Awso.Http.Io.Error.call ]) result=
      let handle_error err error_of_json =
        match err with
        | `Too_many_redirects -> Error (`Transport `Too_many_redirects)
        | `Bad_response
            { Awso.Http.Io.Error.code = code; body; x_amzn_error_type } ->
            let generic_error () =
              Error
                (`Transport
                   (`Bad_response
                      { Awso.Http.Io.Error.code = code; body; x_amzn_error_type })) in
            (match (x_amzn_error_type, error_of_json,
                     ((code >= 400) && (code <= 599)))
             with
             | (Some error_type, Some error_of_json, true) ->
                 let json = Awso.Json.from_string body in
                 Error (`AWS (error_of_json error_type json))
             | (None, Some error_of_json, true) ->
                 (try
                    let json = Awso.Json.from_string body in
                    match json |> (Awso.Json.Util.member_or_null "__type") with
                    | `String error_type ->
                        let error_type =
                          match String.lsplit2 error_type ~on:'#' with
                          | Some (_, s) -> s
                          | None -> error_type in
                        Error (`AWS (error_of_json error_type json))
                    | `Null -> generic_error ()
                    | _ ->
                        failwithf "Error '__type' did not have string type: %s"
                          body ()
                  with | _ -> generic_error ())
             | (None, _, _) | (_, None, _) | (_, _, false) -> generic_error ()) in
      let response_to_json resp =
        Awso.Json.from_string (Awso.Http.Response.body resp) in
      let _ = resp in
      let _ = handle_error in
      let _ = response_to_json in
      match endpoint with
      | Of_header_and_no_body ->
          (match resp with
           | Error err -> handle_error err None
           | Ok resp ->
               let headers =
                 Awso.Http.Headers.to_list (Awso.Http.Response.headers resp) in
               Ok (Result.of_header_and_body (headers, ())))
      | Direct ->
          (match resp with
           | Error err -> handle_error err None
           | Ok resp -> Ok (DirectResult.of_json (response_to_json resp)))
      | Of_header_and_body ->
          (match resp with
           | Error err -> handle_error err None
           | Ok resp ->
               let body = Payload_module.of_string (Awso.Http.Response.body resp) in
               let headers =
                 Awso.Http.Headers.to_list (Awso.Http.Response.headers resp) in
               Ok (Result_of_header_and_body.of_header_and_body (headers, body)))
      | No_output -> Ok ()
    |}]
;;

let make_structure_for_protocol service data =
  [ to_request service data; of_response data ]
;;
