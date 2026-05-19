open! Import

let eval_structure ~base_module ~io_subsystem operations =
  let loc = !Ast_helper.default_loc in
  let make binding ctor =
    let p = Ast_convenience.pvar binding in
    let c = Printf.ksprintf Ast_convenience.evar "Endpoints.%s" ctor in
    [%stri
      let [%p p] = fun ?endpoint_url ?cfg input -> eval ?endpoint_url ?cfg [%e c] input]
  in
  let make_open mod_name =
    let longident_loc txt loc = { txt = Longident.Lident txt; loc } in
    Ast_helper.Str.open_
      { popen_expr =
          { pmod_desc = Pmod_ident (longident_loc mod_name loc)
          ; pmod_loc = loc
          ; pmod_attributes = []
          }
      ; popen_override = Fresh
      ; popen_loc = loc
      ; popen_attributes = []
      }
  in
  let io_module =
    match io_subsystem with
    | `Async -> "Awso_async"
    | `Lwt -> "Awso_lwt"
    | `Sync -> "Awso_sync"
    | `Eio -> "Awso_eio"
  in
  let base_open = make_open base_module in
  let io_open = make_open io_module in
  let preamble =
    [%str
      [%%i base_open]
      [%%i io_open]

      module Io = Http.Io

      let eval ?endpoint_url ?cfg endpoint input =
        Io.bind (Io.resolve_cfg cfg) (fun cfg ->
          let meth = Endpoints.method_of_endpoint endpoint in
          let uri = Endpoints.uri_of_endpoint endpoint input in
          Io.map
            (Io.call
               ?endpoint_url
               ~cfg
               ~service:Values.service
               meth
               (Endpoints.to_request endpoint input)
               uri)
            (fun resp_result -> Endpoints.of_response endpoint resp_result))
      ;;]
  in
  preamble
  @ List.map
      ~f:(fun e ->
        let s = Endpoint.name e in
        make (Util.camel_to_snake_case s) s)
      operations
;;

let%expect_test "eval_structure_async" =
  let data =
    [ Endpoint.create_test "AbortMultipartUpload"
    ; Endpoint.create_test "CompleteMultipartUpload"
    ]
  in
  eval_structure ~io_subsystem:`Async ~base_module:"Base_module" data
  |> Util.structure_to_string
  |> printf "%s%!";
  [%expect
    {|
    open Base_module
    open Awso_async
    module Io = Http.Io
    let eval ?endpoint_url ?cfg endpoint input =
      Io.bind (Io.resolve_cfg cfg)
        (fun cfg ->
           let meth = Endpoints.method_of_endpoint endpoint in
           let uri = Endpoints.uri_of_endpoint endpoint input in
           Io.map
             (Io.call ?endpoint_url ~cfg ~service:Values.service meth
                (Endpoints.to_request endpoint input) uri)
             (fun resp_result -> Endpoints.of_response endpoint resp_result))
    let abort_multipart_upload ?endpoint_url ?cfg input =
      eval ?endpoint_url ?cfg Endpoints.AbortMultipartUpload input
    let complete_multipart_upload ?endpoint_url ?cfg input =
      eval ?endpoint_url ?cfg Endpoints.CompleteMultipartUpload input
    |}]
;;

let%expect_test "eval_structure_lwt" =
  let data =
    [ Endpoint.create_test "AbortMultipartUpload"
    ; Endpoint.create_test "CompleteMultipartUpload"
    ]
  in
  eval_structure ~io_subsystem:`Lwt ~base_module:"Base_module" data
  |> Util.structure_to_string
  |> printf "%s%!";
  [%expect
    {|
    open Base_module
    open Awso_lwt
    module Io = Http.Io
    let eval ?endpoint_url ?cfg endpoint input =
      Io.bind (Io.resolve_cfg cfg)
        (fun cfg ->
           let meth = Endpoints.method_of_endpoint endpoint in
           let uri = Endpoints.uri_of_endpoint endpoint input in
           Io.map
             (Io.call ?endpoint_url ~cfg ~service:Values.service meth
                (Endpoints.to_request endpoint input) uri)
             (fun resp_result -> Endpoints.of_response endpoint resp_result))
    let abort_multipart_upload ?endpoint_url ?cfg input =
      eval ?endpoint_url ?cfg Endpoints.AbortMultipartUpload input
    let complete_multipart_upload ?endpoint_url ?cfg input =
      eval ?endpoint_url ?cfg Endpoints.CompleteMultipartUpload input
    |}]
;;

let eval_signature ~protocol ~base_module ~io_subsystem endpoints =
  let loc = !Ast_helper.default_loc in
  let open_ =
    base_module
    |> Printf.ksprintf Ast_convenience.lid "%s.Values"
    |> Ast_helper.Opn.mk
    |> Ast_helper.Sig.open_
  in
  [%sig: [%%i open_]]
  @ List.map endpoints ~f:(fun e ->
    let name = Endpoint.name e |> Util.camel_to_snake_case |> Ast_convenience.mknoloc in
    let request_type = Endpoint.request_type e in
    let result_type =
      let ok_arg = Endpoint.result_ok_type e in
      let error_arg =
        match protocol with
        | `ec2 -> [%type: Values.Ec2_error.t]
        | `json | `query | `rest_xml | `rest_json -> Endpoint.result_error_type e
      in
      match io_subsystem with
      | `Async -> [%type: ([%t ok_arg], [%t error_arg]) Result.t Async.Deferred.t]
      | `Lwt -> [%type: ([%t ok_arg], [%t error_arg]) Result.t Lwt.t]
      | `Sync -> [%type: ([%t ok_arg], [%t error_arg]) Result.t]
      | `Eio -> [%type: ([%t ok_arg], [%t error_arg]) Result.t]
    in
    let cfg_type =
      match io_subsystem with
      | `Async | `Lwt | `Sync -> [%type: Awso.Cfg.t]
      | `Eio -> [%type: Awso_eio.Cfg.t]
    in
    Ast_helper.Sig.value
      (Ast_helper.Val.mk
         name
         [%type:
           ?endpoint_url:string
           -> ?cfg:[%t cfg_type]
           -> [%t request_type]
           -> [%t result_type]]))
;;

let%expect_test "eval_signature_async" =
  let data =
    [ Endpoint.create_test
        "Input_and_output"
        ~request_module:(Some "Input")
        ~result_module:(Some "Output")
    ; Endpoint.create_test "Only_input" ~request_module:(Some "Input") ~result_module:None
    ; Endpoint.create_test
        "Only_output"
        ~request_module:None
        ~result_module:(Some "Output")
    ; Endpoint.create_test
        "No_input_and_no_output"
        ~request_module:None
        ~result_module:None
    ]
  in
  eval_signature ~protocol:`json ~base_module:"Base_module" ~io_subsystem:`Async data
  |> Util.signature_to_string
  |> print_endline;
  [%expect
    {|
    open Base_module.Values
    val input_and_output :
      ?endpoint_url:string ->
        ?cfg:Awso.Cfg.t ->
          Input.t -> (Output.t, Output.error) Result.t Async.Deferred.t
    val only_input :
      ?endpoint_url:string ->
        ?cfg:Awso.Cfg.t -> Input.t -> (unit, unit) Result.t Async.Deferred.t
    val only_output :
      ?endpoint_url:string ->
        ?cfg:Awso.Cfg.t ->
          unit -> (Output.t, Output.error) Result.t Async.Deferred.t
    val no_input_and_no_output :
      ?endpoint_url:string ->
        ?cfg:Awso.Cfg.t -> unit -> (unit, unit) Result.t Async.Deferred.t |}]
;;
