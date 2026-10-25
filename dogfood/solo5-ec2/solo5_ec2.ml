(* Boots raw disk images as EC2 instances and reads their serial console: the
   AWS side of running Solo5 unikernels directly on EC2 (no Linux).

   Dogfoods awso-async.ebs (the EBS direct APIs) and awso-async.ec2.

   upload IMAGE     StartSnapshot, PutSnapshotBlock for every 512 KiB block that
                    isn't all zeros, CompleteSnapshot, then wait for the
                    snapshot to be "completed". No helper instance, no S3.
   register SNAP    RegisterImage: x86_64, hvm, legacy BIOS, ENA flag set (t3
                    and t3a refuse an AMI without it), root on /dev/xvda.
   boot AMI         RunInstances (spot, one-time), then poll GetConsoleOutput
                    with Latest=true and print new console text until --until
                    appears, the instance stops, or --timeout. Terminates the
                    instance afterwards unless --keep.
   run IMAGE        upload + register + boot, then deregister the AMI and
                    delete the snapshot unless --keep-image.
   inventory        Everything tagged Project=solo5-ec2.
   cleanup          Terminate, deregister and delete everything tagged
                    Project=solo5-ec2.

   Everything created is tagged Project=solo5-ec2. Instances are launched with
   InstanceInitiatedShutdownBehavior=Terminate, so a unikernel that powers off
   (solo5_exit does an ACPI S5) terminates itself.

   awso's Cfg doesn't read AWS_PROFILE, so the profile comes from --profile,
   falling back to $AWS_PROFILE, then "solo5-ec2". The region comes from that
   profile. *)

open! Core
open! Async
module Ebs = Awso_ebs_async
module Ec2 = Awso_ec2_async

let project_tag = "solo5-ec2"
let block_size = 524288
let eprintf_now fmt = ksprintf (fun s -> eprintf "[solo5-ec2] %s\n%!" s) fmt

let base64_encode s =
  Cryptokit.transform_string (Cryptokit.Base64.encode_compact_pad ()) s
;;

let base64_decode s = Cryptokit.transform_string (Cryptokit.Base64.decode ()) s
let sha256 s = Cryptokit.hash_string (Cryptokit.Hash.sha256 ()) s

let ec2_call ~name f request =
  match%bind f request with
  | Ok x -> return x
  | Error err ->
    let s = err |> Ec2.Ec2_error.to_json |> Yojson.Safe.to_string in
    failwithf "%s: AWS error: %s" name s ()
;;

let ebs_call ~name ~error_to_json f request =
  match%bind f request with
  | Ok x -> return x
  | Error err ->
    failwithf "%s: AWS error: %s" name (Yojson.Safe.to_string (error_to_json err)) ()
;;

let get_cfg ~profile =
  let profile =
    match profile with
    | Some p -> p
    | None -> Option.value (Sys.getenv "AWS_PROFILE") ~default:project_tag
  in
  let%map cfg = Awso_async.Cfg.get_exn ~profile () in
  eprintf_now
    "profile %s, region %s"
    profile
    (Option.value_map cfg.region ~default:"<none>" ~f:Awso.Region.to_string);
  cfg
;;

let ec2_tags ~name =
  [ Ec2.Tag.make ~key:"Project" ~value:project_tag ()
  ; Ec2.Tag.make ~key:"Name" ~value:name ()
  ]
;;

let tag_spec resource_type ~name =
  Ec2.TagSpecification.make ~resourceType:resource_type ~tags:(ec2_tags ~name) ()
;;

let project_filter = Ec2.Filter.make ~name:"tag:Project" ~values:[ project_tag ] ()

(* Upload *)

let is_zero s = String.for_all s ~f:(Char.equal '\000')

(* The non-zero 512 KiB blocks of [path], with their indexes. Only the data
   blocks are held in memory: a 1 GiB image with a few MB of data costs a
   few MB. *)
