(* Launches a one-shot spot EC2 instance, pushes the local working tree
   over SSH, installs the OCaml toolchain over SSH, runs `dune build -p ...`
   (the opam-ci simulation), streams build output back, and tears everything
   down on completion.

   Dogfoods awso-async.ec2 (and .sts) for everything that touches AWS. SSH is
   shelled out to the local OS.

   Resource lifecycle (everything regenerated each run):
   - Auth keypair: ssh-keygen ed25519, dropped at ~/.cache/awso-ci/auth.id_ed25519
     (or $XDG_CACHE_HOME/awso-ci/), imported to EC2 as KeyPair "awso-ci-$USER".
     DeleteKeyPair clears any prior copy before ImportKeyPair.
   - Host keypair: ssh-keygen ed25519, dropped at ~/.cache/awso-ci/host.ed25519,
     shipped to the instance via cloud-init's ssh_keys module so we can pin a
     known fingerprint instead of TOFU.
   - known_hosts: per-run file at ~/.cache/awso-ci/known_hosts. Never touches
     ~/.ssh/known_hosts. ssh runs with StrictHostKeyChecking=yes against it.
   - Security group: named "awso-ci-$USER". Delete-if-exists then create, with
     ingress locked to the detected public IP.
   - Instance: spot, one-time, terminate-on-interruption. Tagged Name="awso-ci-$USER".

   The remote build:
   - Tars the local working tree (minus _build/_opam/.git/secrets) and pipes
     it over SSH into ~/awso on the instance, so uncommitted changes are
     part of the build.
   - `--lower-bounds` swaps the switch to 4.14.2 and the solver to
     builtin-0install with version-lag bias, mirroring opam-ci's
     lower-bounds job.

   AWS account attestation:
   - Cloud-init receives the SSH host private key in EC2 user-data. Anyone in
     this account with ec2:DescribeInstanceAttribute can read it and MITM the
     build host. On first run for each account, the tool prompts for a typed
     "yes" attestation that the account is trusted. The attestation is stored
     at ~/.cache/awso-ci/aws-account-trust/<account-id>.attested.

   At startup we sanity-check for any not-fully-terminated instances tagged
   Name="awso-ci-$USER" (e.g. left behind by --dont-shut-down-on-failure on
   a previous run) and abort with the cleanup command unless --force.

   Failsafes:
   - Instance launched with InstanceInitiatedShutdownBehavior=Terminate.
   - User-data schedules `shutdown -h +<max-hours*60>` as an absolute kill.
   - SIGINT/SIGTERM handler attempts cleanup if the tool dies mid-run.

   By default a successful build tears down the instance, SG, AWS keypair, and
   local key files. A failure also tears them down unless
   --dont-shut-down-on-failure is passed (in which case the SSH command is
   printed and the resources are left for the caller to inspect; the local
   keypair and known_hosts file are also kept so manual SSH works). *)

open! Core
open! Async
module Ec2 = Awso_ec2_async
module Sts = Awso_sts_async

let eprintf_now fmt = ksprintf (fun s -> eprintf "[ci] %s\n%!" s) fmt

type arch =
  | Arm64
  | X86_64

let arch_arg =
  Command.Arg_type.create (function
    | "arm64" -> Arm64
    | "x86-64" | "x86_64" | "amd64" -> X86_64
    | s -> failwithf "--arch must be 'arm64' or 'x86-64', got %S" s ())
;;

let arch_label = function
  | Arm64 -> "arm64"
  | X86_64 -> "x86-64"
;;

let default_instance_type = function
  | Arm64 -> "c7g.xlarge"
  | X86_64 -> "c7i.xlarge"
;;

