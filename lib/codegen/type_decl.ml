open! Import

let strip_html s =
  let s = Re.replace_string (Re.Perl.compile_pat "<[^>]*>") ~by:"" s in
  let s = String.substr_replace_all s ~pattern:"&amp;" ~with_:"&" in
  let s = String.substr_replace_all s ~pattern:"&lt;" ~with_:"<" in
  let s = String.substr_replace_all s ~pattern:"&gt;" ~with_:">" in
  let s = String.substr_replace_all s ~pattern:"&quot;" ~with_:"\"" in
  let s = String.substr_replace_all s ~pattern:"&#39;" ~with_:"'" in
  let s = Re.replace_string (Re.Perl.compile_pat "\\s+") ~by:" " s in
  String.strip s

let doc_attribute = function
  | None | Some "" -> []
  | Some html ->
    let text = strip_html html in
    if String.is_empty text then []
    else
      let loc = !Ast_helper.default_loc in
      [{ attr_name = { txt = "ocaml.doc"; loc }
       ; attr_payload = PStr [%str [%e Ast_convenience.str text]]
       ; attr_loc = loc
       }]

let documentation_of_shape = function
  | Botodata.Boolean_shape s -> s.documentation
  | Long_shape s -> s.documentation
  | Double_shape s -> s.documentation
  | Float_shape s -> s.documentation
  | Blob_shape s -> s.documentation
  | Integer_shape s -> s.documentation
  | String_shape s -> s.documentation
  | List_shape _ -> None
  | Enum_shape _ -> None
  | Structure_shape s -> s.documentation
  | Timestamp_shape s -> s.documentation
  | Map_shape _ -> None

let type_declaration ?kind ?manifest ?priv ?(attrs=[]) n =
  Ast_helper.Type.mk
    ~attrs
    (Ast_convenience.mknoloc (Shape.uncapitalized_id n))
    ?manifest
    ?kind
    ?priv
;;

let error_cases (op : Botodata.operation) =
  let loc = !Ast_helper.default_loc in
  let case name typ =
    { prf_desc = Rtag ({ txt = name; loc = Location.none }, false, [ typ ])
    ; prf_loc = Location.none
    ; prf_attributes = []
    }
  in
  let error_cases =
    op.errors
    |> Option.value ~default:[]
    |> List.map ~f:(fun (e : Botodata.operation_error) -> e.shape)
    |> List.dedup_and_sort ~compare:String.compare
    |> List.map ~f:(fun shape ->
         case (Shape.capitalized_id shape) (Shape.core_type_of_shape shape))
  in
  (*let name = sprintf "%s_error" (Shape.uncapitalized_id op.name) in*)
  let name = "error" in
  let catch_all_error_case =
    case "Unknown_operation_error" [%type: string * string option]
  in
  ( name
  , Ast_helper.Typ.mk
      (Ptyp_variant (error_cases @ [ catch_all_error_case ], Closed, None)) )
;;

let type_declaration_of_errors op =
  let name, manifest = error_cases op in
  type_declaration ~manifest name
;;

