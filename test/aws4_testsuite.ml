open! Import

module Req = struct
  let string_of_file filename =
    read_file filename |> String.substr_replace_all ~pattern:"http/1.1" ~with_:"HTTP/1.1"
  ;;

  let request_of_file filename =
    let s = string_of_file filename in
    (* cohttp 6.x's parser requires CRLF + a \r\n\r\n end-of-headers marker.
       Fixtures are a mix of CRLF and LF, with no trailing newline; normalize
       to LF first to avoid turning existing \r\n into \r\r\n. *)
    let s =
      s
      |> String.substr_replace_all ~pattern:"\r\n" ~with_:"\n"
      |> String.substr_replace_all ~pattern:"\n" ~with_:"\r\n"
    in
    let s = if String.is_suffix s ~suffix:"\r\n" then s ^ "\r\n" else s ^ "\r\n\r\n" in
    match Cohttp.Request.of_string s with
    | `Eof -> assert false
    | `Invalid x -> failwith x
    | `Ok x -> x
  ;;

  let body_of_file filename : Cohttp.Body.t =
    let content = read_file filename in
    let lines = String.split content ~on:'\n' in
    let rec loop body_started accum = function
      | [] -> accum
      | "" :: lines -> (
        match body_started with
        | true -> loop body_started ("" :: accum) lines
        | false -> loop true accum lines)
      | x :: lines -> (
        match body_started with
        | true -> loop body_started (x :: accum) lines
        | false -> loop body_started accum lines)
    in
    loop false [] lines |> List.rev |> fun x -> `Strings x
  ;;

  let of_file filename = request_of_file filename, body_of_file filename
end

module Creq = struct
  let of_file filename =
    read_file filename |> String.substr_replace_all ~pattern:"\r\n" ~with_:"\n"
  ;;
end