(* Ubuntu 22.04 LTS AMIs. Date-sensitive; refresh from
   https://cloud-images.ubuntu.com/locator/ec2/ *)
let ubuntu_2204_arm64_ami_by_region =
  [ "us-east-1", "ami-0a7a4e87939439934"
  ; "us-east-2", "ami-09040d770ffe2224f"
  ; "us-west-1", "ami-014e30c8689d31c25"
  ; "us-west-2", "ami-04f7efe62f419d9f5"
  ; "eu-west-1", "ami-0568773882d492fc8"
  ; "eu-central-1", "ami-0c1ac8a41498c1a9c"
  ]
;;

let ubuntu_2204_amd64_ami_by_region =
  [ "us-east-1", "ami-0e2c8caa4b6378d8c"
  ; "us-east-2", "ami-036841078a4b68e14"
  ; "us-west-1", "ami-0d50e5e845c552faf"
  ; "us-west-2", "ami-0aff18ec83b712f05"
  ; "eu-west-1", "ami-0c1bc246476a5572b"
  ; "eu-central-1", "ami-024f768332f0e6c2"
  ]
;;

let lookup_default_ami ~arch ~region =
  let table =
    match arch with
    | Arm64 -> ubuntu_2204_arm64_ami_by_region
    | X86_64 -> ubuntu_2204_amd64_ami_by_region
  in
  List.Assoc.find table ~equal:String.equal region
;;

let ssh_user = "ubuntu"

(* AWS resource names are account-shared, so we suffix with the local username
   to keep concurrent users from colliding on a single account. The cache dir
   is already per-user (under $HOME) so local file basenames don't need this
   suffix. *)
let user_tag () =
  let raw =
    match Sys.getenv "USER" with
    | Some u when not (String.is_empty u) -> u
    | _ -> failwithf "$USER is not set; cannot compute user_tag" ()
  in
  let sanitized =
    String.map raw ~f:(function
      | ('a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '-' | '_') as c -> c
      | _ -> '_')
  in
  "awso-ci-" ^ sanitized
;;

let run_capture ~prog ~args ?(stdin_input = "") () =
  let%bind p = Process.create ~prog ~args () >>| ok_exn in
  Writer.write (Process.stdin p) stdin_input;
  let%bind () = Writer.close (Process.stdin p) in
  let%bind out, err =
    Deferred.both
      (Reader.contents (Process.stdout p))
      (Reader.contents (Process.stderr p))
  in
  let%map exit_or_signal = Process.wait p in
  match exit_or_signal with
  | Ok () -> Ok (String.strip out)
  | Error _ -> Error err
;;

let run_or_die ~prog ~args ?(stdin_input = "") () =
  match%map run_capture ~prog ~args ~stdin_input () with
  | Ok s -> s
  | Error stderr ->
    failwithf "%s %s failed: %s" prog (String.concat ~sep:" " args) stderr ()
;;

let detect_public_ip () =
  match%map
    Monitor.try_with ~run:`Schedule (fun () ->
      let%bind _resp, body =
        Cohttp_async.Client.get (Uri.of_string "https://checkip.amazonaws.com")
      in
      Cohttp_async.Body.to_string body)
  with
  | Ok s -> String.strip s
  | Error e -> failwithf "Could not detect public IP: %s" (Exn.to_string e) ()
;;

let unlink_if_exists path =
  match%bind Sys.file_exists path with
  | `Yes -> Unix.unlink path
  | `No | `Unknown -> return ()
;;

(* Fresh ed25519 keypair, regenerated every run. Unlink any stale files first
   so ssh-keygen doesn't bail on "file exists". ssh-keygen creates the private
   key 0600 atomically, so no follow-up chmod (and no race window). Returns
   the private-key path and the trimmed public-key line. *)
let generate_keypair ~dir ~basename ~comment =
  let priv = Filename.concat dir basename in
  let pub = priv ^ ".pub" in
  let%bind () = unlink_if_exists priv in
  let%bind () = unlink_if_exists pub in
  let%bind _ =
    run_or_die
      ~prog:"ssh-keygen"
      ~args:[ "-q"; "-t"; "ed25519"; "-N"; ""; "-f"; priv; "-C"; comment ]
      ()
  in
  let%map pub_text = Reader.file_contents pub in
  priv, String.strip pub_text
;;

(* `dune exec` sets cwd to the dune file's directory, not the project root,
   so we walk up looking for dune-project. The result is what we tar and
   ship to the build instance. *)
let find_project_root start =
  let rec aux dir =
    match%bind Sys.file_exists (Filename.concat dir "dune-project") with
    | `Yes -> return dir
    | `No | `Unknown ->
      let parent = Filename.dirname dir in
      if String.equal parent dir
      then failwithf "no dune-project found searching upward from %s" start ()
      else aux parent
  in
  aux start
;;

(* ~/.cache/awso-ci/ (or $XDG_CACHE_HOME/awso-ci/ if set). Created 0700
   atomically; ssh-keygen drops 0600 keypairs inside. *)
let ensure_cache_dir () =
  let home =
    match Sys.getenv "HOME" with
    | Some h -> h
    | None -> failwithf "HOME is not set" ()
  in
  let base =
    match Sys.getenv "XDG_CACHE_HOME" with
    | Some s when not (String.is_empty s) -> s
    | _ -> Filename.concat home ".cache"
  in
  let dir = Filename.concat base "awso-ci" in
  let%map () = Unix.mkdir ~p:() ~perm:0o700 dir in
  dir
;;

let aws_call ~cfg ~name f request =
  match%bind f ~cfg request with
  | Ok x -> return x
  | Error err ->
    let s = err |> Ec2.Ec2_error.to_json |> Yojson.Safe.to_string in
    failwithf "%s: AWS error: %s" name s ()
;;

let get_aws_account_id ~cfg =
  match%bind Sts.get_caller_identity ~cfg (Sts.GetCallerIdentityRequest.make ()) with
  | Ok resp ->
    (match resp.getCallerIdentityResult.account with
     | Some a -> return a
     | None -> failwithf "GetCallerIdentity: no account in response" ())
  | Error err ->
    let s = err |> Sts.GetCallerIdentityResponse.error_to_json |> Yojson.Safe.to_string in
    failwithf "GetCallerIdentity failed: %s" s ()
;;

(* We stuff the SSH host private key into EC2 user-data so cloud-init can
   install it before sshd starts. Anyone in this AWS account with
   ec2:DescribeInstanceAttribute can read user-data, grab the key, and MITM
   the build box. So make the user pinky-swear once per account that they
   aren't sharing it with randos. Re-prompt only fires if the file gets
   deleted (e.g. switching accounts). *)
let ensure_aws_account_attested ~cache_dir ~account_id =
  let trust_dir = Filename.concat cache_dir "aws-account-trust" in
  let%bind () = Unix.mkdir ~p:() ~perm:0o700 trust_dir in
  let trust_file = Filename.concat trust_dir (account_id ^ ".attested") in
  match%bind Sys.file_exists trust_file with
  | `Yes -> return ()
  | `No | `Unknown ->
    eprintf
      "\n\
       ========================================================\n\
      \  AWS account attestation required (one-time)\n\
       ========================================================\n\n\
       This tool embeds an SSH host private key in EC2 user-data.\n\
       Anyone in this AWS account with ec2:DescribeInstanceAttribute\n\
       can read user-data, recover the key, and impersonate the build\n\
       host to intercept commands and steal source code.\n\n\
       AWS account: %s\n\n\
       Type 'yes' to attest that no untrusted parties have access to\n\
       this AWS account. The attestation will be cached at\n\
      \  %s\n\
       and not asked again unless you delete that file.\n\n\
       attestation> %!"
      account_id
      trust_file;
    let stdin = Lazy.force Reader.stdin in
    let%bind line = Reader.read_line stdin in
    let answer =
      match line with
      | `Ok s -> String.strip (String.lowercase s)
      | `Eof -> ""
    in
    if String.equal answer "yes"
    then Writer.save trust_file ~contents:""
    else failwithf "AWS account %s not attested; aborting" account_id ()
;;

let base64_encode s =
  Cryptokit.transform_string (Cryptokit.Base64.encode_compact_pad ()) s
;;

let import_key_pair ~cfg ~key_name ~public_key =
  let req =
    Ec2.ImportKeyPairRequest.make
      ~keyName:key_name
      ~publicKeyMaterial:(base64_encode public_key)
      ()
  in
  aws_call ~cfg ~name:"ImportKeyPair" (fun ~cfg r -> Ec2.import_key_pair ~cfg r) req
;;

(* Best-effort: silently swallow errors. Used to clear any prior-run keypair
   before ImportKeyPair, since ImportKeyPair refuses to overwrite. *)
let delete_aws_keypair ~cfg ~key_name =
  let req = Ec2.DeleteKeyPairRequest.make ~keyName:key_name () in
  match%map Ec2.delete_key_pair ~cfg req with
  | Ok _ | Error _ -> ()
;;

let install_aws_keypair ~cfg ~key_name ~public_key =
  let%bind () = delete_aws_keypair ~cfg ~key_name in
  let%map _ = import_key_pair ~cfg ~key_name ~public_key in
  ()
;;

(* Returns instance IDs of any not-fully-terminated instances tagged with
   this Name in this region. Used as a sanity check at startup so prior
   runs that left a box alive (e.g. with --dont-shut-down-on-failure) don't
   silently rack up costs. *)
let leftover_instances ~cfg ~name_tag =
  let req =
    Ec2.DescribeInstancesRequest.make
      ~filters:
        [ Ec2.Filter.make ~name:"tag:Name" ~values:[ name_tag ] ()
        ; Ec2.Filter.make
            ~name:"instance-state-name"
            ~values:[ "pending"; "running"; "stopping"; "stopped" ]
            ()
        ]
      ()
  in
  let%map resp =
    aws_call
      ~cfg
      ~name:"DescribeInstances (leftover scan)"
      (fun ~cfg r -> Ec2.describe_instances ~cfg r)
      req
  in
  Option.value resp.reservations ~default:[]
  |> List.concat_map ~f:(fun r -> Option.value r.instances ~default:[])
  |> List.filter_map ~f:(fun (i : Ec2.Instance.t) -> i.instanceId)
;;

let create_security_group ~cfg ~name ~description =
  let req = Ec2.CreateSecurityGroupRequest.make ~groupName:name ~description () in
  let%map resp =
    aws_call
      ~cfg
      ~name:"CreateSecurityGroup"
      (fun ~cfg r -> Ec2.create_security_group ~cfg r)
      req
  in
  Option.value_exn resp.groupId ~message:"CreateSecurityGroup: no group id"
;;

let authorize_ssh_from ~cfg ~sg_id ~ip_cidr =
  let req =
    Ec2.AuthorizeSecurityGroupIngressRequest.make
      ~groupId:sg_id
      ~ipPermissions:
        [ Ec2.IpPermission.make
            ~ipProtocol:"tcp"
            ~fromPort:22
            ~toPort:22
            ~ipRanges:[ Ec2.IpRange.make ~cidrIp:ip_cidr ~description:"awso-ci" () ]
            ()
        ]
      ()
  in
  aws_call
    ~cfg
    ~name:"AuthorizeSecurityGroupIngress"
    (fun ~cfg r -> Ec2.authorize_security_group_ingress ~cfg r)
    req
;;

let launch_spot_instance
      ~cfg
      ~ami_id
      ~instance_type
      ~key_name
      ~sg_id
      ~user_data
      ~max_price
      ~disk_gb
      ~name_tag
  =
  (* Ubuntu cloud-init grows the root partition to fill the underlying EBS
     volume on first boot, so we can just request a bigger one here.
     /dev/sda1 is the Ubuntu ARM64 AMI's root device. *)
  let block_device_mappings =
    [ Ec2.BlockDeviceMapping.make
        ~deviceName:"/dev/sda1"
        ~ebs:
          (Ec2.EbsBlockDevice.make
             ~volumeSize:disk_gb
             ~volumeType:Ec2.VolumeType.Gp3
             ~deleteOnTermination:true
             ())
        ()
    ]
  in
  let tag_specifications =
    [ Ec2.TagSpecification.make
        ~resourceType:Ec2.ResourceType.Instance
        ~tags:[ Ec2.Tag.make ~key:"Name" ~value:name_tag () ]
        ()
    ]
  in
  let req =
    Ec2.RunInstancesRequest.make
      ~imageId:ami_id
      ~minCount:1
      ~maxCount:1
      ~instanceType:(Ec2.InstanceType.of_string instance_type)
      ~keyName:key_name
      ~securityGroupIds:[ sg_id ]
      ~userData:(base64_encode user_data)
      ~instanceInitiatedShutdownBehavior:Ec2.ShutdownBehavior.Terminate
      ~blockDeviceMappings:block_device_mappings
      ~tagSpecifications:tag_specifications
      ~instanceMarketOptions:
        (Ec2.InstanceMarketOptionsRequest.make
           ~marketType:Ec2.MarketType.Spot
           ~spotOptions:
             (Ec2.SpotMarketOptions.make
                ?maxPrice:max_price
                ~spotInstanceType:Ec2.SpotInstanceType.One_time
                ~instanceInterruptionBehavior:Ec2.InstanceInterruptionBehavior.Terminate
                ())
           ())
      ()
  in
  let%map resp =
    aws_call ~cfg ~name:"RunInstances" (fun ~cfg r -> Ec2.run_instances ~cfg r) req
  in
  let inst =
    let instances = Option.value resp.instances ~default:[] in
    match instances with
    | [ i ] -> i
    | _ -> failwithf "RunInstances returned %d instances" (List.length instances) ()
  in
  Option.value_exn inst.instanceId ~message:"RunInstances: no instance id"
;;

let describe_instance ~cfg ~instance_id =
  let req = Ec2.DescribeInstancesRequest.make ~instanceIds:[ instance_id ] () in
  let%map resp =
    aws_call
      ~cfg
      ~name:"DescribeInstances"
      (fun ~cfg r -> Ec2.describe_instances ~cfg r)
      req
  in
  let reservations = Option.value resp.reservations ~default:[] in
  let instances =
    List.concat_map reservations ~f:(fun r -> Option.value r.instances ~default:[])
  in
  match instances with
  | [ i ] -> i
  | _ ->
    failwithf
      "DescribeInstances returned %d for %s"
      (List.length instances)
      instance_id
      ()
;;

let rec wait_for_running ~cfg ~instance_id =
  let%bind i = describe_instance ~cfg ~instance_id in
  let state =
    Option.bind i.state ~f:(fun s -> s.name)
    |> Option.value ~default:Ec2.InstanceStateName.Pending
  in
  match state with
  | Ec2.InstanceStateName.Running ->
    let dns = Option.value i.publicDnsName ~default:"" in
    let ip = Option.value i.publicIpAddress ~default:"" in
    let host = if String.is_empty dns then ip else dns in
    if String.is_empty host
    then failwithf "instance %s has no public DNS/IP" instance_id ()
    else return host
  | Pending ->
    eprintf_now "instance %s pending..." instance_id;
    let%bind () = Clock.after (Time_float.Span.of_sec 5.) in
    wait_for_running ~cfg ~instance_id
  | s ->
    failwithf
      "instance %s in unexpected state %s"
      instance_id
      (Ec2.InstanceStateName.to_string s)
      ()
;;

let wait_for_ssh ~host =
  let attempt () =
    (* host comes from AWS DescribeInstances and in practice is a clean
       hostname or IP, but quote anyway so any future shell metacharacter
       can't escape into the bash -c argument. *)
    match%map
      run_capture
        ~prog:"bash"
        ~args:[ "-c"; sprintf "exec 3<>/dev/tcp/%s/22 && echo ok" (Filename.quote host) ]
        ()
    with
    | Ok s -> String.equal s "ok"
    | Error _ -> false
  in
  let rec loop n =
    let%bind ok = attempt () in
    if ok
    then return ()
    else if n <= 0
    then failwithf "ssh on %s never became reachable" host ()
    else (
      let%bind () = Clock.after (Time_float.Span.of_sec 1.) in
      loop (n - 1))
  in
  loop 300 (* ~5 min at 1s intervals *)
;;

let terminate_instance ~cfg ~instance_id =
  let req = Ec2.TerminateInstancesRequest.make ~instanceIds:[ instance_id ] () in
  let%map _ =
    aws_call
      ~cfg
      ~name:"TerminateInstances"
      (fun ~cfg r -> Ec2.terminate_instances ~cfg r)
      req
  in
  ()
;;

let delete_security_group ~cfg ~sg_id =
  let req = Ec2.DeleteSecurityGroupRequest.make ~groupId:sg_id () in
  let%map _ =
    aws_call
      ~cfg
      ~name:"DeleteSecurityGroup"
      (fun ~cfg r -> Ec2.delete_security_group ~cfg r)
      req
  in
  ()
;;

(* Best-effort by name. Quietly returns if the SG doesn't exist. *)
let delete_security_group_by_name ~cfg ~name =
  let req = Ec2.DescribeSecurityGroupsRequest.make ~groupNames:[ name ] () in
  match%bind Ec2.describe_security_groups ~cfg req with
  | Error _ -> return ()
  | Ok resp ->
    let sgs = Option.value resp.securityGroups ~default:[] in
    Deferred.List.iter ~how:`Sequential sgs ~f:(fun (sg : Ec2.SecurityGroup.t) ->
      match sg.groupId with
      | None -> return ()
      | Some sg_id ->
        (match%map
           Monitor.try_with ~run:`Schedule (fun () -> delete_security_group ~cfg ~sg_id)
         with
         | Ok () | Error _ -> ()))
;;

(* cloud-config user-data. Two jobs:
   1. ssh_keys.ed25519_*: cloud-init's ssh_keys module replaces the
      auto-generated host keys with ours before sshd starts, so the local
      ssh client can pin a known fingerprint instead of TOFU.
   2. runcmd: schedule the absolute-kill shutdown.

   The private-key block must be indented as a YAML block scalar (|), with
   every line of the key indented by exactly 4 spaces beneath the parent. *)
let user_data_script ~max_hours ~host_priv ~host_pub =
  let indent_block s =
    String.split s ~on:'\n'
    |> List.map ~f:(fun line -> "    " ^ line)
    |> String.concat ~sep:"\n"
  in
  sprintf
    {|#cloud-config
ssh_keys:
  ed25519_private: |
%s
  ed25519_public: %s
runcmd:
  - [ sh, -c, "shutdown -h +%d || true" ]
|}
    (indent_block (String.strip host_priv))
    host_pub
    (max_hours * 60)
;;

let ssh_args ~private_key_path ~known_hosts_path ~user ~host =
  [ "-o"
  ; "StrictHostKeyChecking=yes"
  ; "-o"
  ; sprintf "UserKnownHostsFile=%s" known_hosts_path
  ; "-o"
  ; "LogLevel=ERROR"
  ; "-i"
  ; private_key_path
  ; sprintf "%s@%s" user host
  ]
;;

let write_known_hosts ~path ~host ~host_pub =
  Writer.save path ~contents:(sprintf "%s %s\n" host host_pub)
;;

let git_in dir args =
  run_or_die ~prog:"git" ~args:([ "-C"; dir ] @ args) ()
;;

let detect_commit ~workdir = git_in workdir [ "rev-parse"; "HEAD" ]

let working_tree_dirty ~workdir =
  let%map out = git_in workdir [ "status"; "--porcelain" ] in
  not (String.is_empty (String.strip out))
;;

let push_code ~private_key_path ~known_hosts_path ~user ~host ~workdir =
  let ssh =
    String.concat
      ~sep:" "
      (List.map
         (ssh_args ~private_key_path ~known_hosts_path ~user ~host)
         ~f:Filename.quote)
  in
  let remote = "mkdir -p ~/awso && cd ~/awso && tar -xzf -" in
  (* Belt *and* suspenders: don't upload any unnecessary stuff or anything that
     looks like a secret. *)
  let exclude_patterns =
    [ "_build"
    ; "_opam"
    ; ".git"
    ; "vendor"
    ; ".env"
    ; ".env.*"
    ; ".envrc"
    ; "*.pem"
    ; "*.key"
    ; "id_rsa"
    ; "id_ed25519"
    ; "secrets"
    ; "secrets.*"
    ; "credentials"
    ]
  in
  let excludes =
    List.map exclude_patterns ~f:(fun p -> "--exclude=" ^ Filename.quote p)
    |> String.concat ~sep:" "
  in
  let cmd =
    sprintf
      "tar -czf - -C %s %s . | ssh %s %s"
      (Filename.quote workdir)
      excludes
      ssh
      (Filename.quote remote)
  in
  eprintf_now "pushing code to %s ..." host;
  match%bind run_capture ~prog:"bash" ~args:[ "-c"; cmd ] () with
  | Ok _ -> return ()
  | Error stderr -> failwithf "code push failed: %s" stderr ()
;;

let run_remote_build ~private_key_path ~known_hosts_path ~user ~host ~lower_bounds =
  let ssh_argv = ssh_args ~private_key_path ~known_hosts_path ~user ~host in
  (* Lower-bounds mode mirrors opam-ci's lower-bounds job: floor OCaml at 4.14
     (our declared minimum) and bias the solver toward older versions of every
     non-OCaml dep. The default solver times out on resolution this dense, so
     switch to builtin-0install which handles it in seconds. *)
  let switch_version, switch_extra_setup, install_extra_flags =
    if lower_bounds
    then
      ( "4.14.2"
      , "opam option solver=builtin-0install --global"
      , "--criteria='+count[version-lag,solution]'" )
    else "5.3.0", "true", ""
  in
  let remote_script =
    Printf.sprintf
      {|set -euo pipefail

echo '*** machine'
uname -srm
echo "$(nproc) cores"
free -h | awk '/^Mem:/ {print $2 " RAM"}'
df -h / | tail -1 | awk '{print $2 " disk (" $4 " free)"}'

if ! command -v opam >/dev/null; then
  echo '*** installing apt build deps'
  sudo bash -c '
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y \
      build-essential m4 patch perl git pkg-config ca-certificates curl \
      bzip2 unzip xz-utils tar gzip \
      bubblewrap \
      libffi-dev libgmp-dev libssl-dev zlib1g-dev \
      libcurl4-gnutls-dev
  '
  echo '*** installing opam from upstream (apt opam is too old for builtin-0install)'
  sudo bash -c "curl -fsSL https://opam.ocaml.org/install.sh | bash"
fi

if [ ! -d ~/.opam ]; then
  echo '*** initialising opam'
  opam init -y --bare --disable-sandboxing
fi

%s

if ! opam switch list --short 2>/dev/null | grep -qx %s; then
  echo '*** creating %s switch'
  opam switch create %s --no-install
fi
eval "$(opam env --switch=%s)"
opam install -y dune

cd ~/awso
echo '*** opam install --deps-only %s'
# unsafe-yes also auto-accepts depext (sudo apt-get) prompts that --yes alone
# leaves interactive.
OPAMCONFIRMLEVEL=unsafe-yes opam install . --deps-only --yes %s
echo '*** dune build -p (all six packages)'
dune build -p awso-common,awso,awso-async,awso-lwt,awso-sync,awso-cli @install
echo '*** done'
|}
      switch_extra_setup
      switch_version
      switch_version
      switch_version
      switch_version
      (if lower_bounds then "(lower bounds)" else "")
      install_extra_flags
  in
  eprintf_now "starting remote build...";
  let%bind p =
    Process.create ~prog:"ssh" ~args:(ssh_argv @ [ "bash"; "-s" ]) () >>| ok_exn
  in
  let stdin_w = Process.stdin p in
  Writer.write stdin_w remote_script;
  let%bind () = Writer.close stdin_w in
  let stdout_done =
    Reader.transfer (Process.stdout p) (Writer.pipe (force Writer.stdout))
  in
  let stderr_done =
    Reader.transfer (Process.stderr p) (Writer.pipe (force Writer.stderr))
  in
  let%bind () = stdout_done
  and () = stderr_done in
  let%map exit_or_signal = Process.wait p in
  match exit_or_signal with
  | Ok () -> `Success
  | Error _ -> `Build_failed
;;

let main_command =
  let open Command.Let_syntax in
  Command.async
    ~summary:"Build awso on a one-shot spot EC2 (arm64 or x86-64)"
    [%map_open
      let arch =
        flag "--arch" (required arch_arg) ~doc:"ARCH 'arm64' or 'x86-64' (required)"
      and region =
        flag
          "--region"
          (optional_with_default "us-east-1" string)
          ~doc:"REGION AWS region (default us-east-1)"
      and instance_type_opt =
        flag
          "--instance-type"
          (optional string)
          ~doc:
            "TYPE EC2 instance type (default c7g.xlarge for arm64, c7i.xlarge for x86-64)"
      and ami_id_opt =
        flag
          "--ami-id"
          (optional string)
          ~doc:"AMI override AMI id (default = Ubuntu 22.04 for the arch+region)"
      and dont_shut_down_on_failure =
        flag
          "--dont-shut-down-on-failure"
          no_arg
          ~doc:" leave the instance running if the build fails"
      and max_hours =
        flag
          "--max-hours"
          (optional_with_default 12 int)
          ~doc:"N absolute kill-switch hours (default 12)"
      and max_price =
        flag
          "--max-spot-price"
          (optional string)
          ~doc:"USD max hourly spot price (default = on-demand)"
      and disk_gb =
        flag
          "--disk-gb"
          (optional_with_default 40 int)
          ~doc:
            "N root EBS volume size in GiB (default 40; need headroom for opam switch \
             ~5-10G + dune _build ~10-20G across ~300 services)"
      and force =
        flag
          "--force"
          no_arg
          ~doc:" proceed even if a previous awso-ci instance is still running"
      and lower_bounds =
        flag
          "--lower-bounds"
          no_arg
          ~doc:
            " mirror opam-ci's lower-bounds job: OCaml 4.14, builtin-0install solver, \
             solver biased toward older dep versions"
      in
      fun () ->
        let instance_type =
          Option.value instance_type_opt ~default:(default_instance_type arch)
        in
        let ami_id =
          match ami_id_opt with
          | Some s -> s
          | None -> (
            match lookup_default_ami ~arch ~region with
            | Some s -> s
            | None ->
              failwithf
                "no default %s AMI for region %s; pass --ami-id"
                (arch_label arch)
                region
                ())
        in
        let open Deferred.Let_syntax in
        let user_tag = user_tag () in
        let%bind cwd = Unix.getcwd () in
        let%bind workdir = find_project_root cwd in
        let%bind cfg = Awso_async.Cfg.get_exn ~region:(Awso.Region.of_string region) () in
        let%bind cache_dir = ensure_cache_dir () in
        let%bind account_id = get_aws_account_id ~cfg in
        let%bind () = ensure_aws_account_attested ~cache_dir ~account_id in
        let%bind commit = detect_commit ~workdir in
        let%bind dirty = working_tree_dirty ~workdir in
        eprintf_now
          "workdir: %s @ %s%s"
          workdir
          (String.strip commit)
          (if dirty then " (dirty — pushing working tree as-is)" else "");
        let%bind () =
          match%bind leftover_instances ~cfg ~name_tag:user_tag with
          | [] -> return ()
          | ids when force ->
            eprintf_now
              "WARNING: prior %s instance(s) still alive (%s); --force given, proceeding"
              user_tag
              (String.concat ~sep:"," ids);
            return ()
          | ids ->
            eprintf_now "previous %s instance(s) are still alive:" user_tag;
            List.iter ids ~f:(fun id -> eprintf_now "  %s" id);
            eprintf_now "terminate them with:";
            eprintf_now
              "  aws ec2 terminate-instances --region %s --instance-ids %s"
              region
              (String.concat ~sep:" " ids);
            eprintf_now "or pass --force to ignore.";
            exit 2
        in
        let%bind public_ip = detect_public_ip () in
        eprintf_now "public IP: %s" public_ip;
        let%bind private_key_path, public_key =
          generate_keypair
            ~dir:cache_dir
            ~basename:"auth.id_ed25519"
            ~comment:"awso-ci-spot-build"
        in
        eprintf_now "auth keypair: %s" private_key_path;
        let%bind () = install_aws_keypair ~cfg ~key_name:user_tag ~public_key in
        let%bind host_priv_path, host_pub =
          generate_keypair
            ~dir:cache_dir
            ~basename:"host.ed25519"
            ~comment:"awso-ci-host"
        in
        let%bind host_priv = Reader.file_contents host_priv_path in
        let known_hosts_path = Filename.concat cache_dir "known_hosts" in
        let%bind () = delete_security_group_by_name ~cfg ~name:user_tag in
        let%bind sg_id =
          create_security_group ~cfg ~name:user_tag ~description:"awso-ci ephemeral"
        in
        (* From here until [launch_spot_instance] succeeds, any failure leaves
           an orphaned SG. Catch the exception, tear the SG down (with the
           same retry the regular cleanup uses, since SG delete fails until
           any partial instance is gone), and re-raise. After this block
           succeeds the regular cleanup handles SG + instance together. *)
        let sg_cleanup_only () =
          let rec try_sg n =
            match%bind
              Monitor.try_with ~run:`Schedule (fun () ->
                delete_security_group ~cfg ~sg_id)
            with
            | Ok () -> return ()
            | Error _ when n > 0 ->
              let%bind () = Clock.after (Time_float.Span.of_sec 15.) in
              try_sg (n - 1)
            | Error e ->
              eprintf_now "could not delete security group %s: %s" sg_id (Exn.to_string e);
              return ()
          in
          try_sg 8
        in
        let%bind instance_id =
          match%bind
            Monitor.try_with ~run:`Schedule (fun () ->
              let%bind () =
                authorize_ssh_from ~cfg ~sg_id ~ip_cidr:(public_ip ^ "/32")
                |> Deferred.ignore_m
              in
              eprintf_now "security group: %s" sg_id;
              let user_data = user_data_script ~max_hours ~host_priv ~host_pub in
              launch_spot_instance
                ~cfg
                ~ami_id
                ~instance_type
                ~key_name:user_tag
                ~sg_id
                ~user_data
                ~max_price
                ~disk_gb
                ~name_tag:user_tag)
          with
          | Ok instance_id -> return instance_id
          | Error e ->
            eprintf_now "instance setup failed; tearing down sg %s" sg_id;
            let%bind () = sg_cleanup_only () in
            raise e
        in
        eprintf_now
          "launched %s spot instance %s (%dG root)"
          instance_type
          instance_id
          disk_gb;
        let cleanup_armed = ref true in
        let unlink_local_state () =
          let%bind () = unlink_if_exists private_key_path in
          let%bind () = unlink_if_exists (private_key_path ^ ".pub") in
          let%bind () = unlink_if_exists host_priv_path in
          let%bind () = unlink_if_exists (host_priv_path ^ ".pub") in
          unlink_if_exists known_hosts_path
        in
        let cleanup ~unlink_local =
          if not !cleanup_armed
          then return ()
          else (
            cleanup_armed := false;
            let%bind () =
              Monitor.try_with ~run:`Schedule (fun () ->
                terminate_instance ~cfg ~instance_id)
              >>| ignore
            in
            (* SG deletion fails until instance is fully terminated; brief retry. *)
            let rec try_sg n =
              match%bind
                Monitor.try_with ~run:`Schedule (fun () ->
                  delete_security_group ~cfg ~sg_id)
              with
              | Ok () -> return ()
              | Error _ when n > 0 ->
                let%bind () = Clock.after (Time_float.Span.of_sec 15.) in
                try_sg (n - 1)
              | Error e ->
                eprintf_now
                  "could not delete security group %s: %s"
                  sg_id
                  (Exn.to_string e);
                return ()
            in
            let%bind () = try_sg 8 in
            let%bind () = delete_aws_keypair ~cfg ~key_name:user_tag in
            if unlink_local then unlink_local_state () else return ())
        in
        Signal.handle Signal.terminating ~f:(fun signal ->
          eprintf_now "caught %s; tearing down AWS resources..." (Signal.to_string signal);
          don't_wait_for
            (let%bind () = cleanup ~unlink_local:true in
             Shutdown.shutdown 130;
             return ()));
        let%bind host = wait_for_running ~cfg ~instance_id in
        eprintf_now "host: %s ; waiting for ssh..." host;
        let%bind () = wait_for_ssh ~host in
        let%bind () = write_known_hosts ~path:known_hosts_path ~host ~host_pub in
        let user = ssh_user in
        let%bind () =
          push_code ~private_key_path ~known_hosts_path ~user ~host ~workdir
        in
        let%bind status =
          run_remote_build
            ~private_key_path
            ~known_hosts_path
            ~user
            ~host
            ~lower_bounds
        in
        match status with
        | `Success ->
          eprintf_now "build succeeded; cleaning up";
          let%bind () = cleanup ~unlink_local:true in
          return ()
        | `Build_failed when dont_shut_down_on_failure ->
          eprintf_now "build failed and --dont-shut-down-on-failure set.";
          eprintf_now "instance %s is still running. SSH:" instance_id;
          eprintf_now
            "  ssh -i %s -o UserKnownHostsFile=%s %s@%s"
            private_key_path
            known_hosts_path
            ssh_user
            host;
          eprintf_now "remember to:";
          eprintf_now "  aws ec2 terminate-instances --instance-ids %s" instance_id;
          eprintf_now "  aws ec2 delete-security-group --group-id %s" sg_id;
          eprintf_now "  aws ec2 delete-key-pair --key-name %s" user_tag;
          (* Disarm the signal handler — Ctrl-C should NOT tear down. *)
          cleanup_armed := false;
          exit 1
        | `Build_failed ->
          eprintf_now "build failed; tearing down";
          let%bind () = cleanup ~unlink_local:true in
          exit 1]
;;

let () = Command_unix.run main_command
