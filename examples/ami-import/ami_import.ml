open Core
open Async
module Cfg = Awso_async.Cfg
module Ec2 = Awso_ec2_async
module Ebs = Awso_ebs_async

(* This is a port of https://github.com/ipxe/ipxe/blob/master/contrib/cloud/aws-import *)
let block_size = 512 * 1024
let checksum_algorithm = "SHA256"

let detect_architecture image =
  let default = "x86_64" in
  match%bind
    Async.Process.run ~prog:"mdir" ~args:[ "-b"; "-i"; image; "::/EFI/BOOT" ] ()
  with
  | Error e ->
    eprintf "detect_architecture: %s\n" (Error.to_string_hum e);
    eprintf "detect_architecture: defaulting to %s\n" default;
    return default
  | Ok mdir -> (
    match String.is_substring ~substring:"BOOTAA64.EFI" mdir with
    | true -> return "arm64"
    | false -> return default)
;;

let dispatch_exn ~name ~error_to_json ~f =
  match%bind f () with
  | Ok v -> return v
  | Error aws ->
    failwithf "%s: %s" name (aws |> error_to_json |> Yojson.Safe.to_string) ()
;;

let start_snapshot ~cfg ~volume_size ~description =
  dispatch_exn
    ~name:"start_snapshot"
    ~error_to_json:Ebs.StartSnapshotResponse.error_to_json
    ~f:(fun () ->
      Ebs.start_snapshot
        ~cfg
        (Ebs.StartSnapshotRequest.make
           ~description
           ~volumeSize:(Int64.of_int volume_size)
           ()))
  >>| fun v ->
  Option.value_exn ~message:"snapshotId is None" v.Ebs.StartSnapshotResponse.snapshotId
;;

let put_snapshot_block ~cfg request =
  dispatch_exn
    ~name:"put_snapshot_block"
    ~error_to_json:Ebs.PutSnapshotBlockResponse.error_to_json
    ~f:(fun () -> Ebs.put_snapshot_block ~cfg request)
  >>| fun v ->
  let _checksum = v.Ebs.PutSnapshotBlockResponse.checksum in
  ()
;;

let complete_snapshot ~cfg ~snapshot_id ~changed_blocks_count =
  dispatch_exn
    ~name:"complete_snapshot"
    ~error_to_json:Ebs.CompleteSnapshotResponse.error_to_json
    ~f:(fun () ->
      Ebs.complete_snapshot
        ~cfg
        (Ebs.CompleteSnapshotRequest.make
           ~snapshotId:snapshot_id
           ~changedBlocksCount:changed_blocks_count
           ()))
  >>| fun v ->
  Option.value_exn
    ~message:"No completeSnapshotResponse.status"
    v.Ebs.CompleteSnapshotResponse.status
;;

let describe_snapshots ~cfg ~snapshot_id =
  dispatch_exn
    ~name:"describe_snapshots"
    ~error_to_json:Ec2.Ec2_error.to_json
    ~f:(fun () ->
      Ec2.describe_snapshots
        ~cfg
        (Ec2.DescribeSnapshotsRequest.make ~snapshotIds:[ snapshot_id ] ()))
  >>| fun v ->
  match v.Ec2.DescribeSnapshotsResult.snapshots with
  | None -> failwithf "No snapshots for %s at all" snapshot_id ()
  | Some [ { state; _ } ] -> Option.value_exn ~message:"No snapshot state" state
  | Some lst ->
    failwithf
      "Snapshots list length %d <> 1 (expected %s)"
      (List.length lst)
      snapshot_id
      ()
;;

let describe_images ~cfg ~image_id =
  dispatch_exn ~name:"describe_images" ~error_to_json:Ec2.Ec2_error.to_json ~f:(fun () ->
    Ec2.describe_images ~cfg (Ec2.DescribeImagesRequest.make ~imageIds:[ image_id ] ()))
  >>| fun v ->
  match v.Ec2.DescribeImagesResult.images with
  | None -> failwithf "No images for %s at all" image_id ()
  | Some [ { state; _ } ] -> Option.value_exn ~message:"No image state" state
  | Some lst ->
    failwithf "Images list length %d <> 1 (expected '%s')" (List.length lst) image_id ()
;;

let waiter_retry_logic ~f ~max_attempts ~delay =
  let rec loop attempt =
    match Int.( >= ) attempt max_attempts with
    | true ->
      failwithf
        !"waiter_retry_logic: gave up after %d attempts (%{Time_float_unix.Span} per \
          attempt)"
        max_attempts
        delay
        ()
    | false -> (
      let%bind () =
        match attempt with
        | 0 -> return ()
        | _ -> Clock.after delay
      in
      match%bind f () with
      | `ok -> return ()
      | `retry -> loop (Int.succ attempt))
  in
  loop 0
;;

let snapshot_completed_waiter ~cfg ~snapshot_id =
  waiter_retry_logic ~delay:(sec 15.) ~max_attempts:40 ~f:(fun () ->
    match%map describe_snapshots ~cfg ~snapshot_id with
    | Ec2.SnapshotState.Completed -> `ok
    | Error -> failwithf "snapshot state for %s settled to error" snapshot_id ()
    | _ -> `retry)
;;

let image_available_waiter ~cfg ~image_id =
  waiter_retry_logic ~delay:(sec 15.) ~max_attempts:40 ~f:(fun () ->
    match%map describe_images ~cfg ~image_id with
    | Ec2.ImageState.Available -> `ok
    | Failed -> failwithf "iamge state for %s settled to error" image_id ()
    | _ -> `retry)
;;

let all_regions ~cfg =
  dispatch_exn ~name:"describe_regions" ~error_to_json:Ec2.Ec2_error.to_json ~f:(fun () ->
    Ec2.describe_regions ~cfg (Ec2.DescribeRegionsRequest.make ()))
  >>| fun v ->
  Option.value_exn ~message:"regions is None" v.Ec2.DescribeRegionsResult.regions
;;

let create_snapshot ~cfg ~description ~image =
  let%bind snapshot_id = start_snapshot ~cfg ~volume_size:1 ~description in
  let%bind r = Reader.open_file image in
  let buf = Bytes.create block_size in
  let rec put_block_loop block_index =
    match%bind Reader.read r ~pos:0 ~len:block_size buf with
    | `Eof -> return block_index
    | `Ok bytes_read ->
      (* The python script does this padding with zeroes, though I'm not sure this is
         always safe; this may corrupt file reads that return short, if it's not short
         because we're at EOF. *)
      for i = bytes_read to Int.pred block_size do
        Bytes.set buf i '\x00'
      done;
      let block_data = Bytes.to_string buf in
      let checksum =
        block_data
        |> Cryptokit.hash_string (Cryptokit.Hash.sha256 ())
        |> Base64.encode_exn
      in
      let%bind () =
        put_snapshot_block
          ~cfg
          (Ebs.PutSnapshotBlockRequest.make
             ~snapshotId:snapshot_id
             ~blockIndex:block_index
             ~blockData:(Ebs.BlockData.of_string block_data)
             ~dataLength:block_size
             ~checksum
             ~checksumAlgorithm:(Ebs.ChecksumAlgorithm.of_string checksum_algorithm)
             ())
      in
      put_block_loop (Int.succ block_index)
  in
  let%bind last_block_index = put_block_loop 0 in
  let%bind _status =
    complete_snapshot ~cfg ~snapshot_id ~changed_blocks_count:last_block_index
  in
  return snapshot_id
;;

let register_image ~cfg request =
  dispatch_exn
    ~name:"register_image"
    ~f:(fun () -> Ec2.register_image ~cfg request)
    ~error_to_json:Ec2.Ec2_error.to_json
  >>| fun v ->
  Option.value_exn
    ~message:"No registerImageResult.imageId"
    v.Ec2.RegisterImageResult.imageId
;;

let import_image ~cfg ~name ~architecture ~image =
  let region =
    Option.value_exn ~message:"AWS config does not have region set" cfg.Awso.Cfg.region
  in
  let description = sprintf "%s (%s)" name architecture in
  let%bind snapshot_id = create_snapshot ~cfg ~description ~image in
  let%bind () = snapshot_completed_waiter ~cfg ~snapshot_id in
  let%bind image_id =
    let device_name = "/dev/sda1" in
    let ebs =
      Ec2.EbsBlockDevice.make
        ~snapshotId:snapshot_id
        ~volumeType:Ec2.VolumeType.Standard
        ()
    in
    let req =
      Ec2.RegisterImageRequest.make
        ~name:description
        ~rootDeviceName:device_name
        ~architecture:(Ec2.ArchitectureValues.of_string architecture)
          (* FIXME: I couldn't boot an AMI instance with serial console support (nitro)
              until I enabled ENA. *)
        ~enaSupport:true
        ~sriovNetSupport:"simple"
        ~virtualizationType:"hvm"
        ~blockDeviceMappings:
          [ Ec2.BlockDeviceMapping.make ~ebs ~deviceName:device_name () ]
        ()
    in
    (*
    eprintf
      "debug: register image request: %s\n"
      (req |> Ec2.RegisterImageRequest.sexp_of_t |> Sexp.to_string_hum); *)
    register_image ~cfg req
  in
  let%bind () = image_available_waiter ~cfg ~image_id in
  printf !"image %s now available in %{Awso.Region}\n" image_id region;
  return ()
;;

let main ~name ~regions ~images =
  let%bind cfg = Awso_async.Cfg.get_exn () in
  let%bind regions =
    match regions with
    | _ :: _ -> return regions
    | [] ->
      let%bind rs = all_regions ~cfg in
      return (List.filter_map rs ~f:(fun r -> r.Ec2.Region.regionName))
  in
  Deferred.List.iter images ~how:`Sequential ~f:(fun image ->
    let%bind architecture = detect_architecture image in
    Deferred.List.iter regions ~how:`Parallel ~f:(fun region ->
      let cfg = { cfg with region = Some (Awso.Region.of_string region) } in
      import_image ~cfg ~name ~architecture ~image))
;;

let () =
  let cmd =
    Command.async
      ~summary:"Import AWS EC2 image (AMI)"
      (let open Command.Let_syntax in
       let%map_open name = flag "-name" (optional string) ~doc:"NAME image name"
       and regions =
         flag "-region" (listed string) ~doc:"REGION AWS region(s) (default: all)"
       and images = anon (non_empty_sequence_as_list ("image" %: string)) in
       fun () ->
         let name =
           Option.value
             ~default:
               (sprintf
                  "iPXE (%s)"
                  (Date.today ~zone:Time_float_unix.Zone.utc |> Date.to_string))
             name
         in
         main ~name ~regions ~images)
  in
  Command_unix.run cmd
;;