let error_to_json_of_errors (op : Botodata.operation) =
  let loc = !Ast_helper.default_loc in
  let error_shapes =
    op.errors
    |> Option.value ~default:[]
    |> List.map ~f:(fun (e : Botodata.operation_error) -> e.shape)
    |> List.dedup_and_sort ~compare:String.compare
  in
  let cases =
    List.map error_shapes ~f:(fun shape ->
      let cap = Shape.capitalized_id shape in
      let to_json =
        sprintf "%s.to_json" cap |> Ast_convenience.evar
      in
      Ast_helper.Exp.case
        (Ast_helper.Pat.variant cap (Some (Ast_convenience.pvar "e")))
        [%expr
          `Assoc
            [ "error", `String [%e Ast_convenience.str cap]
            ; "details", [%e to_json] e
            ]])
  in
  let catch_all =
    Ast_helper.Exp.case
      (Ast_helper.Pat.variant
         "Unknown_operation_error"
         (Some [%pat? code, msg]))
      [%expr
        `Assoc
          (("error", `String code)
           ::
           (match msg with
            | None -> []
            | Some m -> [ "message", `String m ]))]
  in
  let body = Ast_helper.Exp.function_ (cases @ [ catch_all ]) in
  [%stri let error_to_json : error -> Yojson.Safe.t = [%e body]]
;;

let%expect_test "type_declaration_of_errors" =
  let test op =
    let tdecl = type_declaration_of_errors op in
    printf
      "%s%!\n"
      (Util.structure_to_string [ Ast_helper.Str.type_ Nonrecursive [ tdecl ] ])
  in
  let error shape =
    { Botodata.shape
    ; documentation = None
    ; exception_ = None
    ; fault = None
    ; error = None
    ; xmlOrder = None
    }
  in
  let operation errors =
    { Botodata.name = "name"
    ; http = { method_ = `GET; requestUri = []; responseCode = None }
    ; input = None
    ; output = None
    ; errors
    ; documentation = None
    ; documentationUrl = None
    ; alias = None
    ; deprecated = None
    ; deprecatedMessage = None
    ; authtype = None
    ; idempotent = None
    ; httpChecksum = None
    ; endpoint = None
    ; endpointdiscovery = None
    }
  in
  test (operation None);
  [%expect
    {| type nonrec error = [ `Unknown_operation_error of (string * string option) ] |}];
  test (operation (Some []));
  [%expect
    {| type nonrec error = [ `Unknown_operation_error of (string * string option) ] |}];
  test (operation (Some [ error "error_a"; error "error_b" ]));
  [%expect
    {|
    type nonrec error =
      [ `Error_a of Error_a.t  | `Error_b of Error_b.t
      | `Unknown_operation_error of (string * string option) ]
    |}]
;;

let type_alias ?priv ?(attrs=[]) manifest = type_declaration ?priv ~attrs "t" ~manifest

(** A field typed like its name, such as [t : t]. *)
let self_typed_field raw_name =
  let name = Shape.uncapitalized_id raw_name in
  Ast_helper.Type.field
    (Ast_convenience.mknoloc name)
    (Ast_helper.Typ.constr (Ast_convenience.lid name) [])
;;

let type_declarations_of_shape ?result_wrapper ?priv shape =
  let loc = !Ast_helper.default_loc in
  let doc_attrs = doc_attribute (documentation_of_shape shape) in
  match shape with
  | Botodata.Boolean_shape _ -> [ type_alias ?priv ~attrs:doc_attrs [%type: bool] ]
  | Float_shape _ -> [ type_alias ?priv ~attrs:doc_attrs [%type: float] ]
  | Integer_shape _ -> [ type_alias ?priv ~attrs:doc_attrs [%type: int] ]
  | String_shape _ -> [ type_alias ?priv ~attrs:doc_attrs [%type: string] ]
  | Long_shape _ -> [ type_alias ?priv ~attrs:doc_attrs [%type: Int64.t] ]
  | Double_shape _ -> [ type_alias ?priv ~attrs:doc_attrs [%type: float] ]
  | Timestamp_shape _ -> [ type_alias ?priv ~attrs:doc_attrs [%type: string] ]
  | Blob_shape _ -> [ type_alias ?priv ~attrs:doc_attrs [%type: string] ]
  | Enum_shape es ->
    let cases =
      List.map es.cases ~f:(fun case ->
        Ast_helper.Type.constructor (Ast_convenience.mknoloc (Shape.capitalized_id case)))
    in
    let other_case = Enum_other.type_decl ~loc in
    [ type_declaration ?priv ~attrs:doc_attrs "t" ~kind:(Ptype_variant (cases @ [ other_case ])) ]
  | List_shape ls ->
    let elem = Shape.core_type_of_shape ls.member.shape in
    [ type_alias ?priv ~attrs:doc_attrs [%type: [%t elem] list] ]
  | Map_shape ms ->
    let key = Shape.core_type_of_shape ms.key in
    let value = Shape.core_type_of_shape ms.value in
    [ type_alias ?priv ~attrs:doc_attrs [%type: ([%t key] * [%t value]) list] ]
  | Structure_shape ss -> (
    let unwrapped_shape_declaration type_name =
      match ss.members with
      | [] -> type_declaration ?priv type_name ~manifest:[%type: unit]
      | members ->
        let fields =
          List.map members ~f:(fun (fn, sm) ->
            (*
              let fn =
                match sm.locationName with
                | None -> fn
                | Some location_name -> location_name
              in
              *)
            let ty = Shape.core_type_of_shape sm.shape in
            let ty =
              if Shape.structure_shape_required_field ss fn
              then ty
              else [%type: [%t ty] option]
            in
            Ast_helper.Type.field
              ~attrs:(doc_attribute sm.documentation)
              (Ast_convenience.mknoloc (Shape.uncapitalized_id fn)) ty)
        in
        type_declaration ?priv type_name ~kind:(Ptype_record fields)
    in
    match result_wrapper with
    | None -> [ unwrapped_shape_declaration "t" ]
    | Some result_wrapper ->
      [ unwrapped_shape_declaration result_wrapper
      ; type_declaration
          ?priv
          (Shape.uncapitalized_id Shape.response_metadata_shape_name)
          ~manifest:[%type: unit]
      ; type_declaration
          ?priv
          "t"
          ~kind:
            (Ptype_record
               [ self_typed_field result_wrapper
               ; self_typed_field Shape.response_metadata_shape_name
               ])
      ])
;;

let%expect_test "type_declarations_of_shape" =
  let test ?result_wrapper shape =
    let tdecls = type_declarations_of_shape ?result_wrapper shape in
    printf
      "%s%!\n"
      (Util.structure_to_string [ Ast_helper.Str.type_ Nonrecursive tdecls ])
  in
  test (Boolean_shape { box = None; documentation = None });
  [%expect {| type nonrec t = bool |}];
  test (Float_shape { box = None; min = None; max = None; documentation = None });
  [%expect {| type nonrec t = float |}];
  test
    (Integer_shape
       { box = None
       ; min = None
       ; max = None
       ; documentation = None
       ; deprecated = None
       ; deprecatedMessage = None
       });
  [%expect {| type nonrec t = int |}];
  test
    (String_shape
       { pattern = None
       ; min = None
       ; max = None
       ; sensitive = None
       ; documentation = None
       ; deprecated = None
       ; deprecatedMessage = None
       });
  [%expect {| type nonrec t = string |}];
  test (Long_shape { box = None; min = None; max = None; documentation = None });
  [%expect {| type nonrec t = Int64.t |}];
  test (Double_shape { box = None; documentation = None; min = None; max = None });
  [%expect {| type nonrec t = float |}];
  test (Timestamp_shape { timestampFormat = None; documentation = None });
  [%expect {| type nonrec t = string |}];
  test
    (Blob_shape
       { streaming = None
       ; sensitive = None
       ; min = None
       ; max = None
       ; documentation = None
       });
  [%expect {| type nonrec t = string |}];
  test
    (Enum_shape
       { cases = [ "a"; "b"; "c" ]
       ; documentation = None
       ; min = None
       ; max = None
       ; pattern = None
       ; deprecatedMessage = None
       ; deprecated = None
       ; sensitive = None
       });
  [%expect
    {|
    type nonrec t =
      | A
      | B
      | C
      | Non_static_id of string
    |}];
  let member_shape shape =
    { Botodata.shape
    ; deprecated = None
    ; deprecatedMessage = None
    ; location = None
    ; locationName = None
    ; documentation = None
    ; xmlNamespace = None
    ; streaming = None
    ; xmlAttribute = None
    ; queryName = None
    ; box = None
    ; flattened = None
    ; idempotencyToken = None
    ; eventpayload = None
    ; hostLabel = None
    ; jsonvalue = None
    }
  in
  test
    (List_shape
       { min = None
       ; max = None
       ; documentation = None
       ; flattened = None
       ; member = member_shape "member_shape"
       ; sensitive = None
       ; deprecated = None
       ; deprecatedMessage = None
       });
  [%expect {| type nonrec t = Member_shape.t list |}];
  test
    (Map_shape
       { key = "key"
       ; value = "value"
       ; min = None
       ; max = None
       ; flattened = None
       ; locationName = None
       ; documentation = None
       ; sensitive = None
       });
  [%expect {| type nonrec t = (Key.t * Value.t) list |}];
  let structure_shape members =
    Botodata.Structure_shape { Botodata.empty_structure_shape with members }
  in
  test (structure_shape []);
  [%expect {| type nonrec t = unit |}];
  let nonempty_structure =
    structure_shape
      [ "name_a", member_shape "member_a"; "name_b", member_shape "member_b" ]
  in
  test nonempty_structure;
  [%expect
    {|
    type nonrec t = {
      name_a: Member_a.t option ;
      name_b: Member_b.t option }
    |}];
  test ~result_wrapper:"result_wrapper" nonempty_structure;
  [%expect
    {|
    type nonrec result_wrapper =
      {
      name_a: Member_a.t option ;
      name_b: Member_b.t option }
    and responseMetaData = unit
    and t = {
      result_wrapper: result_wrapper ;
      responseMetaData: responseMetaData }
    |}]
;;
