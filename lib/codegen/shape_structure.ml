open! Import

type constr =
  | Int_min of int
  | Int_max of int
  | Int64_min of int64
  | Int64_max of int64
  | String_min of int
  | String_max of int
  | Float_min of float
  | Float_max of float
  | Pattern of string
  | List_min of int
  | List_max of int

let int_min x = Int_min x
let int_max x = Int_max x
let int64_min x = Int64_min x
let int64_max x = Int64_max x
let string_min x = String_min x
let string_max x = String_max x
let float_min x = Float_min x
let float_max x = Float_max x
let pattern x = Pattern x
let list_min x = List_min x
let list_max x = List_max x

let apply_constraint cons =
  let loc = !Ast_helper.default_loc in
  match cons with
  | Int_min x -> [%expr check_int_min i ~min:[%e Ast_convenience.int x]]
  | Int_max x -> [%expr check_int_max i ~max:[%e Ast_convenience.int x]]
  | Int64_min m -> [%expr check_int64_min i ~min:[%e Ast_convenience.int64 m]]
  | Int64_max m -> [%expr check_int64_max i ~max:[%e Ast_convenience.int64 m]]
  | String_min x -> [%expr check_string_min i ~min:[%e Ast_convenience.int x]]
  | String_max x -> [%expr check_string_max i ~max:[%e Ast_convenience.int x]]
  | Float_min f -> [%expr check_float_min i ~min:[%e Ast_convenience.float f]]
  | Float_max f -> [%expr check_float_min i ~min:[%e Ast_convenience.float f]]
  | Pattern x -> [%expr check_pattern i ~pattern:[%e Ast_convenience.str x]]
  | List_min x -> [%expr check_list_min i ~min:[%e Ast_convenience.int x]]
  | List_max x -> [%expr check_list_max i ~max:[%e Ast_convenience.int x]]
;;

