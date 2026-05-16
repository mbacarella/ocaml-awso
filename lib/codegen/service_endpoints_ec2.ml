open! Import

let to_request = Service_endpoints_common.to_request

let of_response endpoints =
  let loc = !Ast_helper.default_loc in
  let body =
    Endpoint.cases endpoints ~f:(fun e ->
      match Endpoint.in_result_module e "of_xml" with
      | None -> [%expr response_of_none ()]
      | Some of_xml -> [%expr response_of_some_xml [%e of_xml]])
    |> Ast_helper.Exp.match_ [%expr endpoint]
  in
  [%stri
    let of_response (type i o e) (endpoint : (i, o, e) t) (resp : Awso.Http.Response.t)
      : (o, Ec2_error.t) result
      =
      let code = Awso.Http.Status.to_code (Awso.Http.Response.status resp) in
      let is_success = code >= 200 && code < 300 in
      let parse_aws_error () =
        if code >= 400 && code <= 599
        then (
          let xml = Awso.Xml.parse_response (Awso.Http.Response.body resp) in
          Ec2_error.of_xml xml)
        else
          raise
            (Awso.Http.Io.Error.Bad_response
               { Awso.Http.Io.Error.code
               ; body = Awso.Http.Response.body resp
               ; x_amzn_error_type = None
               })
      in
      let response_of_none () =
        if is_success then Ok () else Error (parse_aws_error ())
      in
      let response_of_some_xml of_xml =
        if is_success
        then (
          let xml = Awso.Xml.parse_response (Awso.Http.Response.body resp) in
          Ok (of_xml xml))
        else Error (parse_aws_error ())
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
      (resp : Awso.Http.Response.t) : (o, Ec2_error.t) result=
      let code = Awso.Http.Status.to_code (Awso.Http.Response.status resp) in
      let is_success = (code >= 200) && (code < 300) in
      let parse_aws_error () =
        if (code >= 400) && (code <= 599)
        then
          let xml = Awso.Xml.parse_response (Awso.Http.Response.body resp) in
          Ec2_error.of_xml xml
        else
          raise
            (Awso.Http.Io.Error.Bad_response
               {
                 Awso.Http.Io.Error.code = code;
                 body = (Awso.Http.Response.body resp);
                 x_amzn_error_type = None
               }) in
      let response_of_none () =
        if is_success then Ok () else Error (parse_aws_error ()) in
      let response_of_some_xml of_xml =
        if is_success
        then
          let xml = Awso.Xml.parse_response (Awso.Http.Response.body resp) in
          Ok (of_xml xml)
        else Error (parse_aws_error ()) in
      match endpoint with
      | Name1 -> response_of_some_xml ResultModule1.of_xml
      | Name2 -> response_of_some_xml ResultModule2.of_xml
      | Name3 -> response_of_none ()
    |}]
;;

let make_structure_for_protocol _service _metadata data =
  [ to_request data ] @ [ of_response data ]
;;
