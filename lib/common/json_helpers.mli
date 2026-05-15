val from_string : string -> Yojson.Safe.t
val to_string : Yojson.Safe.t -> string
val member_or_null : string -> Yojson.Safe.t -> Yojson.Safe.t
val field_map : Yojson.Safe.t -> string -> (Yojson.Safe.t -> 'a) -> 'a option
val field_map_exn : Yojson.Safe.t -> string -> (Yojson.Safe.t -> 'a) -> 'a
