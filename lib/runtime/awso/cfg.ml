open! Import
open Ppx_yojson_conv_lib.Yojson_conv.Primitives

module type Stanza_spec = sig
  type t [@@deriving yojson]

  val empty : t

  val set_field
    :  is_s3_field:bool
    -> name:string
    -> value:string
    -> line_num:int
    -> t String.Map.t * (string * t) option
    -> t String.Map.t * (string * t) option
end

module type File_env_spec = sig
  val env_var : string
  val aws_home_dir_file : string
end

module S3_custom_command_settings = struct
  (* We don't use these in awso ourselves, but the .aws/config format allows
     for configuring the aws s3 higher-level command this way. So, we parse it.*)
  type t =
    { max_concurrent_requests : string option
    ; max_queue_size : string option
    ; multipart_threshold : string option
    ; multipart_chunksize : string option
    ; max_bandwidth : string option
    ; use_accelerate_endpoint : string option
    ; use_dualstack_endpoint : string option
    ; addressing_style : string option
    }
  [@@deriving yojson]

  let empty =
    { max_concurrent_requests = None
    ; max_queue_size = None
    ; multipart_threshold = None
    ; multipart_chunksize = None
    ; max_bandwidth = None
    ; use_accelerate_endpoint = None
    ; use_dualstack_endpoint = None
    ; addressing_style = None
    }
  ;;
end

