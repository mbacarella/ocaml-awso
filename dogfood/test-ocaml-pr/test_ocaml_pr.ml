(* Benchmarks an ocaml/ocaml pull request on a one-shot spot EC2 instance and
   prints the results, with no SSH at all:

   - repro/<ocaml-pr-number>/ next to this file holds the PR's benchmark
     programs (.ml files, each with an optional <prog>.args). The generic
     bench-pr.sh clones ocaml, fetches the PR, builds the compiler without it
     (the PR's merge-base with trunk, or -base REF) and with it (or once per
     commit, -per-commit), compiles each program with each build at four
     code alignments, and prints cycles and instructions. A repro.sh in the
     PR's directory replaces bench-pr.sh entirely.
   - The instance gets those files in a cloud-init user-data script that
     installs a toolchain and perf, runs the benchmark, and echoes every
     output line to the serial console behind a marker. It then powers off,
     and InstanceInitiatedShutdownBehavior=Terminate turns that into
     termination.
   - We poll GetConsoleOutput (Latest=true, so near real time on Nitro) and
     print the marked lines as they arrive.
   - No key pair and no ingress rule: the instance is launched into the
     default VPC's default security group and only talks outbound.

   Failsafes: the user-data schedules `shutdown -h +<max-hours*60>` first
   thing, and any exit from this program (success, error, Ctrl-C) terminates
   the instance.

   Why -per-commit: by default you get two builds, the base and the whole
   PR, which says whether the PR is faster or slower but not which change
   did it. With -per-commit there is one build per commit, applied
   cumulatively (base, base+c1, base+c1+c2, ...), so each row of the table
   isolates one more commit. That is what turns "the PR is slower here" into
   "commit 2 is slower here, commit 1 is fine", i.e. into a concrete
   suggestion for the PR author. The builds run in parallel, so on a large
   instance it costs little time; for a PR with many small commits it is
   less useful, as each row then measures a step that may not stand alone.

   Example: #14925 on Graviton4. Base vs the whole PR shows its repro ~75%
   slower; -per-commit shows its first commit (inline the arity check, word
   load) is ~1% faster than base and its second (load the arity as one
   byte) causes the whole slowdown, when calling a just-allocated closure:

     dune exec ./dogfood/test-ocaml-pr/test_ocaml_pr.exe -- \
       -pr 14925 -per-commit -region us-east-2 -instance-type m8g.metal-24xl

   Dogfoods awso-async.ec2 (DescribeImages, RunInstances, GetConsoleOutput,
   DescribeInstances, TerminateInstances). *)

open! Core
open! Async
module Ec2 = Awso_ec2_async

let marker = "TEST-OCAML-PR:"
let done_marker = "TEST-OCAML-PR-DONE"
let eprintf_now fmt = ksprintf (fun s -> eprintf "[test-ocaml-pr] %s\n%!" s) fmt

let aws_call ~cfg ~name f request =
  match%bind f ~cfg request with
  | Ok x -> return x
  | Error err ->
    failwithf
      "%s: AWS error: %s"
      name
      (err |> Ec2.Ec2_error.to_json |> Yojson.Safe.to_string)
      ()
;;

let base64_encode s =
  Cryptokit.transform_string (Cryptokit.Base64.encode_compact_pad ()) s
;;

let base64_decode s = Cryptokit.transform_string (Cryptokit.Base64.decode ()) s

