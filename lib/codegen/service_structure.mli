open! Core
open! Import

val constants_of_service
  :  awso_service_id:string
  -> Botodata.service
  -> Parsetree.structure

val shape_modules : Botodata.service -> Parsetree.structure
