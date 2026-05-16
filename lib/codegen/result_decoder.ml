open! Import

type t =
  | Xml
  | Json
  | Of_header_and_body of string option

let of_botodata ~default (op : Botodata.operation) ~shapes =
  Option.map op.output ~f:(fun { shape = output_shape_name; _ } ->
    let (output_shape : Botodata.shape) =
      List.Assoc.find_exn shapes ~equal:String.equal output_shape_name
    in
    let payload =
      match output_shape with
      | Structure_shape { payload; _ } -> payload
      | _ -> None
    in
    match Shape.shape_is_header_structure' ~shapes output_shape, payload with
    | true, _ -> Of_header_and_body payload
    | false, Some _ ->
      (* Mixed: some members are headers, the [payload] member is the
         body and may itself be a structure. The runtime parses the body
         via the payload shape's of_string. *)
      Of_header_and_body payload
    | false, None -> default)
;;

let of_botodata_xml (op : Botodata.operation) ~shapes =
  of_botodata ~default:Xml op ~shapes
;;

let of_botodata_json (op : Botodata.operation) ~shapes =
  of_botodata ~default:Json op ~shapes
;;