(* Newest Canonical Ubuntu 24.04 AMI for the instance's architecture. *)
let ubuntu_ami ~cfg ~arch =
  let pattern = sprintf "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-%s-server-*" arch in
  let req =
    Ec2.DescribeImagesRequest.make
      ~owners:[ "099720109477" ]
      ~filters:
        [ Ec2.Filter.make ~name:"name" ~values:[ pattern ] ()
        ; Ec2.Filter.make ~name:"state" ~values:[ "available" ] ()
        ]
      ()
  in
  let%map resp =
    aws_call ~cfg ~name:"DescribeImages" (fun ~cfg r -> Ec2.describe_images ~cfg r) req
  in
  Option.value resp.images ~default:[]
  |> List.filter_map ~f:(fun (i : Ec2.Image.t) ->
    match i.imageId, i.creationDate with
    | Some id, Some date -> Some (date, id)
    | _ -> None)
  |> List.max_elt ~compare:[%compare: string * string]
  |> function
  | Some (_, id) -> id
  | None -> failwithf "no Canonical AMI matches %s" pattern ()
;;

let arch_of_instance_type t =
  (* Graviton families carry a 'g' after the generation digit: m8g, c7gn, r6gd. *)
  if
    String.is_substring_at t ~pos:2 ~substring:"g"
    || String.is_substring_at t ~pos:3 ~substring:"g"
  then "arm64"
  else "amd64"
;;

(* The files are shipped base64-encoded, so their contents can't interfere
   with the shell script that unpacks them. *)
let user_data ~files ~max_hours ~run =
  let unpack =
    List.map files ~f:(fun (name, contents) ->
      sprintf
        "echo %s | base64 -d > %s\n"
        (Filename.quote (base64_encode contents))
        (Filename.quote name))
    |> String.concat
  in
  sprintf
    {|#!/bin/bash
shutdown -h +%d
say() { echo "%s $*" > /dev/console; }
set -o pipefail
mkdir -p /root/work && cd /root/work
%s chmod +x ./*.sh
say "setting up: $(nproc) cpus, $(lscpu | sed -n 's/^Model name: *//p' | head -n1)"
export DEBIAN_FRONTEND=noninteractive HOME=/root
apt-get update -q >/dev/null && apt-get install -y -q build-essential git \
  "linux-tools-$(uname -r)" >/dev/null 2>&1 || apt-get install -y -q linux-tools-aws >/dev/null 2>&1
sysctl -q -w kernel.perf_event_paranoid=-1
say "running: %s"
%s 2>&1 | while IFS= read -r l; do say "$l"; done
say "exit status ${PIPESTATUS[0]}"
echo %s > /dev/console
sleep 30   # let the console capture catch up before powering off
shutdown -h now
|}
    (max_hours * 60)
    marker
    unpack
    run
    run
    done_marker
;;

let run_instance ~cfg ~ami ~instance_type ~user_data ~name_tag =
  let req =
    Ec2.RunInstancesRequest.make
      ~imageId:ami
      ~minCount:1
      ~maxCount:1
      ~instanceType:(Ec2.InstanceType.of_string instance_type)
      ~userData:(base64_encode user_data)
      ~instanceInitiatedShutdownBehavior:Ec2.ShutdownBehavior.Terminate
      ~blockDeviceMappings:
        [ Ec2.BlockDeviceMapping.make
            ~deviceName:"/dev/sda1"
            ~ebs:
              (Ec2.EbsBlockDevice.make
                 ~volumeSize:40
                 ~volumeType:Ec2.VolumeType.Gp3
                 ~deleteOnTermination:true
                 ())
            ()
        ]
      ~tagSpecifications:
        [ Ec2.TagSpecification.make
            ~resourceType:Ec2.ResourceType.Instance
            ~tags:[ Ec2.Tag.make ~key:"Name" ~value:name_tag () ]
            ()
        ]
      ~instanceMarketOptions:
        (Ec2.InstanceMarketOptionsRequest.make
           ~marketType:Ec2.MarketType.Spot
           ~spotOptions:
             (Ec2.SpotMarketOptions.make
                ~spotInstanceType:Ec2.SpotInstanceType.One_time
                ~instanceInterruptionBehavior:Ec2.InstanceInterruptionBehavior.Terminate
                ())
           ())
      ()
  in
  let%map resp =
    aws_call ~cfg ~name:"RunInstances" (fun ~cfg r -> Ec2.run_instances ~cfg r) req
  in
  match Option.value resp.instances ~default:[] with
  | [ i ] -> Option.value_exn i.instanceId ~message:"RunInstances: no instance id"
  | l -> failwithf "RunInstances returned %d instances" (List.length l) ()
;;

let instance_state ~cfg ~instance_id =
  let req = Ec2.DescribeInstancesRequest.make ~instanceIds:[ instance_id ] () in
  let%map resp =
    aws_call
      ~cfg
      ~name:"DescribeInstances"
      (fun ~cfg r -> Ec2.describe_instances ~cfg r)
      req
  in
  List.concat_map (Option.value resp.reservations ~default:[]) ~f:(fun r ->
    Option.value r.instances ~default:[])
  |> List.hd
  |> Option.bind ~f:(fun (i : Ec2.Instance.t) -> i.state)
  |> Option.bind ~f:(fun (s : Ec2.InstanceState.t) -> s.name)
;;

let console_output ~cfg ~instance_id =
  let req = Ec2.GetConsoleOutputRequest.make ~latest:true ~instanceId:instance_id () in
  match%map Ec2.get_console_output ~cfg req with
  | Ok { output = Some o; _ } -> base64_decode o
  | Ok { output = None; _ } | Error _ -> ""
;;

let terminate ~cfg ~instance_id =
  let req = Ec2.TerminateInstancesRequest.make ~instanceIds:[ instance_id ] () in
  match%map Ec2.terminate_instances ~cfg req with
  | Ok _ -> eprintf_now "terminated %s" instance_id
  | Error e ->
    eprintf_now
      "could not terminate %s (%s): aws ec2 terminate-instances --instance-ids %s"
      instance_id
      (e |> Ec2.Ec2_error.to_json |> Yojson.Safe.to_string)
      instance_id
;;

(* Print each marked console line once. The console buffer holds only the
   most recent output, so we remember lines already printed rather than an
   offset into it. *)
let follow ~cfg ~instance_id =
  let seen = Hash_set.create (module String) in
  (* The console API lags the instance by up to a minute or so, and the
     instance powers off right after printing the done marker; so once it is
     shutting down, keep reading for a while before calling it gone. *)
  let rec loop ~grace =
    let%bind console = console_output ~cfg ~instance_id in
    let lines =
      String.split_lines console
      |> List.filter_map ~f:(fun l ->
        let l = String.rstrip l in
        Option.map (String.substr_index l ~pattern:marker) ~f:(fun i ->
          String.drop_prefix l (i + String.length marker) |> String.strip))
    in
    List.iter lines ~f:(fun l ->
      if Hash_set.strict_add seen l |> Result.is_ok then print_endline l);
    if String.is_substring console ~substring:done_marker
    then return `Done
    else (
      match%bind instance_state ~cfg ~instance_id with
      | Some (Ec2.InstanceStateName.Terminated | Shutting_down) when grace <= 0 ->
        return `Gone
      | Some (Terminated | Shutting_down) ->
        let%bind () = Clock.after (Time_float.Span.of_sec 15.) in
        loop ~grace:(grace - 1)
      | _ ->
        let%bind () = Clock.after (Time_float.Span.of_sec 20.) in
        loop ~grace)
  in
  loop ~grace:12
