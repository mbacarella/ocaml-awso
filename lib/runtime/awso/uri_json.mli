type t = Uri.t

val to_string : t -> string
val of_string : string -> t
val compare : t -> t -> int
val equal : t -> t -> bool
val yojson_of_t : t -> Yojson.Safe.t
val t_of_yojson : Yojson.Safe.t -> t
