open! Import

(* Synchronous mirror of Awso_lwt.Cfg / Awso_async.Cfg, but using plain
   blocking [In_channel] reads. The base [Awso.Cfg] only exposes [make] —
   each backend wraps that with its own file-I/O strategy. *)

let file_contents path =
  let ic = Stdlib.open_in path in
  let n = Stdlib.in_channel_length ic in
  let buf = Bytes.create n in
  Stdlib.really_input ic buf 0 n;
  Stdlib.close_in ic;
  Bytes.unsafe_to_string buf
;;

let get ?profile ?aws_access_key_id ?aws_secret_access_key ?region ?output () =
  let profile =
    List.reduce_exn
      ~f:Option.first_some
      [ profile; Stdlib.Sys.getenv_opt "AWS_DEFAULT_PROFILE" ]
  in
  let file path of_string =
    match path () with
    | None -> Ok None
    | Some file -> (
      let contents = file_contents file in
      match of_string contents with
      | Error e -> Error e
      | Ok r -> Ok (Some (file, r)))
  in
  match file Awso.Cfg.Config_file.path Awso.Cfg.Config_file.of_string with
  | Error e -> Error e
  | Ok config_file -> (
    match
      file
        Awso.Cfg.Shared_credentials_file.path
        Awso.Cfg.Shared_credentials_file.of_string
    with
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
  match get ?profile ?aws_access_key_id ?aws_secret_access_key ?region ?output () with
  | Ok r -> r
  | Error e -> failwithf "Cfg.get_exn: %s" e ()
;;
