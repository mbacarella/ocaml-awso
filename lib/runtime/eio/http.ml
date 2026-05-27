open! Awso_common.Jane_compat

let to_headers req =
  req |> Awso.Http.Request.headers |> Awso.Http.Headers.to_list |> Cohttp.Header.of_list
;;

let of_version resp =
  match Cohttp.Response.version resp with
  | `HTTP_1_0 -> 1, 0
  | `HTTP_1_1 -> 1, 1
  | `Other _ -> 0, 0
;;

let of_headers resp =
  resp |> Cohttp.Response.headers |> Cohttp.Header.to_list |> Awso.Http.Headers.of_list
;;

let of_status resp =
  match Cohttp.Response.status resp with
  | #Awso.Http.Status.t as status -> (status :> Awso.Http.Status.t)
  | status -> `Code (Cohttp.Code.code_of_status status)
;;

module Io = struct
  type 'a t = 'a

  let return x = x
  let bind x f = f x
  let map x f = f x

  let resolve_cfg = function
    | Some cfg -> cfg
    | None ->
      failwith
        "awso-eio: ~cfg is required (Cfg.get_exn needs the Eio env, so we can't \
         auto-resolve here)"
  ;;

  let call ?endpoint_url ~cfg ~service meth request uri =
    let { Cfg.aws_cfg; client } = cfg in
    let { Awso.Cfg.region
        ; aws_access_key_id
        ; aws_secret_access_key
        ; aws_session_token
        ; _
        }
      =
      aws_cfg
    in
    let region =
      match region with
      | Some r -> r
      | None -> failwith "config must set 'region'"
    in
    let endpoint =
      match endpoint_url with
      | Some s -> Uri.of_string s
      | None -> Awso.Botocore_endpoints.lookup_uri ~region service `HTTPS
    in
    let uri = Uri.with_uri ~scheme:(Uri.scheme endpoint) ~host:(Uri.host endpoint) uri in
    let host =
      match Uri.host endpoint with
      | Some h -> h
      | None ->
        failwithf "could not extract 'host' from url %s" (Uri.to_string endpoint) ()
    in
    let req_body = Awso.Http.Request.body request in
    let body_length = Int64.of_int (String.length req_body) in
    let payload_hash = Awso.Auth.payload_hash req_body in
    let cohttp_meth = (meth :> Cohttp.Code.meth) in
    let cohttp_headers =
      let h = to_headers request in
      Cohttp.Header.add_unless_exists h "host" host
    in
    let signed_request =
      Cohttp.Request.make_for_client
        ~headers:cohttp_headers
        ~chunked:false
        ~body_length
        cohttp_meth
        uri
      |> Awso.Auth.sign_request
           ~region
           ~service
           ?session_token:aws_session_token
           ?aws_access_key_id
           ?aws_secret_access_key
           ~payload_hash
    in
    let signed_headers = Cohttp.Request.headers signed_request in
    (* 2026-05-18 mbac: This tautological looking match is actually converting
       Cohttp.Code.meth to Http.Method.t. It's leveraging poly-variant inference
       to avoid module name collisions: this module is called Http, not to be confused
       with the `http` opam library. *)
    let eio_meth =
      match meth with
      | `GET -> `GET
      | `POST -> `POST
      | `HEAD -> `HEAD
      | `PUT -> `PUT
      | `DELETE -> `DELETE
      | `CONNECT -> `CONNECT
      | `OPTIONS -> `OPTIONS
      | `TRACE -> `TRACE
      | `PATCH -> `PATCH
      | `Other s -> `Other s
    in
    Eio.Switch.run (fun sw ->
      let body = Cohttp_eio.Body.of_string req_body in
      let resp, resp_body =
        Cohttp_eio.Client.call
          ~sw
          client
          ~headers:signed_headers
          ~body
          ~chunked:false
          eio_meth
          uri
      in
      let body_str = Eio.Buf_read.(parse_exn take_all) resp_body ~max_size:max_int in
      Awso.Http.Response.make
        ~version:(of_version resp)
        ~headers:(of_headers resp)
        ~body:body_str
        (of_status resp))
  ;;
end
