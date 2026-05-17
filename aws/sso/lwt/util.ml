open Lwt.Infix

module Cfg = struct
  let get ?profile ?region ?output () =
    Awso_lwt.Cfg.get ?profile ?region ?output ()
    >>= function
    | Error e -> Lwt.return (Error (Failure e))
    | Ok cfg ->
      let cached_sso_token_file = Awso_sso.Util.get_cached_sso_token_file_path ~cfg in
      Awso_lwt.Import.file_contents cached_sso_token_file
      >>= fun jsonstr ->
      (match
         Awso_sso.Util.get_sso_role_request_and_cfg ~cfg ~cached_sso_token_file jsonstr
       with
       | Error e -> Lwt.return (Error e)
       | Ok (role_request, sso_cfg) ->
         Io.get_role_credentials ~cfg:sso_cfg role_request
         >|= fun res ->
         let roleCredentials = Awso_sso.Util.parse_role_credentials_response_exn res in
         Awso_sso.Util.update_cfg_with_role_credentials ~cfg roleCredentials)
  ;;

  let get_exn ?profile ?region ?output () =
    get ?profile ?region ?output ()
    >|= function
    | Ok x -> x
    | Error e -> raise e
  ;;
end
