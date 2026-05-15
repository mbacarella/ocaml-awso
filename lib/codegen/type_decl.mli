open! Core
open! Import

(* Make a type declaration corresponding to the name and type returned by
    [error_cases]. *)
val type_declaration_of_errors : Botodata.operation -> Parsetree.type_declaration
val error_to_json_of_errors : Botodata.operation -> Parsetree.structure_item

(* Compute the type declarations corresponding to a shape: [type t = bool] for
    a boolean shape, etc. *)
val type_declarations_of_shape
  :  ?result_wrapper:string
  -> ?priv:Asttypes.private_flag
  -> Botodata.shape
  -> Parsetree.type_declaration list
