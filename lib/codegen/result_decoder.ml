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
    (* When [payload] isn't explicitly set but the output is a structure with
       exactly one non-header blob member (alongside zero or more header
       members), that blob member is the implicit payload; newer botocore
       output shapes sometimes omit the explicit [payload] field. We only
       apply this when [shape_is_header_structure'] holds since otherwise
       the per-shape codegen won't emit an [of_header_and_body]. *)
    let implicit_payload =
      match payload, output_shape with
      | None, Structure_shape ss
        when Shape.shape_is_header_structure' ~shapes output_shape -> (
        let is_header (m : Botodata.shape_member) =
          match m.location with
          | Some `header | Some `headers -> true
          | _ -> false
        in
        let blob_members =
          List.filter ss.members ~f:(fun (_, m) ->
            (not (is_header m))
            &&
            match List.Assoc.find shapes m.shape ~equal:String.equal with
            | Some (Botodata.Blob_shape _) -> true
            | _ -> false)
        in
        match blob_members with
        | [ (name, _) ] -> Some name
        | _ -> None)
      | _ -> None
    in
    let payload = Option.first_some payload implicit_payload in
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
