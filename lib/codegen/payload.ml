open! Import

type t =
  { is_blob : bool
  ; payload_module : string
  ; field_name : string
  ; is_required : bool
  }
let create ~is_blob ~payload_module ~field_name ~is_required =
  { is_blob; payload_module; field_name; is_required }

let convert_rest_json
  { is_blob; payload_module; field_name; is_required }
  ~(service : Botodata.service)
  ~(op : Botodata.operation option)
  ~endpoint_name:_
  expr
  =
  let loc = !Ast_helper.default_loc in
  match op with
  | None -> [%expr None, None]
  | Some op -> (
    match op.input with
    | None -> [%expr None, None]
    | Some input -> (
      let find_shape key = List.Assoc.find_exn service.shapes key ~equal:String.equal in
      let input_shape = find_shape input.shape in
      match input_shape with
      | Float_shape _
      | Boolean_shape _
      | Long_shape _
      | Double_shape _
      | Blob_shape _
      | Integer_shape _
      | String_shape _
      | List_shape _
      | Enum_shape _
      | Map_shape _
      | Timestamp_shape _ ->
        failwithj
          ~here:()
          "Expected a Structure_shape"
          input_shape
          Botodata.yojson_of_shape
      | Structure_shape ss ->
        let header_members =
          List.filter ss.members ~f:(fun (_field_name, member) ->
            match member.location with
            | Some `header -> true
            | _ -> false)
        in
        let header_values =
          List.map header_members ~f:(fun (field_name, member) ->
            let field_e =
              Ast_helper.Exp.field
                (Ast_convenience.evar "req")
                (Ast_convenience.lid
                   (input.shape ^ "." ^ Shape.uncapitalized_id field_name))
            in
            let to_value_e x =
              Ast_convenience.app
                (Ast_convenience.evar (Shape.capitalized_id member.shape ^ ".to_header"))
                [ x ]
            in
            let key = Option.value member.locationName ~default:field_name in
            let pair x = Ast_convenience.pair (Ast_convenience.str key) (to_value_e x) in
            if Shape.structure_shape_required_field ss field_name
            then Ast_convenience.some (pair field_e)
            else
              [%expr
                Option.map [%e field_e] ~f:(fun x -> [%e pair (Ast_convenience.evar "x")])])
          |> Ast_convenience.list
          |> fun e -> [%expr List.filter_opt [%e e] |> Awso.Http.Headers.of_list]
        in
        let in_module id =
          Printf.ksprintf Ast_convenience.evar "%s.%s" payload_module id
        in
        let field = Ast_helper.Exp.field expr (Ast_convenience.lid field_name) in
        let f =
          if is_blob
          then in_module "to_header"
          else (
            (*let module_str = Ast_convenience.str endpoint_name in*)
            let to_value = in_module "to_value" in
            [%expr
              fun param ->
                param
                |> [%e to_value]
                |> Awso.Botodata.Json.value_to_json
                |> Yojson.Safe.to_string])
        in
        if is_required
        then
          [%expr
            let headers = Some [%e header_values] in
            let body = [%e f] [%e field] in
            Awso.Http.Request.make ?headers ~body (method_of_endpoint endp)]
        else
          [%expr
            let headers = Some [%e header_values] in
            let body = Option.map [%e field] ~f:[%e f] in
            Awso.Http.Request.make ?headers ?body (method_of_endpoint endp)]))
;;

let convert_rest_xml
  { is_blob; payload_module; field_name; is_required }
  ~endpoint_name
  expr
  =
  let loc = !Ast_helper.default_loc in
  let in_module id = Printf.ksprintf Ast_convenience.evar "%s.%s" payload_module id in
  let field = Ast_helper.Exp.field expr (Ast_convenience.lid field_name) in
  let f =
    if is_blob
    then in_module "to_header"
    else (
      let module_str = Ast_convenience.str endpoint_name in
      let to_value = in_module "to_value" in
      [%expr
        fun param ->
          param
          |> [%e to_value]
          |> Awso.Xml.of_value [%e module_str]
          |> List.map ~f:Awso.Xml.to_string
          |> String.concat ~sep:""])
  in
  if is_required
  then
    [%expr
      let body = [%e f] [%e field] in
      Awso.Http.Request.make ~body (method_of_endpoint endp)]
  else
    [%expr
      let body = Option.map [%e field] ~f:[%e f] in
      Awso.Http.Request.make ?body (method_of_endpoint endp)]
;;

let of_botodata (op : Botodata.operation) ~shapes =
  let find_shape shape = List.Assoc.find_exn shapes shape ~equal:String.equal in
  Option.bind op.input ~f:(fun op_input ->
    match find_shape op_input.shape with
    | Botodata.Structure_shape structure_shape ->
      let { Botodata.payload; members; _ } = structure_shape in
      Option.map payload ~f:(fun name ->
        let payload_shape_member = List.Assoc.find_exn members name ~equal:String.equal in
        let payload_module = payload_shape_member.shape in
        let is_blob =
          match find_shape payload_module with
          | Structure_shape _ -> false
          | Blob_shape _ -> true
          | String_shape _ -> true
          | shape ->
            failwithf "Unexpected payload shape %s for op %s"
              (Yojson.Safe.to_string (Botodata.yojson_of_shape shape))
              op.name ()
        in
        let field_name = String.uncapitalize name in
        let is_required =
          structure_shape.Botodata.required
          |> Option.value ~default:[]
          |> fun l -> List.mem ~equal:String.equal l name
        in
        create ~is_blob ~payload_module ~field_name ~is_required)
    | _ -> None)
;;
