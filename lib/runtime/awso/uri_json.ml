open! Import

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
     @ (if Stdlib.( = ) path "" then [] else [ "path", `String path ])
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
