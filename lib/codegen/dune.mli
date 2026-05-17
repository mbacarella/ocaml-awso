open! Import

val make : service:string -> string
val make_io : [ `Async | `Lwt | `Sync ] -> service:string -> string
val make_awso_cli_dune : services:string list -> string
val make_awso_cli_main : services:string list -> string
val has_addendum : io_kind:[ `Async | `Lwt | `Sync ] -> service:string -> bool
val num_value_submodules : string -> int
val num_cli_submodules : string -> int