module Ini_file_parser (Stanza : Stanza_spec) (File_env : File_env_spec) = struct
  module Line = struct
    type t =
      [ `Profile of string
      | `Key_val of string * string * bool
      | `Comment
      ]

    let of_string line : (t, string) Result.t =
      let line = String.rstrip line in
      if String.is_prefix line ~prefix:"#"
      then Ok `Comment
      else if String.for_all line ~f:Char.is_whitespace
      then Ok `Comment
      else (
        match String.chop_prefix line ~prefix:"[" with
        | Some x -> (
          match String.chop_suffix x ~suffix:"]" with
          | Some x -> Ok (`Profile (String.strip x))
          | None -> Error (sprintf "line missing closing ]: %S" line))
        | None -> (
          let indented =
            String.is_prefix line ~prefix:" " || String.is_prefix line ~prefix:"\t"
          in
          match String.split line ~on:'=' with
          | [] -> assert false
          | [ x; y ] -> Ok (`Key_val (String.strip x, String.strip y, indented))
          | [ _ ] -> Error (sprintf "invalid line: %S" line)
          | _ -> Error (sprintf "line contains multiple equal characters: %S" line)))
    ;;
  end

  module State = struct
    type t =
      { completed : Stanza.t String.Map.t
      ; cur_name_settings : (string * Stanza.t) option
      ; in_s3_subsection : bool
      }

    let init =
      { completed = String.Map.empty; cur_name_settings = None; in_s3_subsection = false }
    ;;

    let end_profile { completed; cur_name_settings; in_s3_subsection = _ } =
      match cur_name_settings with
      | None -> completed
      | Some (key, data) -> Map.set completed ~key ~data
    ;;

    let start_new_profile ~init ~new_name state =
      let completed = end_profile state in
      match Map.mem completed new_name with
      | true -> Error (sprintf "profile defined multiple times: %S" new_name)
      | false ->
        Ok
          { completed
          ; cur_name_settings = Some (new_name, init)
          ; in_s3_subsection = false
          }
    ;;

    let reduce ~line_num t line =
      match line with
      | `Comment -> Ok t
      | `Profile new_name -> start_new_profile ~init:Stanza.empty ~new_name t
      | `Key_val ("s3", "", true) -> Error "repeated s3= directive"
      | `Key_val ("s3", "", false) -> Ok { t with in_s3_subsection = true }
      | `Key_val (name, value, indented) -> (
        let is_s3_field = t.in_s3_subsection && indented in
        try
          let completed, cur_name_settings =
            Stanza.set_field
              ~is_s3_field
              ~name
              ~value
              ~line_num
              (t.completed, t.cur_name_settings)
          in
          (* in_s3_subsection ends if we stop being indented *)
          Ok { completed; cur_name_settings; in_s3_subsection = is_s3_field }
        with
        | Failure s -> Error s
        | e -> Error (Exn.to_string e))
    ;;
  end

  type t = Stanza.t String.Map.t

  let yojson_of_t m =
    `Assoc (Map.to_alist m |> List.map ~f:(fun (k, v) -> k, Stanza.yojson_of_t v))

  let _t_of_yojson = function
    | `Assoc l ->
      String.Map.of_alist_exn
        (List.map l ~f:(fun (k, v) -> k, Stanza.t_of_yojson v))
    | _ -> failwith "expected object"

  let of_string s =
    s
    |> String.split ~on:'\n'
    |> List.map ~f:Line.of_string
    |> Result.combine_errors
    |> function
    | Error errs -> Error (String.concat ~sep:"; " errs)
    | Ok lines ->
      List.fold_until
        (List.zip_exn (List.range 0 (List.length lines)) lines)
        ~init:State.init
        ~f:(fun acc (i, line) ->
          match State.reduce ~line_num:(Int.succ i) acc line with
          | Ok acc -> Continue acc
          | Error err -> Stop (Error err))
        ~finish:(fun x -> Ok (State.end_profile x))
  ;;

  let path () =
    List.reduce_exn
      ~f:Option.first_some
      [ Sys.getenv_opt File_env.env_var
      ; (match Sys.getenv_opt "HOME" with
         | None -> None
         | Some home -> Some (home ^/ ".aws" ^/ File_env.aws_home_dir_file))
      ]
  ;;
end

module Config_file_stanza = struct
  type redacted = string option

  let yojson_of_redacted (_ : redacted) = `String "<redacted>"
  let redacted_of_yojson j = option_of_yojson string_of_yojson j

  type t =
    { aws_access_key_id : string option
    ; aws_secret_access_key : redacted
    ; aws_session_token : redacted
    ; region : Region.t option
    ; output : string option
    ; ca_bundle : string option
    ; cli_auto_prompt : string option
    ; cli_binary_format : string option
    ; cli_history : string option
    ; cli_pager : string option
    ; cli_timestamp_format : string option
    ; credential_process : string option
    ; credential_source : string option
    ; duration_seconds : string option
    ; external_id : string option
    ; max_attempts : string option
    ; mfa_serial : string option
    ; parameter_validation : string option
    ; retry_mode : string option
    ; role_arn : string option
    ; role_session_name : string option
    ; source_profile : string option
    ; sso_account_id : string option
    ; sso_region : string option
    ; sso_role_name : string option
    ; sso_start_url : string option
    ; web_identity_token_file : string option
    ; tcp_keepalive : string option
    ; s3_custom_command_settings : S3_custom_command_settings.t option
    }
  [@@deriving yojson]

  let empty =
    { aws_access_key_id = None
    ; aws_secret_access_key = None
    ; aws_session_token = None
    ; region = None
    ; output = None
    ; ca_bundle = None
    ; cli_auto_prompt = None
    ; cli_binary_format = None
    ; cli_history = None
    ; cli_pager = None
    ; cli_timestamp_format = None
    ; credential_process = None
    ; credential_source = None
    ; duration_seconds = None
    ; external_id = None
    ; max_attempts = None
    ; mfa_serial = None
    ; parameter_validation = None
    ; retry_mode = None
    ; role_arn = None
    ; role_session_name = None
    ; source_profile = None
    ; sso_account_id = None
    ; sso_region = None
    ; sso_role_name = None
    ; sso_start_url = None
    ; web_identity_token_file = None
    ; tcp_keepalive = None
    ; s3_custom_command_settings = None
    }
  ;;

  let set_field ~is_s3_field ~name ~value ~line_num (completed, name_settings) =
    let message =
      sprintf
        "Line %d: attempting to set field outside of any profile: %S"
        line_num
        name
    in
    match is_s3_field with
    | true ->
      let profile_name, profile = Option.value_exn ~message name_settings in
      let s3 =
        match profile.s3_custom_command_settings with
        | Some x -> x
        | None -> S3_custom_command_settings.empty
      in
      let s3 =
        match name with
        | "max_concurrent_requests" ->
          { s3 with max_concurrent_requests = Some value }
        | "max_queue_size" -> { s3 with max_queue_size = Some value }
        | "multipart_threshold" -> { s3 with multipart_threshold = Some value }
        | "multipart_chunksize" -> { s3 with multipart_chunksize = Some value }
        | "max_bandwidth" -> { s3 with max_bandwidth = Some value }
        | "use_accelerate_endpoint" ->
          { s3 with use_accelerate_endpoint = Some value }
        | "use_dualstack_endpoint" ->
          { s3 with use_dualstack_endpoint = Some value }
        | "addressing_style" -> { s3 with addressing_style = Some value }
        | _ -> failwithf "Line %d: unknown field: %S (s3)" line_num name ()
      in
      let new_profile =
        { profile with s3_custom_command_settings = Some s3 }
      in
      completed, Some (profile_name, new_profile)
    | false ->
      let profile_name, profile = Option.value_exn ~message name_settings in
      let new_profile =
        match name with
        | "aws_access_key_id" -> { profile with aws_access_key_id = Some value }
        | "aws_secret_access_key" -> { profile with aws_secret_access_key = Some value }
        | "aws_session_token" -> { profile with aws_session_token = Some value }
        | "region" -> { profile with region = Some (Region.of_string value) }
        | "output" -> { profile with output = Some value }
        | "ca_bundle" -> { profile with ca_bundle = Some value }
        | "cli_auto_prompt" -> { profile with cli_auto_prompt = Some value }
        | "cli_binary_format" -> { profile with cli_binary_format = Some value }
        | "cli_history" -> { profile with cli_history = Some value }
        | "cli_pager" -> { profile with cli_pager = Some value }
        | "cli_timestamp_format" -> { profile with cli_timestamp_format = Some value }
        | "credential_process" -> { profile with credential_process = Some value }
        | "credential_source" -> { profile with credential_source = Some value }
        | "duration_seconds" -> { profile with duration_seconds = Some value }
        | "external_id" -> { profile with external_id = Some value }
        | "max_attempts" -> { profile with max_attempts = Some value }
        | "mfa_serial" -> { profile with mfa_serial = Some value }
        | "parameter_validation" -> { profile with parameter_validation = Some value }
        | "retry_mode" -> { profile with retry_mode = Some value }
        | "role_arn" -> { profile with role_arn = Some value }
        | "role_session_name" -> { profile with role_session_name = Some value }
        | "source_profile" -> { profile with source_profile = Some value }
        | "sso_account_id" -> { profile with sso_account_id = Some value }
        | "sso_region" -> { profile with sso_region = Some value }
        | "sso_role_name" -> { profile with sso_role_name = Some value }
        | "sso_start_url" -> { profile with sso_start_url = Some value }
        | "web_identity_token_file" -> { profile with web_identity_token_file = Some value }
        | "tcp_keepalive" -> { profile with tcp_keepalive = Some value }
        | _ -> failwithf "Line %d: unknown field: %S" line_num name ()
      in
      completed, Some (profile_name, new_profile)
  ;;
end

module Config_file =
  Ini_file_parser
    (* We cannot inline Config_file_stanza because the Ini_file_parser functor
       aliases and exports the type Config_file_stanza.t, which is a record.
       New types such as records and sum types cannot be defined in anonymous
       modules if they are visible to the outside. *)
    (Config_file_stanza)
    (struct
      let env_var = "AWS_CONFIG_FILE"
      let aws_home_dir_file = "config"
    end)

let%expect_test "File.of_string" =
  let test s =
    match Config_file.of_string s with
    | Error s -> printf "Failed with: %s\n" s
    | Ok r -> r |> Config_file.yojson_of_t |> Yojson.Safe.pretty_to_string |> print_endline
  in
  test
    {|
[default]
region=us-west-2
output=json
aws_access_key_id=AKIAIOSFODNN7EXAMPLE
aws_secret_access_key=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
[profile other_profile]
region=us-east-1
|};
  [%expect
    {|
    {
      "default": {
        "aws_access_key_id": "AKIAIOSFODNN7EXAMPLE",
        "aws_secret_access_key": "<redacted>",
        "aws_session_token": "<redacted>",
        "region": "us-west-2",
        "output": "json",
        "ca_bundle": null,
        "cli_auto_prompt": null,
        "cli_binary_format": null,
        "cli_history": null,
        "cli_pager": null,
        "cli_timestamp_format": null,
        "credential_process": null,
        "credential_source": null,
        "duration_seconds": null,
        "external_id": null,
        "max_attempts": null,
        "mfa_serial": null,
        "parameter_validation": null,
        "retry_mode": null,
        "role_arn": null,
        "role_session_name": null,
        "source_profile": null,
        "sso_account_id": null,
        "sso_region": null,
        "sso_role_name": null,
        "sso_start_url": null,
        "web_identity_token_file": null,
        "tcp_keepalive": null,
        "s3_custom_command_settings": null
      },
      "profile other_profile": {
        "aws_access_key_id": null,
        "aws_secret_access_key": "<redacted>",
        "aws_session_token": "<redacted>",
        "region": "us-east-1",
        "output": null,
        "ca_bundle": null,
        "cli_auto_prompt": null,
        "cli_binary_format": null,
        "cli_history": null,
        "cli_pager": null,
        "cli_timestamp_format": null,
        "credential_process": null,
        "credential_source": null,
        "duration_seconds": null,
        "external_id": null,
        "max_attempts": null,
        "mfa_serial": null,
        "parameter_validation": null,
        "retry_mode": null,
        "role_arn": null,
        "role_session_name": null,
        "source_profile": null,
        "sso_account_id": null,
        "sso_region": null,
        "sso_role_name": null,
        "sso_start_url": null,
        "web_identity_token_file": null,
        "tcp_keepalive": null,
        "s3_custom_command_settings": null
      }
    }
    |}];
  test "";
  [%expect {| {} |}];
  test "[";
  [%expect {| Failed with: line missing closing ]: "[" |}];
  test "output=json";
  [%expect
    {| Failed with: Line 1: attempting to set field outside of any profile: "output" |}];
  test {|
[default]
unknown_field=1
    |};
  [%expect {| Failed with: Line 3: unknown field: "unknown_field" |}];
  test {|
[a]
region=us-east-1
[a]
region=us-east-2
    |};
  [%expect {|
    Failed with: profile defined multiple times: "a" |}];
  test {|
[a]
[b]
[a]
    |};
  [%expect {| Failed with: profile defined multiple times: "a" |}];
  test {|
[a]
no_equal_sign
    |};
  [%expect {| Failed with: invalid line: "no_equal_sign" |}];
  test {|
[a]
a=b=c
    |};
  [%expect {| Failed with: line contains multiple equal characters: "a=b=c" |}]
;;

module Shared_credentials_file_stanza = struct
  type t =
    { aws_access_key_id : string option
    ; aws_secret_access_key : string option
    }
  [@@deriving yojson]

  let empty = { aws_access_key_id = None; aws_secret_access_key = None }

  let set_field ~is_s3_field ~name ~value ~line_num (completed, name_settings) =
    assert (not is_s3_field);
    let message =
      sprintf
        "Line %d: attempting to set field outside of any profile: %S"
        line_num
        name
    in
    let profile_name, profile = Option.value_exn ~message name_settings in
    let new_profile =
      match name with
      | "aws_access_key_id" -> { profile with aws_access_key_id = Some value }
      | "aws_secret_access_key" -> { profile with aws_secret_access_key = Some value }
      | _ -> failwithf "Line %d: unknown field: %S" line_num name ()
    in
    completed, Some (profile_name, new_profile)
  ;;
end

module Shared_credentials_file =
  Ini_file_parser
    (Shared_credentials_file_stanza)
    (struct
      let env_var = "AWS_SHARED_CREDENTIALS_FILE"
      let aws_home_dir_file = "credentials"
    end)

let prefer_right_if_defined a b =
  match a, b with
  | None, None -> None
  | None, Some p -> Some p
  | Some p, None -> Some p
  | Some _, Some b -> Some b
;;

let merge ~(from : Config_file_stanza.t) ~(to_ : Config_file_stanza.t)
  : Config_file_stanza.t
  =
  let mv a b = prefer_right_if_defined a b in
  { aws_access_key_id = mv from.aws_access_key_id to_.aws_access_key_id
  ; aws_secret_access_key = mv from.aws_secret_access_key to_.aws_secret_access_key
  ; aws_session_token = mv from.aws_session_token to_.aws_session_token
  ; region = mv from.region to_.region
  ; output = mv from.output to_.output
  ; ca_bundle = mv from.ca_bundle to_.ca_bundle
  ; cli_auto_prompt = mv from.cli_auto_prompt to_.cli_auto_prompt
  ; cli_binary_format = mv from.cli_binary_format to_.cli_binary_format
  ; cli_history = mv from.cli_history to_.cli_history
  ; cli_pager = mv from.cli_pager to_.cli_pager
  ; cli_timestamp_format = mv from.cli_timestamp_format to_.cli_timestamp_format
  ; credential_process = mv from.credential_process to_.credential_process
  ; credential_source = mv from.credential_source to_.credential_source
  ; duration_seconds = mv from.duration_seconds to_.duration_seconds
  ; external_id = mv from.external_id to_.external_id
  ; max_attempts = mv from.max_attempts to_.max_attempts
  ; mfa_serial = mv from.mfa_serial to_.mfa_serial
  ; parameter_validation = mv from.parameter_validation to_.parameter_validation
  ; retry_mode = mv from.retry_mode to_.retry_mode
  ; role_arn = mv from.role_arn to_.role_arn
  ; role_session_name = mv from.role_session_name to_.role_session_name
  ; source_profile = mv from.source_profile to_.source_profile
  ; sso_account_id = mv from.sso_account_id to_.sso_account_id
  ; sso_region = mv from.sso_region to_.sso_region
  ; sso_role_name = mv from.sso_role_name to_.sso_role_name
  ; sso_start_url = mv from.sso_start_url to_.sso_start_url
  ; web_identity_token_file = mv from.web_identity_token_file to_.web_identity_token_file
  ; tcp_keepalive = mv from.tcp_keepalive to_.tcp_keepalive
  ; s3_custom_command_settings =
      mv from.s3_custom_command_settings to_.s3_custom_command_settings
  }
;;

let make_internal
  ?(config_file : (string * Config_file_stanza.t String.Map.t) option)
  ?shared_credentials_file
  ?profile
  ?aws_access_key_id
  ?aws_secret_access_key
  ?region
  ?output
  ()
  =
  let config_file, config_profiles =
    match config_file with
    | None -> None, String.Map.empty
    | Some (x, y) -> Some x, y
  in
  let config_profile =
    let default = Map.find config_profiles "default" in
    let config_profile =
      match profile with
      | None -> None
      | Some profile -> (
        match Map.find config_profiles (sprintf "profile %s" profile) with
        | Some x -> Some x
        | None ->
          failwithf
            "config file %s doesn't contain requested profile %s"
            (Option.value config_file ~default:"<none>")
            profile
            ())
    in
    (* inherit all of the non-None fields from default, if any *)
    match default, config_profile with
    | None, None -> Config_file_stanza.empty
    | None, Some p -> p
    | Some p, None -> p
    | Some a, Some b -> merge ~from:a ~to_:b
  in
  let credentials_profile : Shared_credentials_file_stanza.t option =
    let credentials_profiles =
      match shared_credentials_file with
      | None -> String.Map.empty
      | Some (_, y) -> y
    in
    let default = Map.find credentials_profiles "default" in
    let credentials_profile = profile |> Option.bind ~f:(Map.find credentials_profiles) in
    (* inherit all of the non-None fields from default, if any *)
    match default, credentials_profile with
    | None, None -> None
    | None, Some p -> Some p
    | Some p, None -> Some p
    | Some a, Some b ->
      Some
        { aws_access_key_id =
            prefer_right_if_defined a.aws_access_key_id b.aws_access_key_id
        ; aws_secret_access_key =
            prefer_right_if_defined a.aws_secret_access_key b.aws_secret_access_key
        }
  in
  let aws_access_key_id =
    List.reduce_exn
      ~f:Option.first_some
      [ aws_access_key_id
      ; Sys.getenv_opt "AWS_ACCESS_KEY_ID"
      ; Option.bind credentials_profile ~f:(fun x -> x.aws_access_key_id)
      ; config_profile.aws_access_key_id
      ]
  in
  let aws_secret_access_key =
    List.reduce_exn
      ~f:Option.first_some
      [ aws_secret_access_key
      ; Sys.getenv_opt "AWS_SECRET_ACCESS_KEY"
      ; Option.bind credentials_profile ~f:(fun x -> x.aws_secret_access_key)
      ; config_profile.aws_secret_access_key
      ]
  in
  let aws_session_token = config_profile.aws_session_token in
  let region =
    List.reduce_exn
      ~f:Option.first_some
      [ region
      ; (match Sys.getenv_opt "AWS_DEFAULT_REGION" with
         | None -> None
         | Some x -> Some (Region.of_string x))
      ; config_profile.region
      ]
  in
  let output = List.reduce_exn ~f:Option.first_some [ output; config_profile.output ] in
  Ok
    { config_profile with
      aws_access_key_id
    ; aws_secret_access_key
    ; aws_session_token
    ; region
    ; output
    }
;;

(* This is the exported Cfg.t. *)
(* 2022-10-21 mbac: this is a copy/paste of Config_file_stanza.t so we could probably use
   ppx_import if we wanted to really avoid the duplication, but we expect this to vary
   in the near future so maybe it's fine like this. *)
type t =
  { aws_access_key_id : string option
  ; aws_secret_access_key : string option
  ; aws_session_token : string option
  ; region : Region.t option
  ; output : string option
  ; ca_bundle : string option
  ; cli_auto_prompt : string option
  ; cli_binary_format : string option
  ; cli_history : string option
  ; cli_pager : string option
  ; cli_timestamp_format : string option
  ; credential_process : string option
  ; credential_source : string option
  ; duration_seconds : string option
  ; external_id : string option
  ; max_attempts : string option
  ; mfa_serial : string option
  ; parameter_validation : string option
  ; retry_mode : string option
  ; role_arn : string option
  ; role_session_name : string option
  ; source_profile : string option
  ; sso_account_id : string option
  ; sso_region : string option
  ; sso_role_name : string option
  ; sso_start_url : string option
  ; web_identity_token_file : string option
  ; tcp_keepalive : string option
  ; s3_custom_command_settings : S3_custom_command_settings.t option
  }
[@@deriving yojson]

let empty =
  { aws_access_key_id = None
  ; aws_secret_access_key = None
  ; aws_session_token = None
  ; region = None
  ; output = None
  ; ca_bundle = None
  ; cli_auto_prompt = None
  ; cli_binary_format = None
  ; cli_history = None
  ; cli_pager = None
  ; cli_timestamp_format = None
  ; credential_process = None
  ; credential_source = None
  ; duration_seconds = None
  ; external_id = None
  ; max_attempts = None
  ; mfa_serial = None
  ; parameter_validation = None
  ; retry_mode = None
  ; role_arn = None
  ; role_session_name = None
  ; source_profile = None
  ; sso_account_id = None
  ; sso_region = None
  ; sso_role_name = None
  ; sso_start_url = None
  ; web_identity_token_file = None
  ; tcp_keepalive = None
  ; s3_custom_command_settings = None
  }
;;

let make
  ?(config_file : (string * Config_file_stanza.t String.Map.t) option)
  ?shared_credentials_file
  ?profile
  ?aws_access_key_id
  ?aws_secret_access_key
  ?region
  ?output
  ()
  =
  match
    make_internal
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
  | Ok c ->
    Ok
      { aws_access_key_id = c.aws_access_key_id
      ; aws_secret_access_key = c.aws_secret_access_key
      ; aws_session_token = c.aws_session_token
      ; region = c.region
      ; output = c.output
      ; ca_bundle = c.ca_bundle
      ; cli_auto_prompt = c.cli_auto_prompt
      ; cli_binary_format = c.cli_binary_format
      ; cli_history = c.cli_history
      ; cli_pager = c.cli_pager
      ; cli_timestamp_format = c.cli_timestamp_format
      ; credential_process = c.credential_process
      ; credential_source = c.credential_source
      ; duration_seconds = c.duration_seconds
      ; external_id = c.external_id
      ; max_attempts = c.max_attempts
      ; mfa_serial = c.mfa_serial
      ; parameter_validation = c.parameter_validation
      ; retry_mode = c.retry_mode
      ; role_arn = c.role_arn
      ; role_session_name = c.role_session_name
      ; source_profile = c.source_profile
      ; sso_account_id = c.sso_account_id
      ; sso_region = c.sso_region
      ; sso_role_name = c.sso_role_name
      ; sso_start_url = c.sso_start_url
      ; web_identity_token_file = c.web_identity_token_file
      ; tcp_keepalive = c.tcp_keepalive
      ; s3_custom_command_settings = c.s3_custom_command_settings
      }
;;

let%test_module "Cfg tests" =
  (module struct
    let test ?profile ?shared_credentials_file ~config_file () =
      match Config_file.of_string config_file with
      | Error s -> printf "Failed with: %s\n" s
      | Ok profiles -> (
        let config_file = "<unknown>", profiles in
        let run shared_credentials_file =
          match make ?shared_credentials_file ~config_file ?profile () with
          | Error s -> printf "Error: %s\n" s
          | Ok r -> r |> yojson_of_t |> Yojson.Safe.pretty_to_string |> print_endline
        in
        match shared_credentials_file with
        | None -> run None
        | Some s -> (
          match Shared_credentials_file.of_string s with
          | Error e -> printf "Failed with: %s\n" e
          | Ok credentials_profiles -> run (Some ("<unknown>", credentials_profiles))))
    ;;

    let config_file =
      {|
[default]
region=us-west-2
output=json
aws_access_key_id=AKIAIOSFODNN7EXAMPLE
aws_secret_access_key=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
[profile other_profile]
region=us-east-1
|}
    ;;

    let config_file_with_s3 =
      {|
[default]
region=us-west-2
output=json
aws_access_key_id=AKIAIOSFODNN7EXAMPLE
aws_secret_access_key=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
[profile other_profile]
region=us-east-1
[profile development]
s3=
  max_concurrent_requests = 20
  max_queue_size = 10000
  multipart_threshold = 64MB
  multipart_chunksize = 16MB
  max_bandwidth = 50MB/s
  use_accelerate_endpoint = true
  addressing_style = path
|}
    ;;

    let shared_credentials_file =
      {|
[default]
aws_access_key_id=aaaaaaaaaaaaaaaaaaaaaaaaa
aws_secret_access_key=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
[other_profile]
aws_access_key_id=bbbbbbbbbbbbbbbbbbbbbbbbbb
aws_secret_access_key=bbbbbbbbbbbbbbbbbbbbbbb
    |}
    ;;

    let%expect_test "File.of_string" =
      test ~config_file ();
      [%expect
        {|
        {
          "aws_access_key_id": "AKIAIOSFODNN7EXAMPLE",
          "aws_secret_access_key": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
          "aws_session_token": null,
          "region": "us-west-2",
          "output": "json",
          "ca_bundle": null,
          "cli_auto_prompt": null,
          "cli_binary_format": null,
          "cli_history": null,
          "cli_pager": null,
          "cli_timestamp_format": null,
          "credential_process": null,
          "credential_source": null,
          "duration_seconds": null,
          "external_id": null,
          "max_attempts": null,
          "mfa_serial": null,
          "parameter_validation": null,
          "retry_mode": null,
          "role_arn": null,
          "role_session_name": null,
          "source_profile": null,
          "sso_account_id": null,
          "sso_region": null,
          "sso_role_name": null,
          "sso_start_url": null,
          "web_identity_token_file": null,
          "tcp_keepalive": null,
          "s3_custom_command_settings": null
        }
        |}];
      test ~profile:"other_profile" ~config_file ();
      [%expect
        {|
        {
          "aws_access_key_id": "AKIAIOSFODNN7EXAMPLE",
          "aws_secret_access_key": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
          "aws_session_token": null,
          "region": "us-east-1",
          "output": "json",
          "ca_bundle": null,
          "cli_auto_prompt": null,
          "cli_binary_format": null,
          "cli_history": null,
          "cli_pager": null,
          "cli_timestamp_format": null,
          "credential_process": null,
          "credential_source": null,
          "duration_seconds": null,
          "external_id": null,
          "max_attempts": null,
          "mfa_serial": null,
          "parameter_validation": null,
          "retry_mode": null,
          "role_arn": null,
          "role_session_name": null,
          "source_profile": null,
          "sso_account_id": null,
          "sso_region": null,
          "sso_role_name": null,
          "sso_start_url": null,
          "web_identity_token_file": null,
          "tcp_keepalive": null,
          "s3_custom_command_settings": null
        }
        |}]
    ;;

    let%expect_test "File.of_string with creds" =
      test ~shared_credentials_file ~config_file ();
      [%expect
        {|
        {
          "aws_access_key_id": "aaaaaaaaaaaaaaaaaaaaaaaaa",
          "aws_secret_access_key": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
          "aws_session_token": null,
          "region": "us-west-2",
          "output": "json",
          "ca_bundle": null,
          "cli_auto_prompt": null,
          "cli_binary_format": null,
          "cli_history": null,
          "cli_pager": null,
          "cli_timestamp_format": null,
          "credential_process": null,
          "credential_source": null,
          "duration_seconds": null,
          "external_id": null,
          "max_attempts": null,
          "mfa_serial": null,
          "parameter_validation": null,
          "retry_mode": null,
          "role_arn": null,
          "role_session_name": null,
          "source_profile": null,
          "sso_account_id": null,
          "sso_region": null,
          "sso_role_name": null,
          "sso_start_url": null,
          "web_identity_token_file": null,
          "tcp_keepalive": null,
          "s3_custom_command_settings": null
        }
        |}];
      test ~profile:"other_profile" ~shared_credentials_file ~config_file ();
      [%expect
        {|
        {
          "aws_access_key_id": "bbbbbbbbbbbbbbbbbbbbbbbbbb",
          "aws_secret_access_key": "bbbbbbbbbbbbbbbbbbbbbbb",
          "aws_session_token": null,
          "region": "us-east-1",
          "output": "json",
          "ca_bundle": null,
          "cli_auto_prompt": null,
          "cli_binary_format": null,
          "cli_history": null,
          "cli_pager": null,
          "cli_timestamp_format": null,
          "credential_process": null,
          "credential_source": null,
          "duration_seconds": null,
          "external_id": null,
          "max_attempts": null,
          "mfa_serial": null,
          "parameter_validation": null,
          "retry_mode": null,
          "role_arn": null,
          "role_session_name": null,
          "source_profile": null,
          "sso_account_id": null,
          "sso_region": null,
          "sso_role_name": null,
          "sso_start_url": null,
          "web_identity_token_file": null,
          "tcp_keepalive": null,
          "s3_custom_command_settings": null
        }
        |}];
      test
        ~profile:"development"
        ~shared_credentials_file
        ~config_file:config_file_with_s3
        ();
      [%expect
        {|
        {
          "aws_access_key_id": "aaaaaaaaaaaaaaaaaaaaaaaaa",
          "aws_secret_access_key": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
          "aws_session_token": null,
          "region": "us-west-2",
          "output": "json",
          "ca_bundle": null,
          "cli_auto_prompt": null,
          "cli_binary_format": null,
          "cli_history": null,
          "cli_pager": null,
          "cli_timestamp_format": null,
          "credential_process": null,
          "credential_source": null,
          "duration_seconds": null,
          "external_id": null,
          "max_attempts": null,
          "mfa_serial": null,
          "parameter_validation": null,
          "retry_mode": null,
          "role_arn": null,
          "role_session_name": null,
          "source_profile": null,
          "sso_account_id": null,
          "sso_region": null,
          "sso_role_name": null,
          "sso_start_url": null,
          "web_identity_token_file": null,
          "tcp_keepalive": null,
          "s3_custom_command_settings": {
            "max_concurrent_requests": "20",
            "max_queue_size": "10000",
            "multipart_threshold": "64MB",
            "multipart_chunksize": "16MB",
            "max_bandwidth": "50MB/s",
            "use_accelerate_endpoint": "true",
            "use_dualstack_endpoint": null,
            "addressing_style": "path"
          }
        }
        |}]
    ;;
  end)
;;
