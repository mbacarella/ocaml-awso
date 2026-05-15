open! Import

let unsupported_services : String.Set.t =
  String.Set.of_list
    [ "apigateway"
    ; "apigatewayv2"
    ; "appconfig"
    ; "appconfigdata"
    ; "appsync"
    ; "cloudhsm"
    ; "codeguruprofiler"
    ; "dataexchange"
    ; "health"
    ; "iottwinmaker"
    ; "lex-runtime"
    ; "lexv2-runtime"
    ; "lookoutvision"
    ; "mediaconnect"
    ; "medialive"
    ; "mq"
    ; "pinpoint"
    ; "s3control"
    ; "sagemaker-runtime"
    ; "workmailmessageflow"
    ]
;;

let get_all_services ~(botocore_data : string) : string list =
  Sys_unix.ls_dir botocore_data
  |> List.filter ~f:(fun ent -> Sys_unix.is_directory_exn (botocore_data ^/ ent))
  |> List.sort ~compare:String.compare
;;

let latest_date ~botocore_data ~service =
  let dir = botocore_data ^/ service in
  match Sys_unix.is_directory_exn dir with
  | false -> Error `Unknown_directory
  | true ->
    let date =
      dir
      |> Sys_unix.ls_dir
      |> List.sort ~compare:String.compare
      |> List.rev
      |> List.hd_exn
    in
    Ok date
;;

(* Simple argument parser replacing Core.Command *)
module Arg : sig
  type t
  val create : string array -> t
  val flag_required : t -> string -> string
  val flag_optional : t -> string -> string option
  val flag_listed : t -> string -> string list
end = struct
  type t = string list ref

  let create argv = ref (Array.to_list argv)

  let flag_required args name =
    let argv = !args in
    let rec extract acc = function
      | [] -> failwithf "Required flag %s not found" name ()
      | k :: v :: rest when String.( = ) k name ->
        args := List.rev acc @ rest;
        v
      | x :: rest -> extract (x :: acc) rest
    in
    extract [] argv

  let flag_optional args name =
    let argv = !args in
    let rec extract acc = function
      | [] -> args := List.rev acc; None
      | k :: v :: rest when String.( = ) k name ->
        args := List.rev acc @ rest;
        Some v
      | x :: rest -> extract (x :: acc) rest
    in
    extract [] argv

  let flag_listed args name =
    let rec aux acc =
      match flag_optional args name with
      | None -> List.rev acc
      | Some v -> aux (v :: acc)
    in
    aux []
end

let botocore_endpoints argv =
  let args = Arg.create argv in
  let file = Arg.flag_required args "--endpoints" in
  let endpoints = file |> read_file |> Botocore_endpoints.of_json in
  let loc = !Ast_helper.default_loc in
  let structure =
    [%str open! Core]
    @ [ Botocore_endpoints.make_lookup_uri endpoints
      ; Botocore_endpoints.make_lookup_credential_scope endpoints
      ]
  in
  print_endline (Util.structure_to_string structure)
;;

module Service = struct
  let dune argv =
    let args = Arg.create argv in
    let service = Arg.flag_required args "--service" in
    let date = Arg.flag_required args "--service-date" in
    Dune.make ~date ~service |> print_endline
  ;;

  let endpoints argv =
    let args = Arg.create argv in
    let service = Arg.flag_required args "--service" in
    let impl = Arg.flag_required args "--impl" in
    let loc = !Ast_helper.default_loc in
    let data =
      service
      |> read_file
      |> Botocore_service.of_json
      |> Service_endpoints.make
      |> fun s -> [%str open! Core] @ s
      |> Util.structure_to_string
    in
    write_file impl data
  ;;

  let values argv =
    let args = Arg.create argv in
    let awso_service_id = Arg.flag_required args "--service-id" in
    let service = Arg.flag_required args "--service" in
    let impl = Arg.flag_required args "--impl" in
    let submodules = Arg.flag_listed args "--sub" in
    let service = service |> read_file |> Botocore_service.of_json in
    let main_module, submodules =
      Values.make ~awso_service_id ~submodules service
    in
    write_file impl (main_module |> Util.structure_to_string);
    submodules
    |> List.iter ~f:(fun (filename, struct_) ->
         write_file filename (struct_ |> Util.structure_to_string))
  ;;

  let dispatch argv =
    match argv with
    | [| |] -> failwith "Usage: service {dune|endpoints|values} [args...]"
    | _ ->
      let sub = argv.(0) in
      let rest = Array.sub argv 1 (Array.length argv - 1) in
      match sub with
      | "dune" -> dune rest
      | "endpoints" -> endpoints rest
      | "values" -> values rest
      | s -> failwithf "Unknown service subcommand: %s" s ()
  ;;
end

module Service_io = struct
  let dune argv =
    let args = Arg.create argv in
    let service = Arg.flag_required args "--service" in
    let date = Arg.flag_required args "--service-date" in
    let io_subsystem = Arg.flag_required args "--io-subsystem" in
    let io_subsystem =
      match io_subsystem with
      | "async" -> `Async
      | "lwt" -> `Lwt
      | s -> failwithf "Unknown io-subsystem: %s" s ()
    in
    Dune.make_io io_subsystem ~date ~service |> print_endline
  ;;

  let values argv =
    let args = Arg.create argv in
    let service = Arg.flag_required args "--service" in
    let service =
      service
      |> String.map ~f:(function
           | '-' -> '_'
           | c -> c)
    in
    printf
      {|(* do not edit! generated module *)
    include Awso_%s.Values|}
      service
  ;;

  let io argv =
    let args = Arg.create argv in
    let service = Arg.flag_required args "--service" in
    let impl = Arg.flag_required args "--impl" in
    let intf = Arg.flag_required args "--intf" in
    let base_module = Arg.flag_required args "--base-module" in
    let io_subsystem = Arg.flag_required args "--io-subsystem" in
    let io_subsystem =
      match io_subsystem with
      | "async" -> `Async
      | "lwt" -> `Lwt
      | s -> failwithf "Unknown io-subsystem: %s" s ()
    in
    let service = service |> read_file |> Botocore_service.of_json in
    let endpoints =
      service.operations |> List.map ~f:(Endpoint.of_botodata ~service)
    in
    Io.eval_structure ~base_module ~io_subsystem endpoints
    |> Util.structure_to_string
    |> write_file impl;
    Io.eval_signature
      ~protocol:service.metadata.protocol
      ~base_module
      ~io_subsystem
      endpoints
    |> Util.signature_to_string
    |> write_file intf
  ;;

  let cli argv =
    let args = Arg.create argv in
    let service = Arg.flag_required args "--service" in
    let impl = Arg.flag_required args "--impl" in
    let submodules = Arg.flag_listed args "--sub" in
    let service = service |> read_file |> Botocore_service.of_json in
    let main_module, submodules = Cli.make ~submodules service in
    write_file impl (main_module |> Util.structure_to_string);
    submodules
    |> List.iter ~f:(fun (filename, struct_) ->
         write_file filename (struct_ |> Util.structure_to_string))
  ;;

  let dispatch argv =
    match argv with
    | [| |] -> failwith "Usage: service-io {dune|cli|io|values} [args...]"
    | _ ->
      let sub = argv.(0) in
      let rest = Array.sub argv 1 (Array.length argv - 1) in
      match sub with
      | "dune" -> dune rest
      | "cli" -> cli rest
      | "io" -> io rest
      | "values" -> values rest
      | s -> failwithf "Unknown service-io subcommand: %s" s ()
  ;;
end

module Cli_cmd = struct
  let dune argv =
    let args = Arg.create argv in
    let service = Arg.flag_required args "--service" in
    Dune.make_cli_async ~service |> print_endline
  ;;

  let script argv =
    let args = Arg.create argv in
    let service = Arg.flag_required args "--service" in
    let service =
      service
      |> String.map ~f:(function
           | '-' -> '_'
           | c -> c)
    in
    printf
      {|(* do not edit! generated module *)

    let () = Command_unix.run Awso_%s_async.Cli.main
    |}
      service
  ;;

  let dispatch argv =
    match argv with
    | [| |] -> failwith "Usage: cli {dune|script} [args...]"
    | _ ->
      let sub = argv.(0) in
      let rest = Array.sub argv 1 (Array.length argv - 1) in
      match sub with
      | "dune" -> dune rest
      | "script" -> script rest
      | s -> failwithf "Unknown cli subcommand: %s" s ()
  ;;
end

module Services = struct
  let main argv =
    let args = Arg.create argv in
    let botocore_data = Arg.flag_required args "--botocore-data" in
    let outdir = Arg.flag_required args "-o" in
    let services_opt = Arg.flag_optional args "--services" in
    let services =
      match services_opt with
      | Some x -> x |> String.split ~on:',' |> List.map ~f:String.strip
      | None ->
        let all = get_all_services ~botocore_data |> String.Set.of_list in
        let unsupported = unsupported_services in
        Set.diff all unsupported |> Set.to_list
    in
    let temp_file = Filename.temp_file "dune" "" in
    let print_dune_file ~outdir ~data =
      write_file temp_file data;
      let prog = "dune" in
      let args = [ "format-dune-file"; temp_file ] in
      match Process.run ~prog ~args with
      | Error exn ->
        failwithf
          "%s %s\n%s"
          prog
          (String.concat ~sep:" " args)
          (Printexc.to_string exn)
          ()
      | Ok { exit_result; stdout; stderr = _ } -> (
        match exit_result with
        | Signaled n ->
          failwithf "dune format-dune-file killed by signal %d" n ()
        | Exited n when n <> 0 ->
          failwithf "dune format-dune-file exited with code %d" n ()
        | Exited _ ->
          Util.mkdir_exn outdir;
          write_file (outdir ^/ "dune") stdout)
    in
    services
    |> List.iter ~f:(fun service ->
         match latest_date ~botocore_data ~service with
         | Error `Unknown_directory ->
           failwithf "Unknown directory: %s/%s" botocore_data service ()
         | Ok date ->
           print_dune_file
             ~outdir:(outdir ^/ service)
             ~data:(Dune.make ~date ~service);
           print_dune_file
             ~outdir:(outdir ^/ service ^ "-lwt")
             ~data:(Dune.make_io `Lwt ~date ~service);
           print_dune_file
             ~outdir:(outdir ^/ service ^ "-async")
             ~data:(Dune.make_io `Async ~date ~service);
           print_dune_file
             ~outdir:(outdir ^/ service ^ "-cli-async")
             ~data:(Dune.make_cli_async ~service));
    Sys_unix.remove temp_file
  ;;
