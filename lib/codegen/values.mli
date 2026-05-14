open! Core
open! Import

val make
  :  awso_service_id:string
  -> submodules:string list
  -> Botodata.service
  -> Parsetree.structure * (string * Parsetree.structure) list
