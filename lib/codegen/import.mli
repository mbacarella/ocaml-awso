include module type of Awso_common.Jane_compat

val failwithj : here:'c -> string -> 'd -> ('d -> Yojson.Safe.t) -> 'e

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
