include Awso_common.Jane_compat

let failwithj ~here:_ msg v to_json =
  let json_str = Yojson.Safe.pretty_to_string (to_json v) in
  failwith (msg ^ ": " ^ json_str)
;;

module Sexp = struct
  type t =
    | Atom of string
    | List of t list

  let rec to_string = function
    | Atom s ->
      if
        Stdlib.String.contains s ' '
        || Stdlib.String.contains s '"'
        || Stdlib.String.contains s '('
        || Stdlib.String.contains s ')'
        || Stdlib.String.length s = 0
      then sprintf "%S" s
      else s
    | List l -> sprintf "(%s)" (Stdlib.String.concat " " (Stdlib.List.map to_string l))
  ;;
end

module Uri_json = struct
  type t = Uri.t

  let to_string uri = Uri.to_string uri
  let of_string = Uri.of_string
  let compare = Uri.compare
  let equal = Uri.equal

  let yojson_of_t uri =
    let opt key f =
      match f uri with
      | Some v -> [ key, `String v ]
      | None -> []
    in
    let opt_int key f =
      match f uri with
      | Some v -> [ key, `Int v ]
      | None -> []
    in
    let path = Uri.path uri in
    let query = Uri.query uri in
    `Assoc
      (opt "scheme" Uri.scheme
       @ opt "userinfo" Uri.userinfo
       @ opt "host" Uri.host
       @ opt_int "port" Uri.port
       @ (if String.( = ) path "" then [] else [ "path", `String path ])
       @ (match query with
          | [] -> []
          | _ ->
            [ ( "query"
              , `Assoc
                  (Stdlib.List.map
                     (fun (k, vs) -> k, `List (Stdlib.List.map (fun v -> `String v) vs))
                     query) )
            ])
       @ opt "fragment" Uri.fragment)
  ;;

  let t_of_yojson = function
    | `String s -> Uri.of_string s
    | `Assoc fields ->
      let get key =
        match Stdlib.List.assoc_opt key fields with
        | Some (`String s) -> Some s
        | _ -> None
      in
      let port =
        match Stdlib.List.assoc_opt "port" fields with
        | Some (`Int n) -> Some n
        | _ -> None
      in
      let query =
        match Stdlib.List.assoc_opt "query" fields with
        | Some (`Assoc pairs) ->
          Stdlib.List.map
            (fun (k, v) ->
               let vs =
                 match v with
                 | `List l ->
                   Stdlib.List.filter_map
                     (function
                       | `String s -> Some s
                       | _ -> None)
                     l
                 | _ -> []
               in
               k, vs)
            pairs
        | _ -> []
      in
      Uri.make
        ?scheme:(get "scheme")
        ?userinfo:(get "userinfo")
        ?host:(get "host")
        ?port
        ~path:(Stdlib.Option.value ~default:"" (get "path"))
        ~query
        ?fragment:(get "fragment")
        ()
    | _ -> failwith "Uri_json.t_of_yojson: expected string or object"
  ;;
end

(* Process.run uses Unix.select to simultaneously drain stdout and stderr,
   avoiding deadlocks when a subprocess writes a lot to stderr. *)
module Process = struct
  type exit_result =
    | Exited of int
    | Signaled of int

  module Output = struct
    type t =
      { exit_result : exit_result
      ; stdout : string
      ; stderr : string
      }
  end

  let run ~prog ~args : (Output.t, exn) result =
    Result.try_with (fun () ->
      let argv = Array.of_list (prog :: args) in
      let stdout_r, stdin_w, stderr_r =
        Unix.open_process_args_full prog argv (Unix.environment ())
      in
      close_out stdin_w;
      let outbuf = Buffer.create 4096 in
      let errbuf = Buffer.create 4096 in
      let buf = Bytes.create 8192 in
      let stdout_fd = Unix.descr_of_in_channel stdout_r in
      let stderr_fd = Unix.descr_of_in_channel stderr_r in
      let read_into fd buffer =
        let n = Unix.read fd buf 0 (Bytes.length buf) in
        if n > 0 then Buffer.add_subbytes buffer buf 0 n;
        n > 0
      in
      let rec drain fds =
        match fds with
        | [] -> ()
        | _ ->
          let readable, _, _ = Unix.select fds [] [] (-1.0) in
          let fds =
            Stdlib.List.fold_left
              (fun fds fd ->
                 if Stdlib.List.mem fd readable
                 then (
                   let buffer = if Stdlib.( = ) fd stdout_fd then outbuf else errbuf in
                   if read_into fd buffer
                   then fds
                   else Stdlib.List.filter (fun fd' -> not (Stdlib.( = ) fd' fd)) fds)
                 else fds)
              fds
              fds
          in
          drain fds
      in
      drain [ stdout_fd; stderr_fd ];
      let status = Unix.close_process_full (stdout_r, stdin_w, stderr_r) in
      let exit_result =
        match status with
        | Unix.WEXITED n -> Exited n
        | Unix.WSIGNALED n -> Signaled n
        | Unix.WSTOPPED n -> Signaled n
      in
      { Output.exit_result
      ; stdout = Buffer.contents outbuf
      ; stderr = Buffer.contents errbuf
      })
  ;;
end

module Sys_unix = struct
  let ls_dir dir =
    let h = Unix.opendir dir in
    let rec loop acc =
      match Unix.readdir h with
      | name -> loop (name :: acc)
      | exception End_of_file -> acc
    in
    let entries = loop [] in
    Unix.closedir h;
    Stdlib.List.filter
      (fun n -> (not (Stdlib.String.equal n ".")) && not (Stdlib.String.equal n ".."))
      entries
    |> Stdlib.List.sort Stdlib.String.compare
  ;;

  let is_directory_exn path = Sys.is_directory path

  let is_directory path =
    try if Sys.is_directory path then `Yes else `No with
    | Sys_error _ -> `Unknown
  ;;

  let is_file path =
    try if Sys.file_exists path && not (Sys.is_directory path) then `Yes else `No with
    | Sys_error _ -> `Unknown
  ;;

  let remove = Sys.remove
end

module Util = struct
  let mkdir_exn (dir : string) : unit =
    if Stdlib.Sys.file_exists dir
    then (
      match Sys_unix.is_directory dir with
      | `Yes -> ()
      | `No | `Unknown ->
        failwithf "cannot make directory %s: path exists but is not a directory" dir ())
    else (
      try Unix.mkdir dir 0o755 with
      | Unix.Unix_error (Unix.EEXIST, _, _) -> ())
  ;;

  let camel_to_snake_case ?(sep = '_') (s : string) : string =
    String.uncapitalize s
    |> String.concat_map ~f:(fun c ->
      if Char.is_uppercase c
      then Printf.sprintf "%c%c" sep (Char.lowercase_ascii c)
      else String.of_char c)
  ;;

  let%expect_test "camel_to_snake_case" =
    let test s = print_endline (camel_to_snake_case s) in
    test "AbortMultipartUpload";
    [%expect "abort_multipart_upload"];
    test "CompleteMultipartUpload";
    [%expect "complete_multipart_upload"]
  ;;

  let tokenize (read_token : Sedlexing.lexbuf -> ('a option, 'err) result) (s : string)
    : ('a list, 'err) result
    =
    let lexbuf = Sedlexing.Latin1.from_string s in
    let accum = ref [] in
    let rec loop () =
      match read_token lexbuf with
      | Error _ as e -> e
      | Ok None -> Ok ()
      | Ok (Some tok) ->
        accum := tok :: !accum;
        loop ()
    in
    match loop () with
    | Ok () -> Ok (Stdlib.List.rev !accum)
    | Error _ as e -> e
  ;;

  let to_string_of_printer (f : Format.formatter -> 'a -> unit) : 'a -> string =
    fun x ->
    let buf = Buffer.create 128 in
    let fmt = Format.formatter_of_buffer buf in
    f fmt x;
    Format.pp_print_flush fmt ();
    Buffer.contents buf
  ;;

  let structure_to_string : Parsetree.structure -> string =
    to_string_of_printer Pprintast.structure
  ;;

  let signature_to_string : Parsetree.signature -> string =
    to_string_of_printer Pprintast.signature
  ;;

  let expression_to_string : Parsetree.expression -> string =
    to_string_of_printer Pprintast.expression
  ;;

  let core_type_to_string : Parsetree.core_type -> string =
    to_string_of_printer Pprintast.core_type
  ;;
end
