module Cfg = struct
  let get ?profile ?region ?output () =
    match%bind Awso_async.Cfg.get ?profile ?region ?output () with
    | Error e -> return (Error (Failure e))
    | Ok cfg -> (
      let cached_sso_token_file = Awso_sso.Util.get_cached_sso_token_file_path ~cfg in
      let%bind jsonstr = Reader.file_contents cached_sso_token_file in
      match
        Awso_sso.Util.get_sso_role_request_and_cfg ~cfg ~cached_sso_token_file jsonstr
      with
      | Error e -> return (Error e)
      | Ok (role_request, sso_cfg) ->
        let%map roleCredentials =
          let%map res = Io.get_role_credentials ~cfg:sso_cfg role_request in
          Awso_sso.Util.parse_role_credentials_response_exn res
        in
        Awso_sso.Util.update_cfg_with_role_credentials ~cfg roleCredentials)
  ;;

  let get_exn ?profile ?region ?output () =
    match%map get ?profile ?region ?output () with
    | Ok x -> x
    | Error e -> raise e
  ;;
end
