module S3_part = Part
open! Values
open! Core
open! Async

let pp_opt pp ppf = function
  | None -> Format.fprintf ppf "<not present>"
  | Some x -> pp ppf x
;;

let failwithf fmt = Format.kasprintf failwith fmt

let dispatch_exn ~name ~error_to_json ~f =
  match%bind f () with
  | Ok v -> return v
  | Error aws ->
    failwithf "%s: %s" name (aws |> error_to_json |> Yojson.Safe.to_string) ()
;;

module List_buckets = struct
  let pp_created_at ppf s = Format.fprintf ppf " (created at %s)" s

  let pp_bucket_line ppf { Bucket.name; creationDate } =
    Format.fprintf
      ppf
      "- %a%a\n"
      (Fmt.option Fmt.string)
      name
      (Fmt.option pp_created_at)
      creationDate
  ;;

  let owner_opt_to_string = function
    | None -> "<no owner>"
    | Some (owner : Owner.t) ->
      Option.value owner.displayName ~default:"<no displayname>"
  ;;

  let pp_out ppf { ListBucketsOutput.owner; buckets } =
    let owner = owner_opt_to_string owner in
    Format.fprintf
      ppf
      "Owner: %s\nBuckets:\n%a"
      owner
      (Fmt.option (Fmt.list pp_bucket_line))
      buckets
  ;;

  let run () =
    Awso_async.Cfg.get_exn ()
    >>= fun cfg ->
    dispatch_exn
      ~name:"list_buckets"
      ~error_to_json:ListBucketsOutput.error_to_json
      ~f:(fun () ->
      Io.list_buckets ~cfg ())
    >>| fun v -> Format.printf "%a" pp_out v
  ;;

  let param =
    let open Command.Param in
    return run
  ;;

  let command = Command.async ~summary:"List buckets" param
end

module List_objects = struct
  let pp_size ppf n = Format.fprintf ppf ", %d bytes" n
  let pp_last_modified ppf s = Format.fprintf ppf ", last modified %s" s

  let pp_object ppf { Object.key; size; lastModified; _ } =
    Format.fprintf
      ppf
      "- %a%a%a\n"
      (Fmt.option Fmt.string)
      key
      (Fmt.option pp_size)
      size
      (Fmt.option pp_last_modified)
      lastModified
  ;;

  let pp_out ppf { ListObjectsOutput.contents; _ } =
    Format.fprintf ppf "%a" (Fmt.option (Fmt.list pp_object)) contents
  ;;

  let run bucket () =
    Awso_async.Cfg.get_exn ()
    >>= fun cfg ->
    dispatch_exn
      ~name:"list_objects"
      ~error_to_json:ListObjectsOutput.error_to_json
      ~f:(fun () ->
      Io.list_objects
        ~cfg
        (ListObjectsRequest.make ~bucket ~prefix:"" ()))
    >>| fun v -> Format.printf "%a" pp_out v
  ;;

  let param =
    let open Command.Param in
    return run <*> Awso_async.Param.bucket
  ;;

  let command = Command.async ~summary:"List objects in a bucket" param
end

