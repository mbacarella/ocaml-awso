(* Core/Base compatibility shim — see import.ml for rationale. *)

val sprintf : ('a, unit, string) format -> 'a
val printf : ('a, out_channel, unit) format -> 'a
val eprintf : ('a, out_channel, unit) format -> 'a
val bprintf : Buffer.t -> ('a, Buffer.t, unit) format -> 'a
val failwithf : ('a, unit, string, 'b) format4 -> 'a
val ksprintf : (string -> 'a) -> ('b, unit, string, 'a) format4 -> 'b
val failwithj : here:'c -> string -> 'd -> ('d -> Yojson.Safe.t) -> 'e
val ( ^/ ) : string -> string -> string

val ( = ) : int -> int -> bool
val ( <> ) : int -> int -> bool
val ( < ) : int -> int -> bool
val ( > ) : int -> int -> bool
val ( <= ) : int -> int -> bool
val ( >= ) : int -> int -> bool
val compare : int -> int -> int
val equal : int -> int -> bool
val phys_equal : 'a -> 'a -> bool

module Char : sig
  include module type of Stdlib.Char

  val is_uppercase : char -> bool
  val is_lowercase : char -> bool
end

module Fn : sig
  val id : 'a -> 'a
  val compose : ('b -> 'c) -> ('a -> 'b) -> 'a -> 'c
end

module List : sig
  include module type of Stdlib.List

  val map : 'a list -> f:('a -> 'b) -> 'b list
  val iter : 'a list -> f:('a -> unit) -> unit
  val filter : 'a list -> f:('a -> bool) -> 'a list
  val filter_map : 'a list -> f:('a -> 'b option) -> 'b list
  val find : 'a list -> f:('a -> bool) -> 'a option
  val find_map : 'a list -> f:('a -> 'b option) -> 'b option
  val for_all : 'a list -> f:('a -> bool) -> bool
  val concat_map : 'a list -> f:('a -> 'b list) -> 'b list
  val mapi : 'a list -> f:(int -> 'a -> 'b) -> 'b list
  val fold : 'a list -> init:'b -> f:('b -> 'a -> 'b) -> 'b
  val fold_right : 'a list -> init:'b -> f:('a -> 'b -> 'b) -> 'b
  val fold_left : 'b list -> init:'a -> f:('a -> 'b -> 'a) -> 'a
  val stable_sort : 'a list -> compare:('a -> 'a -> int) -> 'a list
  val sort : 'a list -> compare:('a -> 'a -> int) -> 'a list
  val mem : 'a list -> 'a -> equal:('a -> 'a -> bool) -> bool
  val dedup_and_sort : compare:('a -> 'a -> int) -> 'a list -> 'a list
  val filter_opt : 'a option list -> 'a list
  val is_empty : 'a list -> bool
  val hd_exn : 'a list -> 'a
  val return : 'a -> 'a list
  val partition_tf : 'a list -> f:('a -> bool) -> 'a list * 'a list
  val init : int -> f:(int -> 'a) -> 'a list
  val take : 'a list -> int -> 'a list
  val nth_exn : 'a list -> int -> 'a
  val chunks_of : 'a list -> length:int -> 'a list list

  module Assoc : sig
    type ('k, 'v) t = ('k * 'v) list

    val find : ('k, 'v) t -> 'k -> equal:('k -> 'k -> bool) -> 'v option
    val find_exn : ('k, 'v) t -> 'k -> equal:('k -> 'k -> bool) -> 'v
  end
end

module String : sig
  include module type of Stdlib.String

  val equal : string -> string -> bool
  val concat : ?sep:string -> string list -> string
  val map : string -> f:(char -> char) -> string
  val capitalize : string -> string
  val uncapitalize : string -> string
  val lowercase : string -> string
  val is_prefix : string -> prefix:string -> bool
  val is_suffix : string -> suffix:string -> bool
  val of_char : char -> string
  val strip : string -> string
  val lsplit2 : string -> on:char -> (string * string) option
  val chop_suffix_exn : string -> suffix:string -> string
  val chop_prefix : string -> prefix:string -> string option
  val concat_map : string -> f:(char -> string) -> string
  val split : string -> on:char -> string list
  val substr_replace_all : string -> pattern:string -> with_:string -> string
  val ( = ) : string -> string -> bool

  module Set : sig
    include Set.S with type elt = string

    val of_list : string list -> t
    val to_list : t -> string list
  end

  module Map : sig
    include Map.S with type key = string

    val of_alist_exn : (string * 'a) list -> 'a t
    val find_exn : string -> 'a t -> 'a
  end

  module Table : sig
    val create : unit -> (string, 'a) Stdlib.Hashtbl.t
  end

  module Caseless : sig
    val equal : string -> string -> bool
  end
end

module Set : sig
  type 'a t = String.Set.t

  val diff : 'a t -> 'a t -> 'a t
  val to_list : 'a t -> string list
  val add : 'a t -> string -> 'a t
  val mem : 'a t -> string -> bool
  val is_empty : 'a t -> bool
  val of_list : string list -> 'a t
  val empty : 'a t
end

module Map : sig
  type ('k, 'v) t = 'v String.Map.t

  val find : ('k, 'v) t -> string -> 'v option
  val find_exn : ('k, 'v) t -> string -> 'v
  val of_alist_exn : (string * 'v) list -> (string, 'v) t
end

module Hashtbl : sig
  include module type of Stdlib.Hashtbl

  val add_exn : ('a, 'b) t -> key:'a -> data:'b -> unit
  val find : ('a, 'b) t -> 'a -> 'b option
end

module Option : sig
  val value : 'a option -> default:'a -> 'a
  val value_exn : ?here:'c -> ?error:'d -> ?message:string -> 'a option -> 'a
  val map : 'a option -> f:('a -> 'b) -> 'b option
  val bind : 'a option -> f:('a -> 'b option) -> 'b option
  val is_some : 'a option -> bool
  val is_none : 'a option -> bool
  val some : 'a -> 'a option
  val some_if : bool -> 'a -> 'a option
  val first_some : 'a option -> 'a option -> 'a option
  val try_with : (unit -> 'a) -> 'a option
  val equal : ('a -> 'a -> bool) -> 'a option -> 'a option -> bool
  val ( >>| ) : 'a option -> ('a -> 'b) -> 'b option
  val ( >>= ) : 'a option -> ('a -> 'b option) -> 'b option

  module Let_syntax : sig
    module Let_syntax : sig
      val map : 'a option -> f:('a -> 'b) -> 'b option
      val bind : 'a option -> f:('a -> 'b option) -> 'b option
      val both : 'a option -> 'b option -> ('a * 'b) option
    end

    val ( >>| ) : 'a option -> ('a -> 'b) -> 'b option
    val ( >>= ) : 'a option -> ('a -> 'b option) -> 'b option
  end
end

module Result : sig
  type ('a, 'e) t = ('a, 'e) result

  val map : ('a, 'e) t -> f:('a -> 'b) -> ('b, 'e) t
  val map_error : ('a, 'e) t -> f:('e -> 'f) -> ('a, 'f) t
  val bind : ('a, 'e) t -> f:('a -> ('b, 'e) t) -> ('b, 'e) t
  val all : ('a, 'e) t list -> ('a list, 'e) t
  val failf : ('a, unit, string, ('b, string) t) format4 -> 'a
  val ok_or_failwith : ('a, string) t -> 'a
  val of_option : 'a option -> error:'e -> ('a, 'e) t
  val return : 'a -> ('a, 'e) t
  val try_with : (unit -> 'a) -> ('a, exn) t

  module Let_syntax : sig
    module Let_syntax : sig
      val map : ('a, 'e) t -> f:('a -> 'b) -> ('b, 'e) t
      val bind : ('a, 'e) t -> f:('a -> ('b, 'e) t) -> ('b, 'e) t
      val both : ('a, 'e1) t -> ('b, 'e1) t -> ('a * 'b, 'e1) t
    end
  end
end

module Sexp : sig
  type t =
    | Atom of string
    | List of t list

  val to_string : t -> string
end

module Uri_json : sig
  type t = Uri.t

  val to_string : t -> string
  val of_string : string -> t
  val compare : t -> t -> int
  val equal : t -> t -> bool
  val yojson_of_t : t -> Yojson.Safe.t
  val t_of_yojson : Yojson.Safe.t -> t
end

module Int : sig
  include module type of Stdlib.Int

  val ( > ) : int -> int -> bool
  val ( < ) : int -> int -> bool
  val ( >= ) : int -> int -> bool
  val ( <= ) : int -> int -> bool
  val ( = ) : int -> int -> bool
  val to_string : int -> string
  val of_string : string -> int
  val of_float : float -> int
  val to_int64 : int -> int64
  val max_value : int
end

module Int64 : sig
  include module type of Stdlib.Int64

  val of_float : float -> int64
end

module Float : sig
  include module type of Stdlib.Float

  val of_int : int -> float
  val to_int : float -> int
  val round_up : float -> float
  val ( / ) : float -> float -> float
end

module Bool : sig
  include module type of Stdlib.Bool

  val to_string : bool -> string
  val of_string : string -> bool
  val equal : bool -> bool -> bool
end

module Memo : sig
  val general : ('a -> 'b) -> 'a -> 'b
end

module Process : sig
  type exit_result =
    | Exited of int
    | Signaled of int

  module Output : sig
    type t =
      { exit_result : exit_result
      ; stdout : string
      ; stderr : string
      }
  end

  val run : prog:string -> args:string list -> (Output.t, exn) result
end

module Sys_unix : sig
  val ls_dir : string -> string list
  val is_directory_exn : string -> bool
  val is_directory : string -> [> `No | `Unknown | `Yes ]
  val is_file : string -> [> `No | `Unknown | `Yes ]
  val remove : string -> unit
end

module Util : sig
  val mkdir_exn : string -> unit
  val camel_to_snake_case : ?sep:char -> string -> string

  val tokenize
    :  (Sedlexing.lexbuf -> ('a option, 'err) result)
    -> string
    -> ('a list, 'err) result

  val to_string_of_printer : (Format.formatter -> 'a -> unit) -> 'a -> string
  val structure_to_string : Parsetree.structure -> string
  val signature_to_string : Parsetree.signature -> string
  val expression_to_string : Parsetree.expression -> string
  val core_type_to_string : Parsetree.core_type -> string
end

val read_file : string -> string
val write_file : string -> string -> unit
