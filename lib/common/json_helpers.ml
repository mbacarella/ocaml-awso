let from_string s = Yojson.Safe.from_string s
let to_string (v : Yojson.Safe.t) = Yojson.Safe.to_string v

let member_or_null s (v : Yojson.Safe.t) =
  Yojson.Safe.Util.member s v

let field_map (x : Yojson.Safe.t) field_name f =
  match x with
  | `Assoc fields -> (
    match List.assoc_opt field_name fields with
    | None | Some `Null -> None
    | Some value -> Some (f value))
  | _ -> raise (Yojson.Safe.Util.Type_error ("Expected Assoc", x))

let field_map_exn (x : Yojson.Safe.t) field_name f =
  match x with
  | `Assoc fields -> (
    match List.assoc_opt field_name fields with
    | Some value -> f value
    | None ->
      raise
        (Yojson.Safe.Util.Type_error
           (Printf.sprintf "Expected field '%s'" field_name, x)))
  | _ -> raise (Yojson.Safe.Util.Type_error ("Expected Assoc", x))
