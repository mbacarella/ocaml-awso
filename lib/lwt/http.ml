open! Import
open Lwt.Infix

module Io : Awso.Http.Io.S with type 'a t := 'a Lwt.t = struct
  let return = Lwt.return
  let bind x f = x >>= f
  let map x f = x >|= f

  module Call : sig
    val cohttp_lwt
      :  ?endpoint_url:string
      -> cfg:Awso.Cfg.t
      -> service:Awso.Service.t
      -> Awso.Http.Meth.t
      -> Awso.Http.Request.t
      -> Uri.t
      -> (Awso.Http.Response.t, Awso.Http.Io.Error.call) result Lwt.t
  end = struct
    let find_xml_redirect_endpoint xml =
      let get x = Awso.Xml.child_exn xml x |> Awso.Xml.string_data_exn in
      let code = get "Code" in
      assert (String.equal "PermanentRedirect" code);
      get "Endpoint"
    ;;

    let set_host_headers headers ~host = Cohttp.Header.replace headers "host" host

    let set_host request ~host =
      { request with
        Cohttp.Request.headers =
          request |> Cohttp.Request.headers |> set_host_headers ~host
      }
    ;;

    let rec interpret_response ~limit req_body request (resp, body)
      : (Cohttp.Response.t * Cohttp.Body.t, Awso.Http.Io.Error.call) result Lwt.t
      =
      if limit >= 50
      then Lwt.return (Error `Too_many_redirects)
      else (
        match Cohttp.Response.status resp with
        | #Cohttp.Code.success_status -> Lwt.return (Ok (resp, body))
        | #Cohttp.Code.redirection_status ->
          Cohttp.Body.to_string body
          >>= fun body ->
          let xml = Awso.Xml.parse_response body in
          let host = find_xml_redirect_endpoint xml in
          let new_request = set_host request ~host in
          Cohttp.Client.call
            ~chunked:false
            ~headers:(Cohttp.Request.headers new_request)
            ~body:req_body
            (Cohttp.Request.meth new_request)
            (Cohttp.Request.uri new_request)
          >>= interpret_response ~limit:(succ limit) req_body new_request
        | code ->
          Cohttp.Body.to_string body
          >>= fun body ->
          let x_amzn_error_type =
            let headers = Cohttp.Response.headers resp in
            match Cohttp.Header.get headers "x-amzn-ErrorType" with
            | None -> None
            | Some value -> (
              match String.lsplit2 value ~on:':' with
              | None -> Some value
              | Some (v, _) -> Some v)
          in
          let bad_response =
            { Awso.Http.Io.Error.code = Cohttp.Code.code_of_status code
            ; body
            ; x_amzn_error_type
            }
          in
          Lwt.return (Error (`Bad_response bad_response)))
    ;;

    let interpret_response = interpret_response ~limit:0

    let cohttp_lwt_client_request request req_body =
      Cohttp.Client.call
        ~chunked:false
        ~headers:(Cohttp.Request.headers request)
        ~body:(Cohttp.Body.of_string req_body)
        (Cohttp.Request.meth request)
        (Uri.with_scheme (Cohttp.Request.uri request) (Some "https"))
    ;;

    let request_and_follow request req_body =
      cohttp_lwt_client_request request req_body
      >>= interpret_response (Cohttp.Body.of_string req_body) request
    ;;

    let cohttp_lwt ?endpoint_url ~cfg ~service meth request uri =
      let { Awso.Cfg.region
          ; aws_access_key_id
          ; aws_secret_access_key
          ; aws_session_token
          ; _
          }
        =
        cfg
      in
      let region = Option.value_exn region ~message:"config must set 'region'" in
      let meth = Cohttp.to_meth meth in
      let endpoint =
        match endpoint_url with
        | Some endpoint_url -> Uri.of_string endpoint_url
        | None -> Awso.Botocore_endpoints.lookup_uri ~region service `HTTPS
      in
      let uri =
        Uri.with_uri ~scheme:(Uri.scheme endpoint) ~host:(Uri.host endpoint) uri
      in
      let host =
        Core.Option.value_exn
          (Uri.host endpoint)
          ~message:
            (sprintf "could not extract 'host' from url %s" (Uri.to_string endpoint))
      in
      let headers =
        let headers = Cohttp.to_headers request in
        Cohttp.Header.add headers "host" host
      in
      let req_body = Awso.Http.Request.body request in
      let body_length = Int64.of_int (String.length req_body) in
      let payload_hash = Awso.Auth.payload_hash req_body in
      let request =
        Cohttp.Request.make_for_client ~headers ~chunked:false ~body_length meth uri
        |> Awso.Auth.sign_request
             ~region
             ~service
             ?session_token:aws_session_token
             ?aws_access_key_id
             ?aws_secret_access_key
             ~payload_hash
      in
      request_and_follow request req_body
      >>= function
      | Error _ as err -> Lwt.return err
      | Ok (resp, body) ->
        let version = Cohttp.of_version resp in
        let headers = Cohttp.of_headers resp in
        let status = Cohttp.of_status resp in
        Cohttp.Body.to_string body
        >|= fun body_str ->
        Ok (Awso.Http.Response.make ~version ~headers ~body:body_str status)
    ;;
  end

  let call ?endpoint_url ~cfg ~service meth request uri =
    Call.cohttp_lwt ?endpoint_url ~cfg ~service meth request uri
  ;;

  let resolve_cfg = function
    | Some cfg -> Lwt.return cfg
    | None -> Cfg.get_exn ()
  ;;
end
