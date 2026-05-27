open! Awso_common.Jane_compat

type t =
  { aws_cfg : Awso.Cfg.t
  ; client : Cohttp_eio.Client.t
  }

(* TLS setup special to cohttp-eio. *)
let make_https () =
  let authenticator =
    match Ca_certs.authenticator () with
    | Ok a -> a
    | Error (`Msg m) ->
      failwithf "awso-eio: failed to load system X509 authenticator: %s" m ()
  in
  let tls_config =
    match Tls.Config.client ~authenticator () with
    | Ok c -> c
    | Error (`Msg m) -> failwithf "awso-eio: failed to build TLS client config: %s" m ()
  in
  fun uri raw ->
    let host =
      Uri.host uri |> Option.map ~f:(fun h -> Domain_name.(host_exn (of_string_exn h)))
    in
    Tls_eio.client_of_flow ?host tls_config raw
;;

let read_file_opt ~fs path of_string =
  match path () with
  | None -> Ok None
  | Some file -> (
    let contents = Eio.Path.load Eio.Path.(fs / file) in
    match of_string contents with
    | Error e -> Error e
    | Ok r -> Ok (Some (file, r)))
;;

let get ~env ?profile ?aws_access_key_id ?aws_secret_access_key ?region ?output () =
  let fs = env#fs in
  let profile =
    match profile with
    | Some _ as p -> p
    | None -> Sys.getenv_opt "AWS_DEFAULT_PROFILE"
  in
  match read_file_opt ~fs Awso.Cfg.Config_file.path Awso.Cfg.Config_file.of_string with
  | Error e -> Error e
  | Ok config_file -> (
    match
      read_file_opt
        ~fs
        Awso.Cfg.Shared_credentials_file.path
        Awso.Cfg.Shared_credentials_file.of_string
    with
    | Error e -> Error e
    | Ok shared_credentials_file -> (
      match
        Awso.Cfg.make
          ?config_file
          ?shared_credentials_file
          ?profile
          ?aws_access_key_id
          ?aws_secret_access_key
          ?region
          ?output
          ()
      with
      | Error e -> Error e
      | Ok aws_cfg ->
        (* TLS in OCaml needs an entropy source initialised before use.
             Idempotent; safe to call repeatedly. *)
        Mirage_crypto_rng_unix.use_default ();
        let client = Cohttp_eio.Client.make ~https:(Some (make_https ())) env#net in
        Ok { aws_cfg; client }))
;;

let get_exn ~env ?profile ?aws_access_key_id ?aws_secret_access_key ?region ?output () =
  get ~env ?profile ?aws_access_key_id ?aws_secret_access_key ?region ?output ()
  |> Result.ok_or_failwith
;;
