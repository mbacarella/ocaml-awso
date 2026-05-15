open! Import

val make : service:string -> string
val make_io : [ `Async | `Lwt ] -> service:string -> string
val make_cli_async : service:string -> string
val has_addendum : io_kind:[ `Async | `Lwt ] -> service:string -> bool
val num_value_submodules : string -> int
val num_cli_submodules : string -> int