;;

let main ~region ~instance_type ~pr ~dir ~base ~per_commit ~flambda ~max_hours =
  let%bind cfg = Awso_async.Cfg.get_exn ~region:(Awso.Region.of_string region) () in
  (* Every regular file in the PR's directory; repro.sh is the entry point. *)
  let%bind names =
    Sys.readdir dir >>| Array.to_list >>| List.sort ~compare:String.compare
  in
  let%bind files =
    Deferred.List.filter_map ~how:`Sequential names ~f:(fun f ->
      let path = Filename.concat dir f in
      match%bind Sys.is_file path with
      | `Yes -> Reader.file_contents path >>| fun c -> Some (f, c)
      | `No | `Unknown -> return None)
  in
  (* A repro.sh in the PR's directory takes over; otherwise the generic
     bench-pr.sh builds the compiler with and without the PR and benchmarks
     every *.ml in the directory. *)
  let%bind files, run =
    if List.Assoc.mem files ~equal:String.equal "repro.sh"
    then return (files, "./repro.sh")
    else (
      if not (List.exists files ~f:(fun (f, _) -> String.is_suffix f ~suffix:".ml"))
      then failwithf "%s has neither repro.sh nor any *.ml program" dir ();
      let%map runner = Reader.file_contents "dogfood/test-ocaml-pr/bench-pr.sh" in
      let env =
        [ Some (sprintf "PR=%d" pr)
        ; Option.map base ~f:(fun b -> "BASE=" ^ Filename.quote b)
        ; Option.some_if per_commit "PER_COMMIT=1"
        ; Option.some_if flambda "FLAMBDA=1"
        ]
        |> List.filter_opt
      in
      ("bench-pr.sh", runner) :: files, String.concat ~sep:" " (env @ [ "./bench-pr.sh" ]))
  in
  let user_data = user_data ~files ~max_hours ~run in
  if String.length user_data > 16_384
  then failwithf "user-data is %d bytes; EC2 allows 16384" (String.length user_data) ();
  let arch = arch_of_instance_type instance_type in
  let%bind ami = ubuntu_ami ~cfg ~arch in
  eprintf_now "launching spot %s (%s, %s) in %s" instance_type arch ami region;
  let name_tag =
    sprintf "test-ocaml-pr-%s" (Option.value (Sys.getenv "USER") ~default:"user")
  in
  let%bind instance_id = run_instance ~cfg ~ami ~instance_type ~user_data ~name_tag in
  eprintf_now "instance %s; following its console (builds take ~10 min)" instance_id;
  let cleanup () = terminate ~cfg ~instance_id in
  Signal.handle Signal.terminating ~f:(fun _ ->
    don't_wait_for (cleanup () >>= fun () -> Shutdown.exit 130));
  let%bind outcome = Monitor.try_with (fun () -> follow ~cfg ~instance_id) in
  let%bind () = cleanup () in
  match outcome with
  | Ok `Done -> return ()
  | Ok `Gone -> failwith "instance stopped before finishing (spot interruption?)"
  | Error e -> raise e
;;

let () =
  Command.async
    ~summary:"Benchmark an OCaml compiler PR on a one-shot spot instance, via its console"
    (let%map_open.Command region =
       flag
         "-region"
         (optional_with_default "us-east-2" string)
         ~doc:"REGION (default us-east-2)"
     and instance_type =
       flag
         "-instance-type"
         (optional_with_default "m8g.metal-24xl" string)
         ~doc:"TYPE (default m8g.metal-24xl, Graviton4; c7g.metal = Graviton3)"
     and pr =
       flag
         "-pr"
         (optional_with_default 14925 int)
         ~doc:"N ocaml/ocaml PR to test; its benchmarks are in repro/N/ (default 14925)"
     and dir =
       flag
         "-dir"
         (optional string)
         ~doc:"DIR take the benchmarks from DIR instead of repro/N/"
     and base =
       flag
         "-base"
         (optional string)
         ~doc:
           "REF compare against REF (e.g. 5.5.1) instead of the PR's merge-base with \
            trunk; the PR's commits are cherry-picked onto it"
     and per_commit = flag "-per-commit" no_arg ~doc:" one build per cumulative PR commit"
     and flambda = flag "-flambda" no_arg ~doc:" configure the compilers with flambda"
     and max_hours =
       flag
         "-max-hours"
         (optional_with_default 2 int)
         ~doc:"N hard kill switch (default 2)"
     in
     fun () ->
       let dir =
         Option.value dir ~default:(sprintf "dogfood/test-ocaml-pr/repro/%d" pr)
       in
       main ~region ~instance_type ~pr ~dir ~base ~per_commit ~flambda ~max_hours)
  |> Command_unix.run
;;