let read_nonzero_blocks path =
  Reader.with_file path ~f:(fun r ->
    let buf = Bytes.create block_size in
    let rec loop index acc =
      match%bind Reader.really_read r buf with
      | `Eof 0 -> return (index, List.rev acc)
      | `Eof n ->
        (* The image's tail: pad the last block with zeros. *)
        Bytes.fill buf ~pos:n ~len:(block_size - n) '\000';
        let s = Bytes.to_string buf in
        return (index + 1, List.rev (if is_zero s then acc else (index, s) :: acc))
      | `Ok ->
        let s = Bytes.to_string buf in
        loop (index + 1) (if is_zero s then acc else (index, s) :: acc)
    in
    loop 0 [])
;;

let rec wait_for_snapshot ~cfg ~snapshot_id =
  let%bind resp =
    ec2_call
      ~name:"DescribeSnapshots"
      (Ec2.describe_snapshots ~cfg)
      (Ec2.DescribeSnapshotsRequest.make ~snapshotIds:[ snapshot_id ] ())
  in
  let state =
    match resp.snapshots with
    | Some [ s ] -> s.state
    | _ -> None
  in
  match state with
  | Some Ec2.SnapshotState.Completed -> return ()
  | Some (Ec2.SnapshotState.Error | Ec2.SnapshotState.Recoverable) ->
    failwithf "snapshot %s failed" snapshot_id ()
  | Some _ | None ->
    let%bind () = after (Time_float.Span.of_sec 5.) in
    wait_for_snapshot ~cfg ~snapshot_id
;;

let upload ~cfg ~image ~name =
  let%bind total_blocks, blocks = read_nonzero_blocks image in
  let gib = 1024 * 1024 * 1024 in
  let volume_size = ((total_blocks * block_size) + gib - 1) / gib in
  eprintf_now
    "%s: %d GiB volume, %d of %d blocks hold data"
    image
    volume_size
    (List.length blocks)
    total_blocks;
  let%bind started =
    ebs_call
      ~name:"StartSnapshot"
      ~error_to_json:Ebs.StartSnapshotResponse.error_to_json
      (Ebs.start_snapshot ~cfg)
      (Ebs.StartSnapshotRequest.make
         ~volumeSize:(Int64.of_int volume_size)
         ~description:name
         ~tags:
           [ Ebs.Tag.make ~key:"Project" ~value:project_tag ()
           ; Ebs.Tag.make ~key:"Name" ~value:name ()
           ]
         ~timeout:60
         ())
  in
  let snapshot_id = Option.value_exn started.snapshotId ~message:"StartSnapshot: no id" in
  eprintf_now "snapshot %s started" snapshot_id;
  let%bind () =
    Deferred.List.iter ~how:(`Max_concurrent_jobs 8) blocks ~f:(fun (index, data) ->
      let%map (_ : Ebs.PutSnapshotBlockResponse.t) =
        ebs_call
          ~name:(sprintf "PutSnapshotBlock %d" index)
          ~error_to_json:Ebs.PutSnapshotBlockResponse.error_to_json
          (Ebs.put_snapshot_block ~cfg)
          (Ebs.PutSnapshotBlockRequest.make
             ~snapshotId:snapshot_id
             ~blockIndex:index
             ~blockData:data
             ~dataLength:block_size
             ~checksum:(base64_encode (sha256 data))
             ~checksumAlgorithm:Ebs.ChecksumAlgorithm.SHA256
             ())
      in
      ())
  in
  let%bind (_ : Ebs.CompleteSnapshotResponse.t) =
    ebs_call
      ~name:"CompleteSnapshot"
      ~error_to_json:Ebs.CompleteSnapshotResponse.error_to_json
      (Ebs.complete_snapshot ~cfg)
      (Ebs.CompleteSnapshotRequest.make
         ~snapshotId:snapshot_id
         ~changedBlocksCount:(List.length blocks)
         ())
  in
  eprintf_now "snapshot %s uploaded, waiting for it to complete" snapshot_id;
  let%map () = wait_for_snapshot ~cfg ~snapshot_id in
  eprintf_now "snapshot %s completed" snapshot_id;
  snapshot_id
;;

(* Register *)

let register ~cfg ~snapshot_id ~name =
  let%map resp =
    ec2_call
      ~name:"RegisterImage"
      (Ec2.register_image ~cfg)
      (Ec2.RegisterImageRequest.make
         ~name
         ~description:"Solo5 unikernel, legacy BIOS boot (solo5-ec2 research)"
         ~architecture:Ec2.ArchitectureValues.X86_64
         ~virtualizationType:"hvm"
         ~bootMode:Ec2.BootModeValues.Legacy_bios
         ~enaSupport:true
         ~rootDeviceName:"/dev/xvda"
         ~blockDeviceMappings:
           [ Ec2.BlockDeviceMapping.make
               ~deviceName:"/dev/xvda"
               ~ebs:
                 (Ec2.EbsBlockDevice.make
                    ~snapshotId:snapshot_id
                    ~volumeType:Ec2.VolumeType.Gp3
                    ~deleteOnTermination:true
                    ())
               ()
           ]
         ~tagSpecifications:[ tag_spec Ec2.ResourceType.Image ~name ]
         ())
  in
  let image_id = Option.value_exn resp.imageId ~message:"RegisterImage: no image id" in
  eprintf_now "image %s registered from %s" image_id snapshot_id;
  image_id
;;

(* Boot *)

type boot_opts =
  { instance_type : string
  ; on_demand : bool
  ; until : string option
  ; timeout : Time_float.Span.t
  ; keep : bool
  ; volumes : (string * [ `Empty of int | `Snapshot of string ]) list
    (* extra gp3 volumes: device, and either a size in GiB or a snapshot *)
  ; security_group : string option
  ; user_data : string option (* a script for cloud-init, for Linux clients *)
  ; availability_zone : string option
  }

let launch ~cfg ~image_id ~(opts : boot_opts) ~name =
  let { instance_type
      ; on_demand
      ; volumes
      ; security_group
      ; user_data
      ; availability_zone
      ; _
      }
    =
    opts
  in
  let block_device_mappings =
    List.map volumes ~f:(fun (device, source) ->
      let volumeSize, snapshotId =
        match source with
        | `Empty gib -> Some gib, None
        | `Snapshot id -> None, Some id
      in
      Ec2.BlockDeviceMapping.make
        ~deviceName:device
        ~ebs:
          (Ec2.EbsBlockDevice.make
             ?volumeSize
             ?snapshotId
             ~volumeType:Ec2.VolumeType.Gp3
             ~deleteOnTermination:true
             ())
        ())
  in
  let instance_market_options =
    if on_demand
    then None
    else
      Some
        (Ec2.InstanceMarketOptionsRequest.make
           ~marketType:Ec2.MarketType.Spot
           ~spotOptions:
             (Ec2.SpotMarketOptions.make
                ~spotInstanceType:Ec2.SpotInstanceType.One_time
                ~instanceInterruptionBehavior:Ec2.InstanceInterruptionBehavior.Terminate
                ())
           ())
  in
  let%map resp =
    ec2_call
      ~name:"RunInstances"
      (Ec2.run_instances ~cfg)
      (Ec2.RunInstancesRequest.make
         ~imageId:image_id
         ~minCount:1
         ~maxCount:1
         ~instanceType:(Ec2.InstanceType.of_string instance_type)
         ~instanceInitiatedShutdownBehavior:Ec2.ShutdownBehavior.Terminate
         ?instanceMarketOptions:instance_market_options
         ?securityGroupIds:(Option.map security_group ~f:List.return)
         ?userData:(Option.map user_data ~f:base64_encode)
         ?placement:
           (Option.map availability_zone ~f:(fun z ->
              Ec2.Placement.make ~availabilityZone:z ()))
         ~blockDeviceMappings:block_device_mappings
         ~tagSpecifications:
           [ tag_spec Ec2.ResourceType.Instance ~name
           ; tag_spec Ec2.ResourceType.Volume ~name
           ]
         ())
  in
  match resp.instances with
  | Some [ { instanceId = Some id; _ } ] ->
    eprintf_now
      "instance %s launched (%s, %s)"
      id
      instance_type
      (if on_demand then "on demand" else "spot");
    id
  | _ -> failwith "RunInstances: expected one instance"
;;

(* The instance's state, and its public IPv4 address (once it has one),
   private IPv4 address and availability zone. A new instance can be missing
   from DescribeInstances for a few seconds (eventual consistency); that reads
   as no state yet. *)
let instance_state ~cfg ~instance_id =
  let%map reservations =
    match%map
      Ec2.describe_instances
        ~cfg
        (Ec2.DescribeInstancesRequest.make ~instanceIds:[ instance_id ] ())
    with
    | Ok resp -> Option.value resp.reservations ~default:[]
    | Error err ->
      let s = err |> Ec2.Ec2_error.to_json |> Yojson.Safe.to_string in
      if String.is_substring s ~substring:"InvalidInstanceID.NotFound"
      then []
      else failwithf "DescribeInstances: AWS error: %s" s ()
  in
  let instance =
    reservations
    |> List.concat_map ~f:(fun r -> Option.value r.instances ~default:[])
    |> List.hd
  in
  ( Option.bind instance ~f:(fun (i : Ec2.Instance.t) ->
      Option.bind i.state ~f:(fun (s : Ec2.InstanceState.t) -> s.name))
  , Option.bind instance ~f:(fun (i : Ec2.Instance.t) -> i.publicIpAddress)
  , Option.bind instance ~f:(fun (i : Ec2.Instance.t) -> i.privateIpAddress)
  , Option.bind instance ~f:(fun (i : Ec2.Instance.t) ->
      Option.bind i.placement ~f:(fun (p : Ec2.Placement.t) -> p.availabilityZone)) )
;;

let console_output ~cfg ~instance_id =
  match%map
    Ec2.get_console_output
      ~cfg
      (Ec2.GetConsoleOutputRequest.make ~instanceId:instance_id ~latest:true ())
  with
  | Ok { output = Some b64; _ } -> base64_decode b64
  | Ok { output = None; _ } -> ""
  | Error err ->
    eprintf_now
      "GetConsoleOutput: %s"
      (err |> Ec2.Ec2_error.to_json |> Yojson.Safe.to_string);
    ""
;;

let terminate ~cfg ~instance_id =
  let%map (_ : Ec2.TerminateInstancesResult.t) =
    ec2_call
      ~name:"TerminateInstances"
      (Ec2.terminate_instances ~cfg)
      (Ec2.TerminateInstancesRequest.make ~instanceIds:[ instance_id ] ())
  in
  eprintf_now "instance %s terminating" instance_id
;;

(* Prints the console as it grows. GetConsoleOutput returns the whole (recent)
   buffer each time, so print only what's past what we printed last. *)
let follow_console ~cfg ~instance_id ~until ~timeout =
  let deadline = Time_float.add (Time_float.now ()) timeout in
  let ip_shown = ref false in
  let rec loop ~printed =
    let%bind out = console_output ~cfg ~instance_id in
    let printed =
      if String.length out > String.length printed && String.is_prefix out ~prefix:printed
      then (
        print_string (String.drop_prefix out (String.length printed));
        out)
      else if String.length out > 0 && not (String.equal out printed)
      then (
        print_string out;
        out)
      else printed
    in
    let%bind () = Writer.flushed (force Writer.stdout) in
    let found =
      Option.exists until ~f:(fun u -> String.is_substring printed ~substring:u)
    in
    let%bind state, public_ip, private_ip, zone = instance_state ~cfg ~instance_id in
    (match public_ip with
     | Some ip when not !ip_shown ->
       ip_shown := true;
       eprintf_now
         "instance %s has public IP %s, private IP %s, in %s"
         instance_id
         ip
         (Option.value private_ip ~default:"?")
         (Option.value zone ~default:"?")
     | _ -> ());
    let gone =
      match state with
      | Some
          ( Ec2.InstanceStateName.Shutting_down
          | Ec2.InstanceStateName.Terminated
          | Ec2.InstanceStateName.Stopping
          | Ec2.InstanceStateName.Stopped ) -> true
      | _ -> false
    in
    if found
    then (
      eprintf_now "found %S on the console" (Option.value_exn until);
      return `Found)
    else if gone
    then (
      eprintf_now "instance is shutting down";
      (* One more read: the last lines may only show up now. *)
      let%map out = console_output ~cfg ~instance_id in
      if String.length out > String.length printed && String.is_prefix out ~prefix:printed
      then print_string (String.drop_prefix out (String.length printed));
      `Stopped)
    else if Time_float.( > ) (Time_float.now ()) deadline
    then (
      eprintf_now "timed out";
      return `Timeout)
    else (
      let%bind () = after (Time_float.Span.of_sec 3.) in
      loop ~printed)
  in
  loop ~printed:""
;;

let boot ~cfg ~image_id ~(opts : boot_opts) ~name =
  let%bind instance_id = launch ~cfg ~image_id ~opts ~name in
  Monitor.protect
    (fun () -> follow_console ~cfg ~instance_id ~until:opts.until ~timeout:opts.timeout)
    ~finally:(fun () ->
      if opts.keep
      then (
        eprintf_now "--keep: instance %s left running" instance_id;
        return ())
      else terminate ~cfg ~instance_id)
;;

(* Inventory and cleanup *)

type inventory =
  { instances : string list
  ; images : string list
  ; snapshots : string list
  ; volumes : string list
  }

let inventory ~cfg =
  let%bind reservations =
    ec2_call
      ~name:"DescribeInstances"
      (Ec2.describe_instances ~cfg)
      (Ec2.DescribeInstancesRequest.make
         ~filters:
           [ project_filter
           ; Ec2.Filter.make
               ~name:"instance-state-name"
               ~values:[ "pending"; "running"; "stopping"; "stopped"; "shutting-down" ]
               ()
           ]
         ())
  in
  let instances =
    Option.value reservations.reservations ~default:[]
    |> List.concat_map ~f:(fun r -> Option.value r.instances ~default:[])
    |> List.filter_map ~f:(fun (i : Ec2.Instance.t) -> i.instanceId)
  in
  let%bind images =
    ec2_call
      ~name:"DescribeImages"
      (Ec2.describe_images ~cfg)
      (Ec2.DescribeImagesRequest.make ~owners:[ "self" ] ~filters:[ project_filter ] ())
  in
  let%bind snapshots =
    ec2_call
      ~name:"DescribeSnapshots"
      (Ec2.describe_snapshots ~cfg)
      (Ec2.DescribeSnapshotsRequest.make
         ~ownerIds:[ "self" ]
         ~filters:[ project_filter ]
         ())
  in
  let%map volumes =
    ec2_call
      ~name:"DescribeVolumes"
      (Ec2.describe_volumes ~cfg)
      (Ec2.DescribeVolumesRequest.make ~filters:[ project_filter ] ())
  in
  { instances
  ; images =
      Option.value images.images ~default:[]
      |> List.filter_map ~f:(fun (i : Ec2.Image.t) -> i.imageId)
  ; snapshots =
      Option.value snapshots.snapshots ~default:[]
      |> List.filter_map ~f:(fun (s : Ec2.Snapshot.t) -> s.snapshotId)
  ; volumes =
      Option.value volumes.volumes ~default:[]
      |> List.filter_map ~f:(fun (v : Ec2.Volume.t) -> v.volumeId)
  }
;;

let print_inventory inv =
  let show what ids =
    printf
      "%-10s %s\n"
      what
      (if List.is_empty ids then "-" else String.concat ~sep:" " ids)
  in
  show "instances" inv.instances;
  show "images" inv.images;
  show "snapshots" inv.snapshots;
  show "volumes" inv.volumes
;;

let deregister ~cfg ~image_id =
  let%map (_ : Ec2.DeregisterImageResult.t) =
    ec2_call
      ~name:"DeregisterImage"
      (Ec2.deregister_image ~cfg)
      (Ec2.DeregisterImageRequest.make ~imageId:image_id ())
  in
  eprintf_now "image %s deregistered" image_id
;;

let delete_snapshot ~cfg ~snapshot_id =
  let%map () =
    match%map
      Ec2.delete_snapshot ~cfg (Ec2.DeleteSnapshotRequest.make ~snapshotId:snapshot_id ())
    with
    | Ok _ -> ()
    | Error err ->
      failwithf
        "DeleteSnapshot %s: %s"
        snapshot_id
        (err |> Ec2.Ec2_error.to_json |> Yojson.Safe.to_string)
        ()
  in
  eprintf_now "snapshot %s deleted" snapshot_id
;;

let cleanup ~cfg =
  let%bind inv = inventory ~cfg in
  let%bind () =
    Deferred.List.iter ~how:`Sequential inv.instances ~f:(fun instance_id ->
      terminate ~cfg ~instance_id)
  in
  let%bind () =
    Deferred.List.iter ~how:`Sequential inv.images ~f:(fun image_id ->
      deregister ~cfg ~image_id)
  in
  let%bind () =
    Deferred.List.iter ~how:`Sequential inv.snapshots ~f:(fun snapshot_id ->
      delete_snapshot ~cfg ~snapshot_id)
  in
  Deferred.List.iter ~how:`Sequential inv.volumes ~f:(fun volume_id ->
    match%map
      Ec2.delete_volume ~cfg (Ec2.DeleteVolumeRequest.make ~volumeId:volume_id ())
    with
    | Ok _ -> eprintf_now "volume %s deleted" volume_id
    | Error err ->
      (* An instance's root volume goes away with the instance. *)
      eprintf_now
        "volume %s not deleted: %s"
        volume_id
        (err |> Ec2.Ec2_error.to_json |> Yojson.Safe.to_string))
;;

(* Commands *)

let profile_flag =
  Command.Param.flag
    "--profile"
    (Command.Param.optional Command.Param.string)
    ~doc:"NAME AWS profile (default: $AWS_PROFILE, else solo5-ec2)"
;;

let default_name image =
  sprintf
    "solo5-ec2-%s-%s"
    (Filename.chop_extension (Filename.basename image))
    (Time_float.to_filename_string ~zone:Time_float.Zone.utc (Time_float.now ()))
;;

let boot_params =
  let%map_open.Command instance_type =
    flag
      "--instance-type"
      (optional_with_default "t3a.nano" string)
      ~doc:"TYPE instance type (default: t3a.nano)"
  and on_demand = flag "--on-demand" no_arg ~doc:" launch on demand instead of spot"
  and until =
    flag
      "--until"
      (optional string)
      ~doc:"TEXT stop following the console once TEXT appears"
  and timeout =
    flag
      "--timeout"
      (optional_with_default (Time_float.Span.of_min 5.) Time_float_unix.Span.arg_type)
      ~doc:"SPAN give up following the console after SPAN (default: 5m)"
  and keep = flag "--keep" no_arg ~doc:" don't terminate the instance afterwards"
  and volumes =
    flag
      "--volume"
      (listed string)
      ~doc:
        "DEVICE:GIB|DEVICE:SNAPSHOT attach an extra gp3 volume, empty or from a \
         snapshot, e.g. /dev/sdf:1 (repeatable)"
  and security_group =
    flag
      "--security-group"
      (optional string)
      ~doc:"ID launch in this security group (default: the VPC's default group)"
  and user_data =
    flag
      "--user-data"
      (optional Filename_unix.arg_type)
      ~doc:"FILE pass FILE as user data (for cloud-init on a Linux AMI)"
  and availability_zone =
    flag "--availability-zone" (optional string) ~doc:"ZONE launch in this zone"
  in
  let user_data = Option.map user_data ~f:In_channel.read_all in
  let volumes =
    List.map volumes ~f:(fun v ->
      match String.rsplit2 v ~on:':' with
      | Some (device, snap) when String.is_prefix snap ~prefix:"snap-" ->
        device, `Snapshot snap
      | Some (device, gib) -> device, `Empty (Int.of_string gib)
      | None -> failwithf "--volume %S: expected DEVICE:GIB or DEVICE:SNAPSHOT" v ())
  in
  { instance_type
  ; on_demand
  ; until
  ; timeout
  ; keep
  ; volumes
  ; security_group
  ; user_data
  ; availability_zone
  }
;;

let exit_with = function
  | `Found | `Stopped -> return ()
  | `Timeout -> exit 2
;;

let upload_command =
  Command.async
    ~summary:"Upload a raw disk image to an EBS snapshot (EBS direct APIs)"
    (let%map_open.Command profile = profile_flag
     and image = anon ("IMAGE" %: Filename_unix.arg_type) in
     fun () ->
       let%bind cfg = get_cfg ~profile in
       let%map snapshot_id = upload ~cfg ~image ~name:(default_name image) in
       print_endline snapshot_id)
;;

let register_command =
  Command.async
    ~summary:"Register a legacy-BIOS x86_64 AMI from a snapshot"
    (let%map_open.Command profile = profile_flag
     and snapshot_id = anon ("SNAPSHOT" %: string)
     and name = flag "--name" (required string) ~doc:"NAME AMI name" in
     fun () ->
       let%bind cfg = get_cfg ~profile in
       let%map image_id = register ~cfg ~snapshot_id ~name in
       print_endline image_id)
;;

let boot_command =
  Command.async
    ~summary:"Boot an AMI and follow its serial console"
    (let%map_open.Command profile = profile_flag
     and image_id = anon ("AMI" %: string)
     and opts = boot_params in
     fun () ->
       let%bind cfg = get_cfg ~profile in
       boot ~cfg ~image_id ~opts ~name:image_id >>= exit_with)
;;

let run_command =
  Command.async
    ~summary:"Upload, register and boot a raw disk image, then clean up"
    (let%map_open.Command profile = profile_flag
     and image = anon ("IMAGE" %: Filename_unix.arg_type)
     and opts = boot_params
     and keep_image =
       flag "--keep-image" no_arg ~doc:" keep the AMI and snapshots afterwards"
     and data =
       flag
         "--data"
         (listed string)
         ~doc:
           "DEVICE=IMAGE upload IMAGE as a snapshot and attach a volume made from it at \
            DEVICE (repeatable)"
     in
     fun () ->
       let%bind cfg = get_cfg ~profile in
       let name = default_name image in
       let%bind data_volumes =
         Deferred.List.map ~how:`Sequential data ~f:(fun d ->
           match String.lsplit2 d ~on:'=' with
           | None -> failwithf "--data %S: expected DEVICE=IMAGE" d ()
           | Some (device, data_image) ->
             let%map snapshot_id =
               upload ~cfg ~image:data_image ~name:(default_name data_image)
             in
             device, snapshot_id)
       in
       let opts =
         { opts with
           volumes =
             opts.volumes
             @ List.map data_volumes ~f:(fun (device, snapshot_id) ->
               device, `Snapshot snapshot_id)
         }
       in
       let delete_data_snapshots () =
         Deferred.List.iter ~how:`Sequential data_volumes ~f:(fun (_, snapshot_id) ->
           delete_snapshot ~cfg ~snapshot_id)
       in
       let%bind snapshot_id = upload ~cfg ~image ~name in
       let%bind image_id = register ~cfg ~snapshot_id ~name in
       let%bind result =
         Monitor.protect
           (fun () -> boot ~cfg ~image_id ~opts ~name)
           ~finally:(fun () ->
             if keep_image
             then (
               eprintf_now "--keep-image: kept %s and %s" image_id snapshot_id;
               return ())
             else (
               let%bind () = delete_data_snapshots () in
               let%bind () = deregister ~cfg ~image_id in
               delete_snapshot ~cfg ~snapshot_id))
       in
       exit_with result)
;;

(* A security group of our own in the default VPC, for reaching test
   instances: ICMP and TCP 80/8080 from one address range only. *)
let test_group_name = "solo5-ec2-test"

let security_group ~cfg ~allow_from =
  let%bind existing =
    ec2_call
      ~name:"DescribeSecurityGroups"
      (Ec2.describe_security_groups ~cfg)
      (Ec2.DescribeSecurityGroupsRequest.make
         ~filters:[ Ec2.Filter.make ~name:"group-name" ~values:[ test_group_name ] () ]
         ())
  in
  let%bind group_id =
    match
      Option.value existing.securityGroups ~default:[]
      |> List.find_map ~f:(fun (g : Ec2.SecurityGroup.t) -> g.groupId)
    with
    | Some id -> return id
    | None ->
      let%map created =
        ec2_call
          ~name:"CreateSecurityGroup"
          (Ec2.create_security_group ~cfg)
          (Ec2.CreateSecurityGroupRequest.make
             ~groupName:test_group_name
             ~description:"solo5-ec2 test instances: ICMP and HTTP from the operator"
             ~tagSpecifications:
               [ tag_spec Ec2.ResourceType.Security_group ~name:test_group_name ]
             ())
      in
      let id = Option.value_exn created.groupId ~message:"CreateSecurityGroup: no id" in
      eprintf_now "security group %s created" id;
      id
  in
  let rule protocol from_port to_port =
    Ec2.IpPermission.make
      ~ipProtocol:protocol
      ~fromPort:from_port
      ~toPort:to_port
      ~ipRanges:[ Ec2.IpRange.make ~cidrIp:allow_from () ]
      ()
  in
  let%map result =
    Ec2.authorize_security_group_ingress
      ~cfg
      (Ec2.AuthorizeSecurityGroupIngressRequest.make
         ~groupId:group_id
         ~ipPermissions:[ rule "icmp" (-1) (-1); rule "tcp" 80 80; rule "tcp" 8080 8080 ]
         ())
  in
  (match result with
   | Ok _ ->
     eprintf_now "security group %s allows ICMP, TCP 80, 8080 from %s" group_id allow_from
   | Error err ->
     (* Most likely the rules are there already. *)
     eprintf_now
       "AuthorizeSecurityGroupIngress: %s"
       (err |> Ec2.Ec2_error.to_json |> Yojson.Safe.to_string));
  group_id
;;

let security_group_command =
  Command.async
    ~summary:"Create or update the solo5-ec2-test security group, print its ID"
    (let%map_open.Command profile = profile_flag
     and allow_from =
       flag "--allow-from" (required string) ~doc:"CIDR e.g. 203.0.113.7/32"
     in
     fun () ->
       let%bind cfg = get_cfg ~profile in
       let%map id = security_group ~cfg ~allow_from in
       print_endline id)
;;

let find_ami_command =
  Command.async
    ~summary:"Print the newest x86_64 AMI of OWNER whose name matches PATTERN"
    (let%map_open.Command profile = profile_flag
     and owner = anon ("OWNER" %: string)
     and pattern = anon ("PATTERN" %: string) in
     fun () ->
       let%bind cfg = get_cfg ~profile in
       let%map resp =
         ec2_call
           ~name:"DescribeImages"
           (Ec2.describe_images ~cfg)
           (Ec2.DescribeImagesRequest.make
              ~owners:[ owner ]
              ~filters:
                [ Ec2.Filter.make ~name:"name" ~values:[ pattern ] ()
                ; Ec2.Filter.make ~name:"architecture" ~values:[ "x86_64" ] ()
                ]
              ())
       in
       match
         Option.value resp.images ~default:[]
         |> List.filter_map ~f:(fun (i : Ec2.Image.t) ->
           match i.imageId, i.creationDate, i.name with
           | Some id, Some date, Some name -> Some (date, id, name)
           | _ -> None)
         |> List.max_elt ~compare:[%compare: string * string * string]
       with
       | Some (date, id, name) -> printf "%s %s %s\n" id date name
       | None -> failwith "no matching image")
;;

let console_command =
  Command.async
    ~summary:"Print the latest serial console output of a running instance"
    (let%map_open.Command profile = profile_flag
     and instance_id = anon ("INSTANCE" %: string) in
     fun () ->
       let%bind cfg = get_cfg ~profile in
       let%map out = console_output ~cfg ~instance_id in
       print_string out)
;;

let inventory_command =
  Command.async
    ~summary:"List everything tagged Project=solo5-ec2"
    (let%map_open.Command profile = profile_flag in
     fun () ->
       let%bind cfg = get_cfg ~profile in
       inventory ~cfg >>| print_inventory)
;;

let cleanup_command =
  Command.async
    ~summary:"Terminate, deregister and delete everything tagged Project=solo5-ec2"
    (let%map_open.Command profile = profile_flag in
     fun () ->
       let%bind cfg = get_cfg ~profile in
       let%bind () = cleanup ~cfg in
       inventory ~cfg >>| print_inventory)
;;

let () =
  Command.group
    ~summary:"Boot raw disk images on EC2 and read their serial console"
    [ "upload", upload_command
    ; "register", register_command
    ; "boot", boot_command
    ; "run", run_command
    ; "security-group", security_group_command
    ; "console", console_command
    ; "find-ami", find_ami_command
    ; "inventory", inventory_command
    ; "cleanup", cleanup_command
    ]
  |> Command_unix.run
;;
