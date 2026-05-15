open Core
open Async
module Ec2 = Awso_ec2_async

let describe_instance_types ~min_vcpus =
  let filter =
    Ec2.Values.Filter.make
      ~name:"processor-info.supported-architecture"
      ~values:[ "x86_64" ]
      ()
  in
  let rec fetch_all ?next_token acc =
    let req =
      Ec2.Values.DescribeInstanceTypesRequest.make
        ~filters:[ filter ]
        ~maxResults:100
        ?nextToken:next_token
        ()
    in
    let%bind response = Ec2.describe_instance_types req in
    let result =
      match response with
      | Error (`Transport err) ->
        let s =
          err |> Awso.Http.Io.Error.yojson_of_call |> Yojson.Safe.pretty_to_string
        in
        failwithf "Transport error: %s" s ()
      | Error (`AWS aws) ->
        let s = aws |> Ec2.Values.Ec2_error.to_json |> Yojson.Safe.to_string in
        failwithf "AWS error: %s" s ()
      | Ok result -> result
    in
    let instances = Option.value ~default:[] result.instanceTypes in
    let acc = acc @ instances in
    match result.nextToken with
    | Some token -> fetch_all ~next_token:token acc
    | None -> return acc
  in
  let%bind all_types = fetch_all [] in
  let rows =
    List.filter_map all_types ~f:(fun info ->
      let open Ec2.Values in
      let vcpus =
        Option.bind info.vCpuInfo ~f:(fun v -> v.VCpuInfo.defaultVCpus)
      in
      let mem_mib =
        Option.bind info.memoryInfo ~f:(fun m ->
          Option.map m.MemoryInfo.sizeInMiB ~f:Int64.to_int_exn)
      in
      let name =
        Option.map info.instanceType ~f:InstanceType.to_string
      in
      match name, vcpus with
      | Some name, Some vcpus when vcpus >= min_vcpus ->
        let mem_gb = Option.value_map mem_mib ~default:"?" ~f:(fun m ->
          Int.to_string (m / 1024))
        in
        Some (vcpus, name, mem_gb)
      | _ -> None)
  in
  let rows =
    List.sort rows ~compare:(fun (v1, _, _) (v2, _, _) -> Int.compare v2 v1)
  in
  printf "%4s  %-28s %s\n" "vCPU" "Instance Type" "Memory (GB)";
  printf "%s\n" (String.make 50 '-');
  List.iter rows ~f:(fun (vcpus, name, mem) ->
    printf "%4d  %-28s %s\n" vcpus name mem);
  return ()
;;

let () =
  let cmd =
    Command.async
      ~summary:"List EC2 instance types sorted by vCPU count"
      (let%map_open.Command min_vcpus =
         flag
           "--min-vcpus"
           (optional_with_default 64 int)
           ~doc:"N Minimum vCPUs (default: 64)"
       in
       fun () -> describe_instance_types ~min_vcpus)
  in
  Command_unix.run cmd
;;
