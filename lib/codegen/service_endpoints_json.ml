open! Import

let to_request ~json_version ~target_prefix endpoints =
  let loc = !Ast_helper.default_loc in
  let unit_to_json = [%expr fun () -> `Assoc []] in
  let content_type =
    (match json_version with
     | "1.0" | "1.1" -> sprintf "application/x-amz-json-%s" json_version
     | _ -> failwithf "unexpected jsonVersion: %s" json_version ())
    |> Ast_convenience.str
  in
  let expr =
    Endpoint.cases endpoints ~f:(fun endpoint ->
      let to_json =
        Endpoint.in_request_module endpoint "to_json"
        |> Option.value ~default:unit_to_json
      in
      let name = Endpoint.name endpoint in
      let target = Printf.ksprintf Ast_convenience.str "%s.%s" target_prefix name in
      [%expr
        let json = [%e to_json] req in
        let body = Awso.Json.to_string json in
        let headers =
          Awso.Http.Headers.of_list
            [ "Content-Type", [%e content_type]; "X-Amz-Target", [%e target] ]
        in
        Awso.Http.Request.make ~body ~headers (method_of_endpoint endp)])
    |> Ast_helper.Exp.match_ [%expr endp]
  in
  [%stri let to_request (type i o e) (endp : (i, o, e) t) (req : i) = [%e expr]]
;;

let%expect_test "to_request" =
  [ Endpoint.create_test "Name1" ~request_module:(Some "Module1")
  ; Endpoint.create_test "Name2" ~request_module:(Some "Module2")
  ; Endpoint.create_test "Name3" ~request_module:None
  ]
  |> to_request ~json_version:"1.1" ~target_prefix:"TARGET_PREFIX"
  |> List.return
  |> Util.structure_to_string
  |> printf "%s%!";
  [%expect
    {|
    let to_request (type i) (type o) (type e) (endp : (i, o, e) t) (req : i) =
      match endp with
      | Name1 ->
          let json = Module1.to_json req in
          let body = Awso.Json.to_string json in
          let headers =
            Awso.Http.Headers.of_list
              [("Content-Type", "application/x-amz-json-1.1");
              ("X-Amz-Target", "TARGET_PREFIX.Name1")] in
          Awso.Http.Request.make ~body ~headers (method_of_endpoint endp)
      | Name2 ->
          let json = Module2.to_json req in
          let body = Awso.Json.to_string json in
          let headers =
            Awso.Http.Headers.of_list
              [("Content-Type", "application/x-amz-json-1.1");
              ("X-Amz-Target", "TARGET_PREFIX.Name2")] in
          Awso.Http.Request.make ~body ~headers (method_of_endpoint endp)
      | Name3 ->
          let json = (fun () -> `Assoc []) req in
          let body = Awso.Json.to_string json in
          let headers =
            Awso.Http.Headers.of_list
              [("Content-Type", "application/x-amz-json-1.1");
              ("X-Amz-Target", "TARGET_PREFIX.Name3")] in
          Awso.Http.Request.make ~body ~headers (method_of_endpoint endp) |}]
;;

let of_response endpoints =
  let loc = !Ast_helper.default_loc in
  let body =
    Endpoint.cases endpoints ~f:(fun endpoint ->
      let error_of_json =
        Service_endpoints_common.make_error_expression
          ~loc
          ~label:"error_of_json"
          endpoint
      in
      match Endpoint.in_result_module endpoint "of_json" with
      | None -> [%expr Ok ()]
      | Some of_json ->
        [%expr
          match resp with
          | Error err -> handle_error err [%e error_of_json]
          | Ok resp ->
            let json = Awso.Json.from_string (Awso.Http.Response.body resp) in
            Ok ([%e of_json] json)])
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
        let generic_error () = Error (`Transport err) in
        match err with
        | `Too_many_redirects -> generic_error ()
        | `Bad_response { Awso.Http.Io.Error.code; body; x_amzn_error_type = _ } -> (
          match error_of_json, code >= 400 && code <= 599 with
          | Some error_of_json, true -> (
            let json = Awso.Json.from_string body in
            match json |> Awso.Json.Util.member_or_null "__type" with
            | `String error_type -> Error (`AWS (error_of_json error_type json))
            | `Null -> generic_error ()
            | _ -> failwith (sprintf "Error '__type' did not have string type: %s" body))
          | None, _ | _, false -> generic_error ())
      in
      [%e body]
    ;;]
;;

let%expect_test "of_response" =
  [ Endpoint.create_test "Name1" ~result_module:(Some "ResultModule1")
  ; Endpoint.create_test "Name2" ~result_module:(Some "ResultModule2")
  ; Endpoint.create_test "Name3" ~result_module:None
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
        let generic_error () = Error (`Transport err) in
        match err with
        | `Too_many_redirects -> generic_error ()
        | `Bad_response
            { Awso.Http.Io.Error.code = code; body; x_amzn_error_type = _ } ->
            (match (error_of_json, ((code >= 400) && (code <= 599))) with
             | (Some error_of_json, true) ->
                 let json = Awso.Json.from_string body in
                 (match json |> (Awso.Json.Util.member_or_null "__type") with
                  | `String error_type ->
                      Error (`AWS (error_of_json error_type json))
                  | `Null -> generic_error ()
                  | _ ->
                      failwith
                        (sprintf "Error '__type' did not have string type: %s"
                           body))
             | (None, _) | (_, false) -> generic_error ()) in
      match endpoint with
      | Name1 ->
          (match resp with
           | Error err -> handle_error err None
           | Ok resp ->
               let json = Awso.Json.from_string (Awso.Http.Response.body resp) in
               Ok (ResultModule1.of_json json))
      | Name2 ->
          (match resp with
           | Error err -> handle_error err None
           | Ok resp ->
               let json = Awso.Json.from_string (Awso.Http.Response.body resp) in
               Ok (ResultModule2.of_json json))
      | Name3 -> Ok ()
    |}]
;;

let make_structure_for_protocol (metadata : Botodata.metadata) data =
  let target_prefix =
    metadata.targetPrefix
    |> Option.value_exn ~message:"make_structure_for_protocol: no target prefix"
    |> Uri_json.to_string
  in
  let json_version =
    Option.value_exn ~message:"No metadata.jsonVersion" metadata.jsonVersion
  in
  [ to_request ~json_version ~target_prefix data; of_response data ]
;;