let apply_constraints ?(is_pipe = false) cons =
  let loc = !Ast_helper.default_loc in
  match cons with
  | [] -> [%expr fun i -> i]
  | cstr0 :: cstrs -> (
    match is_pipe with
    | true ->
      (* FIXME: The interface doesn't allow enforcing constraints on pipes *)
      [%expr fun i -> i]
    | false ->
      let e =
        List.fold_right cstrs ~init:(apply_constraint cstr0) ~f:(fun cstr e ->
          [%expr [%e apply_constraint cstr] >>= fun () -> [%e e]])
      in
      [%expr
        fun i ->
          let open Result in
          ok_or_failwith [%e e];
          i])
;;

let%expect_test "apply_constraints" =
  let test cstrs =
    let expr = apply_constraints cstrs in
    printf "%s%!" (Util.expression_to_string expr)
  in
  test [];
  [%expect {| fun i -> i |}];
  test [ Int_min 3 ];
  [%expect {| fun i -> let open Result in ok_or_failwith (check_int_min i ~min:3); i |}];
  test [ Int_min 3; Int_max 5 ];
  [%expect
    {|
    fun i ->
      let open Result in
        ok_or_failwith
          ((check_int_max i ~max:5) >>= (fun () -> check_int_min i ~min:3));
        i |}]
;;

(* helper function to sort and annotate fields of a structure shape. This is
   used both for the implementation and the interface. *)
let structure_members (ss : Botodata.structure_shape) =
  List.map ss.members ~f:(fun (field_name, member) ->
    ( Shape.structure_shape_required_field ss field_name
    , field_name
    , Shape.uncapitalized_id field_name
    , member ))
  |> List.stable_sort ~compare:(fun (x, _, _, _) (y, _, _, _) -> Bool.compare x y)
;;

let wrap_result body = function
  | None -> body
  | Some result_wrapper ->
    let loc = !Ast_helper.default_loc in
    Ast_convenience.record
      [ Shape.uncapitalized_id result_wrapper, body
      ; Shape.uncapitalized_id Shape.response_metadata_shape_name, [%expr ()]
      ]
;;

let lambda args body =
  let loc = !Ast_helper.default_loc in
  List.fold_right
    args
    ~init:[%expr fun () -> [%e body]]
    ~f:(fun (required, _, id, _) acc ->
      let label = if required then Labelled id else Optional id in
      Ast_convenience.lam ~label (Ast_convenience.pvar id) acc)
;;

let make_of_structure_shape ?result_wrapper ss =
  let loc = !Ast_helper.default_loc in
  let members = structure_members ss in
  let fields = List.map members ~f:(fun (_, _, id, _) -> id, Ast_convenience.evar id) in
  let result =
    if List.is_empty fields then [%expr ()] else Ast_convenience.record fields
  in
  let body = wrap_result result result_wrapper in
  lambda members body
;;

let shape_member shape =
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
;;

let%expect_test "make_of_structure_shape" =
  let test ?result_wrapper shape =
    let expr = make_of_structure_shape ?result_wrapper shape in
    printf "%s%!" (Util.expression_to_string expr)
  in
  let required_name = "required_field" in
  let structure_shape members : Botodata.structure_shape =
    { Botodata.empty_structure_shape with required = Some [ required_name ]; members }
  in
  let member ~name ~shape = name, shape_member shape in
  test (structure_shape []);
  [%expect {| fun () -> () |}];
  test
    (structure_shape
       [ member ~name:"name_a" ~shape:"shape_a"
       ; member ~name:required_name ~shape:"shape_required"
       ; member ~name:"name_b" ~shape:"shape_b"
       ]);
  [%expect
    {|
    fun ?name_a ->
      fun ?name_b ->
        fun ~required_field -> fun () -> { name_a; name_b; required_field } |}];
  test
    ~result_wrapper:"result_wrapper"
    (structure_shape
       [ member ~name:"name_a" ~shape:"shape_a"
       ; member ~name:required_name ~shape:"shape_required"
       ; member ~name:"name_b" ~shape:"shape_b"
       ]);
  [%expect
    {|
    fun ?name_a ->
      fun ?name_b ->
        fun ~required_field ->
          fun () ->
            {
              result_wrapper = { name_a; name_b; required_field };
              responseMetaData = ()
            } |}]
;;

type core_type = Parsetree.core_type

let yojson_of_constr = function
  | Int_min x -> `List [ `String "Int_min"; `Int x ]
  | Int_max x -> `List [ `String "Int_max"; `Int x ]
  | Int64_min x -> `List [ `String "Int64_min"; `Intlit (Int64.to_string x) ]
  | Int64_max x -> `List [ `String "Int64_max"; `Intlit (Int64.to_string x) ]
  | String_min x -> `List [ `String "String_min"; `Int x ]
  | String_max x -> `List [ `String "String_max"; `Int x ]
  | Float_min x -> `List [ `String "Float_min"; `Float x ]
  | Float_max x -> `List [ `String "Float_max"; `Float x ]
  | Pattern x -> `List [ `String "Pattern"; `String x ]
  | List_min x -> `List [ `String "List_min"; `Int x ]
  | List_max x -> `List [ `String "List_max"; `Int x ]

type kind =
  | Constraints of
      { constraints : constr list
      ; base_type : core_type
      }
  | Build of Botodata.structure_shape

let yojson_of_kind = function
  | Constraints { constraints; base_type } ->
    `Assoc
      [ "Constraints",
        `Assoc
          [ "constraints", `List (Stdlib.List.map yojson_of_constr constraints)
          ; "base_type", `String (Util.core_type_to_string base_type)
          ]
      ]
  | Build _ -> `String "Build"

let constraints base_type l = Constraints { constraints = List.filter_opt l; base_type }

let kind shape =
  let open Option in
  let loc = !Ast_helper.default_loc in
  match shape with
  | Botodata.Integer_shape is ->
    constraints [%type: int] [ is.min >>| int_min; is.max >>| int_max ]
  | Long_shape ls ->
    constraints [%type: int64] [ ls.min >>| int64_min; ls.max >>| int64_max ]
  | String_shape ss ->
    constraints
      [%type: string]
      [ ss.pattern >>| pattern; ss.min >>| string_min; ss.max >>| string_max ]
  | Blob_shape bs ->
    constraints [%type: string] [ bs.min >>| string_min; bs.max >>| string_max ]
  | List_shape ls ->
    let elt_ty = Shape.core_type_of_shape ls.member.shape in
    constraints [%type: [%t elt_ty] list] [ ls.min >>| list_min; ls.max >>| list_max ]
  | Map_shape ms ->
    let key_ty = Shape.core_type_of_shape ms.key in
    let value_ty = Shape.core_type_of_shape ms.value in
    constraints
      [%type: ([%t key_ty] * [%t value_ty]) list]
      [ ms.min >>| list_min; ms.max >>| list_max ]
  | Timestamp_shape _ -> constraints [%type: string] []
  (* FIXME: the format of time stamp should be checked *)
  | Enum_shape _ -> constraints [%type: t] []
  | Boolean_shape _ -> constraints [%type: bool] []
  | Float_shape fs ->
    constraints [%type: float] [ fs.min >>| float_min; fs.max >>| float_max ]
  | Double_shape ds ->
    constraints [%type: float] [ ds.min >>| float_min; ds.max >>| float_max ]
  | Structure_shape s -> Build s
;;

let%expect_test "kind" =
  let test shape = print_string (Yojson.Safe.to_string (yojson_of_kind (kind shape))) in
  let integer_shape ?min ?max () =
    Botodata.Integer_shape
      { box = None
      ; min
      ; max
      ; documentation = None
      ; deprecated = None
      ; deprecatedMessage = None
      }
  in
  test (integer_shape ());
  [%expect {| {"Constraints":{"constraints":[],"base_type":"int"}} |}];
  test (integer_shape ~min:3 ());
  [%expect {| {"Constraints":{"constraints":[["Int_min",3]],"base_type":"int"}} |}];
  test (integer_shape ~max:5 ());
  [%expect {| {"Constraints":{"constraints":[["Int_max",5]],"base_type":"int"}} |}];
  test (integer_shape ~min:3 ~max:5 ());
  [%expect {| {"Constraints":{"constraints":[["Int_min",3],["Int_max",5]],"base_type":"int"}} |}];
  let long_shape ?min ?max () =
    Botodata.Long_shape { box = None; min; max; documentation = None }
  in
  test (long_shape ());
  [%expect {| {"Constraints":{"constraints":[],"base_type":"int64"}} |}];
  test (long_shape ~min:3L ~max:5L ());
  [%expect
    {| {"Constraints":{"constraints":[["Int64_min",3],["Int64_max",5]],"base_type":"int64"}} |}];
  let string_shape ?min ?max ?pattern () =
    Botodata.String_shape
      { pattern
      ; min
      ; max
      ; sensitive = None
      ; documentation = None
      ; deprecated = None
      ; deprecatedMessage = None
      }
  in
  test (string_shape ());
  [%expect {| {"Constraints":{"constraints":[],"base_type":"string"}} |}];
  test (string_shape ~min:3 ~max:5 ~pattern:"PATTERN" ());
  [%expect
    {| {"Constraints":{"constraints":[["Pattern","PATTERN"],["String_min",3],["String_max",5]],"base_type":"string"}} |}];
  let blob_shape ?min ?max () =
    Botodata.Blob_shape
      { min; max; sensitive = None; streaming = None; documentation = None }
  in
  test (blob_shape ());
  [%expect {| {"Constraints":{"constraints":[],"base_type":"string"}} |}];
  test (blob_shape ~min:3 ~max:5 ());
  [%expect
    {| {"Constraints":{"constraints":[["String_min",3],["String_max",5]],"base_type":"string"}} |}];
  let list_shape ?min ?max () =
    Botodata.List_shape
      { min
      ; max
      ; member = shape_member "shape"
      ; documentation = None
      ; flattened = None
      ; sensitive = None
      ; deprecatedMessage = None
      ; deprecated = None
      }
  in
  test (list_shape ());
  [%expect {| {"Constraints":{"constraints":[],"base_type":"Shape.t list"}} |}];
  test (list_shape ~min:3 ~max:5 ());
  [%expect
    {| {"Constraints":{"constraints":[["List_min",3],["List_max",5]],"base_type":"Shape.t list"}} |}];
  let map_shape ?min ?max () =
    Botodata.Map_shape
      { min
      ; max
      ; key = "key"
      ; value = "value"
      ; locationName = None
      ; documentation = None
      ; flattened = None
      ; sensitive = None
      }
  in
  test (map_shape ());
  [%expect {| {"Constraints":{"constraints":[],"base_type":"(Key.t * Value.t) list"}} |}];
  test (map_shape ~min:3 ~max:5 ());
  [%expect
    {| {"Constraints":{"constraints":[["List_min",3],["List_max",5]],"base_type":"(Key.t * Value.t) list"}} |}]
;;

let body ?result_wrapper shape =
  match kind shape with
  | Build s -> make_of_structure_shape ?result_wrapper s
  | Constraints { constraints; _ } ->
    let is_pipe =
      match shape with
      | Blob_shape _ -> true
      | _ -> false
    in
    apply_constraints ~is_pipe constraints
;;

let structure_item_of_shape ?result_wrapper shape =
  let loc = !Ast_helper.default_loc in
  [%stri let make = [%e body ?result_wrapper shape]]
;;

let structure_make_type ss =
  let loc = !Ast_helper.default_loc in
  let members = structure_members ss in
  let init = [%type: unit -> t] in
  List.fold_right members ~init ~f:(fun (required, _, id, member) acc ->
    let label = if required then Labelled id else Optional id in
    let ty = Shape.core_type_of_shape member.shape in
    Ast_helper.Typ.arrow label ty acc)
;;

let type_of_shape s =
  let loc = !Ast_helper.default_loc in
  match kind s with
  | Constraints { base_type; _ } -> [%type: [%t base_type] -> t]
  | Build ss -> structure_make_type ss
;;

let private_flag_of_shape shape =
  match shape, kind shape with
  | List_shape _, _ ->
    (* Make exception for list shapes so we can destruct them naturally *)
    Public
  | _, Constraints { constraints = []; _ } -> Public
  | _, Constraints _ -> Private
  | _, Build _ -> Public
;;
