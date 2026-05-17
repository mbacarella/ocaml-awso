open! Import
open Lwt.Infix

let get ?profile ?aws_access_key_id ?aws_secret_access_key ?region ?output () =
  let profile : string option =
    List.reduce_exn
      ~f:Option.first_some
      [ profile; Stdlib.Sys.getenv_opt "AWS_DEFAULT_PROFILE" ]
  in
  let file path of_string =
    match path () with
    | None -> Lwt.return (Ok None)
    | Some file -> (
      file_contents file
      >>= fun contents ->
      match of_string contents with
      | Error e -> Lwt.return (Error e)
      | Ok r -> Lwt.return (Ok (Some (file, r))))
  in
  file Awso.Cfg.Config_file.path Awso.Cfg.Config_file.of_string
  >>= function
  | Error e -> Lwt.return (Error e)
  | Ok config_file -> (
    file Awso.Cfg.Shared_credentials_file.path Awso.Cfg.Shared_credentials_file.of_string
    >|= function
    | Error e -> Error e
    | Ok shared_credentials_file ->
      Awso.Cfg.make
        ?config_file
        ?shared_credentials_file
        ?profile
        ?aws_access_key_id
        ?aws_secret_access_key
        ?region
        ?output
        ())
;;

let get_exn ?profile ?aws_access_key_id ?aws_secret_access_key ?region ?output () =
  get ?profile ?aws_access_key_id ?aws_secret_access_key ?region ?output ()
  >|= function
  | Ok r -> r
  | Error e -> failwithf "Cfg.get_exn: %s" e ()
;;