module Get_object = struct
  let save { GetObjectOutput.body; _ } ~to_:dest =
    let data = Option.value_exn body in
    Out_channel.write_all dest ~data
  ;;

  let pp_metadata_kv ppf (k, v) = Format.fprintf ppf "%s => %s" k v

  let pp_metadata =
    let sep ppf () = Format.fprintf ppf ", " in
    Fmt.list ~sep pp_metadata_kv
  ;;

  let pp_metadata
    ppf
    { GetObjectOutput.lastModified; contentLength; eTag; contentType; metadata; _ }
    =
    Format.fprintf
      ppf
      "Last modified: %a\nContent length: %a\nETag: %a\nContent-Type: %a\nMetadata: %a\n"
      (pp_opt String.pp)
      lastModified
      (pp_opt Int64.pp)
      contentLength
      (pp_opt String.pp)
      eTag
      (pp_opt String.pp)
      contentType
      (pp_opt pp_metadata)
      metadata
  ;;

  let run bucket key dest_opt () =
    Awso_async.Cfg.get_exn ()
    >>= fun cfg ->
    dispatch_exn
      ~name:"get_object"
      ~error_to_json:GetObjectOutput.error_to_json
      ~f:(fun () ->
      Io.get_object
        ~cfg
        (GetObjectRequest.make ~bucket ~key ()))
    >>| fun out ->
    match dest_opt with
    | None -> Format.printf "%a" pp_metadata out
    | Some dest -> save ~to_:dest out
  ;;

  let destination =
    let open Command.Param in
    flag "-o" (optional Filename_unix.arg_type) ~doc:"Save output to this file"
  ;;

  let param =
    let open Command.Param in
    return run <*> Awso_async.Param.bucket <*> Awso_async.Param.key <*> destination
  ;;

  let command = Command.async ~summary:"Download an object" param
end

module Put_object = struct
  let pp_out ppf { PutObjectOutput.eTag; _ } =
    Format.fprintf ppf "ETag: %a\n" (pp_opt String.pp) eTag
  ;;

  let run bucket key infile () =
    let body_s = In_channel.read_all infile in
    let body = Body.of_string body_s in
    Awso_async.Cfg.get_exn ()
    >>= fun cfg ->
    dispatch_exn
      ~name:"put_object"
      ~error_to_json:PutObjectOutput.error_to_json
      ~f:(fun () ->
      Io.put_object
        ~cfg
        (PutObjectRequest.make ~bucket ~key ~body ()))
    >>| fun v -> Format.printf "%a" pp_out v
  ;;

  let param =
    let open Command.Param in
    return run
    <*> Awso_async.Param.bucket
    <*> Awso_async.Param.key
    <*> Awso_async.Param.infile
  ;;

  let command = Command.async ~summary:"Upload an object" param
end

module Put_multipart = struct
  let run bucket key infile () =
    Awso_async.Cfg.get_exn ()
    >>= fun cfg ->
    dispatch_exn
      ~name:"create_multipart_upload"
      ~error_to_json:CreateMultipartUploadOutput.error_to_json
      ~f:(fun () ->
      Io.create_multipart_upload
        ~cfg
        (CreateMultipartUploadRequest.make ~bucket ~key ()))
    >>= fun creation ->
    let upload_part ~nparts i part =
      let req = S3_part.upload_request ~creation ~path:infile part in
      let progress = 100. *. float i /. float nparts in
      printf "%d/%d (%.1f%%)\n%!" i nparts progress;
      dispatch_exn
        ~name:"upload_part"
        ~error_to_json:UploadPartOutput.error_to_json
        ~f:(fun () ->
        Io.upload_part ~cfg req)
      >>| fun v -> S3_part.completed_part part v
    in
    let parts = S3_part.build_parts infile in
    let nparts = List.length parts in
    Deferred.List.mapi parts ~how:`Sequential ~f:(upload_part ~nparts)
    >>= fun parts ->
    dispatch_exn
      ~name:"complete_multipart_upload"
      ~error_to_json:CompleteMultipartUploadOutput.error_to_json
      ~f:(fun () ->
      Io.complete_multipart_upload
        ~cfg
        (S3_part.complete_request ~creation ~parts))
    >>| fun { location; _ } ->
    Format.printf
      "Successful upload, location: %a\n"
      (pp_opt Format.pp_print_string)
      location
  ;;

  let param =
    let open Command.Param in
    return run
    <*> Awso_async.Param.bucket
    <*> Awso_async.Param.key
    <*> Awso_async.Param.infile
  ;;

  let command = Command.async ~summary:"Upload an object using the multipart API" param
end

let main =
  Command.group
    ~summary:"Interact with the S3 API"
    [ "lb", List_buckets.command
    ; "ls", List_objects.command
    ; "get", Get_object.command
    ; "put", Put_object.command
    ; "put-multipart", Put_multipart.command
    ]
;;
