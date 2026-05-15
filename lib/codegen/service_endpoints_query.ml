open! Import

let to_request = Service_endpoints_common.to_request

let of_response endpoints =
  let loc = !Ast_helper.default_loc in
  let body =
    Endpoint.cases endpoints ~f:(fun endpoint ->
      let error_of_xml =
        Service_endpoints_common.make_error_expression ~loc ~label:"error_of_xml" endpoint
      in
      match Endpoint.in_result_module endpoint "of_xml" with
      | None -> [%expr Ok ()]
      | Some of_xml ->
        [%expr
          match resp with
          | Error err -> handle_error err [%e error_of_xml]
          | Ok resp ->
            let xml = Awso.Xml.parse_response (Awso.Http.Response.body resp) in
            Ok ([%e of_xml] xml)])
    |> Ast_helper.Exp.match_ [%expr endpoint]
  in
  [%stri
    let of_response
      (type i o e)
      (endpoint : (i, o, e) t)
      (resp : (Awso.Http.Response.t, Awso.Http.Io.Error.call) result)
      : (o, [ `AWS of e | `Transport of Awso.Http.Io.Error.call ]) result
      =
      let handle_error err error_of_xml =
        let generic_error () = Error (`Transport err) in
        match err with
        | `Too_many_redirects -> generic_error ()
        | `Bad_response { Awso.Http.Io.Error.code; body; x_amzn_error_type = _ } -> (
          match error_of_xml, code >= 400 && code <= 599 with
          | None, _ | _, false -> generic_error ()
          | Some error_of_xml, true -> (
            match Awso.Xml.parse_response body with
            | `Data _ -> generic_error ()
            | `El (((_, "ErrorResponse"), _), _) as error_response_xml -> (
              let error_xml = Awso.Xml.child_exn error_response_xml "Error" in
              try
                let error_code =
                  match Awso.Xml.child_exn error_xml "Code" with
                  | `Data error_code -> error_code
                  | `El (_, children) ->
                    List.map children ~f:(function
                      | `Data s -> s
                      | `El _ -> "")
                    |> String.concat ~sep:""
                in
                Error (`AWS (error_of_xml (String.strip error_code) error_xml))
              with
              | Failure _ -> generic_error ())
            | `El _ -> generic_error ()))
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
      let handle_error err error_of_xml =
        let generic_error () = Error (`Transport err) in
        match err with
        | `Too_many_redirects -> generic_error ()
        | `Bad_response
            { Awso.Http.Io.Error.code = code; body; x_amzn_error_type = _ } ->
            (match (error_of_xml, ((code >= 400) && (code <= 599))) with
             | (None, _) | (_, false) -> generic_error ()
             | (Some error_of_xml, true) ->
                 (match Awso.Xml.parse_response body with
                  | `Data _ -> generic_error ()
                  | `El (((_, "ErrorResponse"), _), _) as error_response_xml ->
                      let error_xml =
                        Awso.Xml.child_exn error_response_xml "Error" in
                      (try
                         let error_code =
                           match Awso.Xml.child_exn error_xml "Code" with
                           | `Data error_code -> error_code
                           | `El (_, children) ->
                               (List.map children
                                  ~f:(function | `Data s -> s | `El _ -> ""))
                                 |> (String.concat ~sep:"") in
                         Error
                           (`AWS
                              (error_of_xml (String.strip error_code) error_xml))
                       with | Failure _ -> generic_error ())
                  | `El _ -> generic_error ())) in
      match endpoint with
      | Name1 ->
          (match resp with
           | Error err -> handle_error err None
           | Ok resp ->
               let xml = Awso.Xml.parse_response (Awso.Http.Response.body resp) in
               Ok (ResultModule1.of_xml xml))
      | Name2 ->
          (match resp with
           | Error err -> handle_error err None
           | Ok resp ->
               let xml = Awso.Xml.parse_response (Awso.Http.Response.body resp) in
               Ok (ResultModule2.of_xml xml))
      | Name3 -> Ok ()
    |}]
;;

let make_structure_for_protocol _service _metadata data =
  [ to_request data; of_response data ]
;;