end

module Build_service_module = struct
  let main argv =
    let args = Arg.create argv in
    let botocore_data = Arg.flag_required args "--botocore-data" in
    let services_opt = Arg.flag_optional args "--services" in
    let services =
      match services_opt with
      | Some x -> x |> String.split ~on:',' |> List.map ~f:String.strip
      | None ->
        let all = get_all_services ~botocore_data |> String.Set.of_list in
        Set.diff all unsupported_services |> Set.to_list
    in
    let service_entries =
      List.map services ~f:(fun service ->
        match latest_date ~botocore_data ~service with
        | Error `Unknown_directory ->
          failwithf "Unknown directory: %s/%s" botocore_data service ()
        | Ok date ->
          let service_under =
            String.map service ~f:(function '-' -> '_' | c -> c)
          in
          sprintf "  let %s = %S" service_under date)
    in
    let ml_content =
      "(* Auto-generated. Do not edit. *)\n"
      ^ String.concat ~sep:"\n" service_entries
      ^ "\n"
    in
    let mli_content =
      "(* Auto-generated. Do not edit. *)\n"
      ^ String.concat ~sep:"\n"
          (List.map services ~f:(fun service ->
            let service_under =
              String.map service ~f:(function '-' -> '_' | c -> c)
            in
            sprintf "  val %s : string" service_under))
      ^ "\n"
    in
    write_file "service.ml" ml_content;
    write_file "service.mli" mli_content
  ;;
end

let main argv =
  match argv with
  | [| |] ->
    eprintf
      "Usage: awso-codegen {botocore-endpoints|service|service-io|services|cli|build-service-module} [args...]\n";
    exit 1
  | _ ->
    let sub = argv.(0) in
    let rest = Array.sub argv 1 (Array.length argv - 1) in
    match sub with
    | "botocore-endpoints" -> botocore_endpoints rest
    | "service" -> Service.dispatch rest
    | "service-io" -> Service_io.dispatch rest
    | "services" -> Services.main rest
    | "cli" -> Cli_cmd.dispatch rest
    | "build-service-module" -> Build_service_module.main rest
    | s -> failwithf "Unknown command: %s" s ()
;;
