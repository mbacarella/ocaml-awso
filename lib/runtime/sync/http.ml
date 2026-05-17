open! Import

(* Synchronous HTTP backend using libcurl (via [ocurl]). Pure blocking I/O.
   The lwt and async backends drive cohttp manually because they need to
   weave their I/O into their respective scheduler; the sync backend has no
   scheduler to weave into, so we let libcurl do the wire-level work.

   We still build a Cohttp.Request.t to feed to Awso.Auth.sign_request (the
   signing function takes Cohttp's request type). We then extract the signed
   headers and hand everything to curl. *)

let method_string (meth : Awso.Http.Meth.t) =
  match meth with
  | `GET -> "GET"
  | `POST -> "POST"
  | `PUT -> "PUT"
  | `DELETE -> "DELETE"
  | `HEAD -> "HEAD"
  | `PATCH -> "PATCH"
  | `OPTIONS -> "OPTIONS"
  | `CONNECT -> "CONNECT"
  | `TRACE -> "TRACE"
  | `Other s -> s
;;

let body_makes_sense_for = function
  | `POST | `PUT | `PATCH | `Other _ -> true
  | `GET | `HEAD | `DELETE | `OPTIONS | `CONNECT | `TRACE -> false
;;

(* Curl wants headers as a "Name: value" string list. *)
let cohttp_headers_to_curl headers =
  Cohttp.Header.to_list headers |> List.map ~f:(fun (k, v) -> sprintf "%s: %s" k v)
;;

(* libcurl reports the response status as the integer code; turn it into the
   Awso.Http.Status.t our runtime expects. *)
let status_of_code code : Awso.Http.Status.t =
  match Cohttp.Code.status_of_code code with
  | #Awso.Http.Status.t as s -> (s :> Awso.Http.Status.t)
  | other -> `Code (Cohttp.Code.code_of_status other)
;;

(* libcurl's headerfunction is called once per response header line, including
   the trailing CRLF on each line and the empty line at the end of the block.
   We parse just the "Name: value" lines. *)
let parse_response_header_line line =
  match String.index_opt line ':' with
  | None -> None
  | Some i ->
    let name = String.sub line 0 i in
    let value =
      let rest = String.sub line (i + 1) (String.length line - i - 1) in
      String.trim rest
    in
    Some (name, value)
;;

let perform_request ~uri ~meth ~headers ~req_body =
  let h = Curl.init () in
  let body_buf = Buffer.create 4096 in
  let resp_headers = ref [] in
  Fun.protect
    ~finally:(fun () -> Curl.cleanup h)
    (fun () ->
       Curl.set_url h (Uri.to_string uri);
       Curl.set_httpheader h (cohttp_headers_to_curl headers);
       Curl.set_followlocation h true;
       Curl.set_maxredirs h 50;
       (* TODO: handle S3-style "PermanentRedirect" responses, where the new
          endpoint is in the XML body rather than a Location header. The lwt
          backend (lib/runtime/lwt/http.ml: find_xml_redirect_endpoint) does
          this — we should port that logic here so cross-region S3 bucket
          access works against awso-sync too. *)
       Curl.set_useragent h "awso-sync/0.9";
       Curl.set_writefunction h (fun chunk ->
         Buffer.add_string body_buf chunk;
         String.length chunk);
       Curl.set_headerfunction h (fun line ->
         (match parse_response_header_line line with
          | None -> ()
          | Some kv -> resp_headers := kv :: !resp_headers);
         String.length line);
       Curl.set_customrequest h (method_string meth);
       if body_makes_sense_for meth
       then (
         Curl.set_postfields h req_body;
         Curl.set_postfieldsize h (String.length req_body));
       if Stdlib.( = ) meth `HEAD then Curl.set_nobody h true;
       Curl.perform h;
       let code = Curl.get_responsecode h in
       let status = status_of_code code in
       let body = Buffer.contents body_buf in
       let headers = Awso.Http.Headers.of_list (List.rev !resp_headers) in
       Awso.Http.Response.make ~headers ~body status)
;;

module Io = struct
  let return x = x
  let bind x f = f x
  let map x f = f x

  let call ?endpoint_url ~cfg ~service meth request uri =
    let { Awso.Cfg.region
        ; aws_access_key_id
        ; aws_secret_access_key
        ; aws_session_token
        ; _
        }
      =
      cfg
    in
    let region =
      match region with
      | Some r -> r
      | None -> failwith "config must set 'region'"
    in
    let endpoint =
      match endpoint_url with
      | Some endpoint_url -> Uri.of_string endpoint_url
      | None -> Awso.Botocore_endpoints.lookup_uri ~region service `HTTPS
    in
    let uri = Uri.with_uri ~scheme:(Uri.scheme endpoint) ~host:(Uri.host endpoint) uri in
    let host =
      match Uri.host endpoint with
      | Some h -> h
      | None ->
        failwith (sprintf "could not extract 'host' from url %s" (Uri.to_string endpoint))
    in
    let cohttp_meth : Cohttp.Code.meth = (meth :> Cohttp.Code.meth) in
    let req_body = Awso.Http.Request.body request in
    let body_length = Int64.of_int (String.length req_body) in
    let payload_hash = Awso.Auth.payload_hash req_body in
    let headers =
      let init =
        request
        |> Awso.Http.Request.headers
        |> Awso.Http.Headers.to_list
        |> Cohttp.Header.of_list
      in
      Cohttp.Header.add init "host" host
    in
    let signed =
      Cohttp.Request.make_for_client ~headers ~chunked:false ~body_length cohttp_meth uri
      |> Awso.Auth.sign_request
           ~region
           ~service
           ?session_token:aws_session_token
           ?aws_access_key_id
           ?aws_secret_access_key
           ~payload_hash
    in
    let signed_headers = Cohttp.Request.headers signed in
    perform_request ~uri ~meth ~headers:signed_headers ~req_body
  ;;

  let resolve_cfg = function
    | Some cfg -> cfg
    | None -> Cfg.get_exn ()
  ;;
end
