open Core
open Async
module Ec2 = Awso_ec2_async

let or_die = function
  | Ok result -> result
  | Error aws ->
    let s = aws |> Ec2.Ec2_error.to_json |> Yojson.Safe.to_string in
    failwithf "aws error: %s" s ()
;;

let fetch_instance_types ~min_vcpus =
  let filter =
    Ec2.Filter.make ~name:"processor-info.supported-architecture" ~values:[ "x86_64" ] ()
  in
  let rec fetch_all ?next_token acc =
    let req =
      Ec2.DescribeInstanceTypesRequest.make
        ~filters:[ filter ]
        ~maxResults:100
        ?nextToken:next_token
        ()
    in
    let%bind result = Ec2.describe_instance_types req >>| or_die in
    let instances = Option.value ~default:[] result.instanceTypes in
    let acc = acc @ instances in
    match result.nextToken with
    | Some token -> fetch_all ~next_token:token acc
    | None -> return acc
  in
  let%bind all_types = fetch_all [] in
  let rows =
    List.filter_map all_types ~f:(fun info ->
      let open Ec2 in
      let vcpus = Option.bind info.vCpuInfo ~f:(fun v -> v.VCpuInfo.defaultVCpus) in
      let mem_mib =
        Option.bind info.memoryInfo ~f:(fun m ->
          Option.map m.MemoryInfo.sizeInMiB ~f:Int64.to_int_exn)
      in
      let name = Option.map info.instanceType ~f:InstanceType.to_string in
      match name, vcpus with
      | Some name, Some vcpus when vcpus >= min_vcpus ->
        let mem_gb =
          Option.value_map mem_mib ~default:"?" ~f:(fun m -> Int.to_string (m / 1024))
        in
        Some (vcpus, name, mem_gb)
      | _ -> None)
  in
  return (List.sort rows ~compare:(fun (v1, _, _) (v2, _, _) -> Int.compare v2 v1))
;;

let fetch_spot_prices ~instance_types =
  let open Ec2 in
  let instance_type_values =
    List.filter_map instance_types ~f:(fun name ->
      Option.try_with (fun () -> InstanceType.of_string name))
  in
  let req =
    DescribeSpotPriceHistoryRequest.make
      ~instanceTypes:instance_type_values
      ~productDescriptions:[ "Linux/UNIX" ]
      ~maxResults:1000
      ()
  in
  let%bind result = Ec2.describe_spot_price_history req >>| or_die in
  let prices = Option.value ~default:[] result.spotPriceHistory in
  let best_per_type =
    List.fold prices ~init:String.Map.empty ~f:(fun acc sp ->
      match sp.SpotPrice.instanceType, sp.SpotPrice.spotPrice with
      | Some it, Some price -> (
        let key = InstanceType.to_string it in
        let az = Option.value ~default:"?" sp.SpotPrice.availabilityZone in
        match Map.find acc key with
        | Some (existing_price, _) when String.( <= ) existing_price price -> acc
        | _ -> Map.set acc ~key ~data:(price, az))
      | _ -> acc)
  in
  return best_per_type
;;

let find_box_with_most_cores ~min_vcpus ~show_spot =
  let%bind rows = fetch_instance_types ~min_vcpus in
  let%bind spot_prices =
    if show_spot
    then fetch_spot_prices ~instance_types:(List.map rows ~f:(fun (_, name, _) -> name))
    else return String.Map.empty
  in
  if show_spot
  then (
    printf "%4s  %-28s %6s  %s\n" "vCPU" "Instance Type" "Mem GB" "Spot $/hr (best AZ)";
    printf "%s\n" (String.make 70 '-'))
  else (
    printf "%4s  %-28s %s\n" "vCPU" "Instance Type" "Memory (GB)";
    printf "%s\n" (String.make 50 '-'));
  List.iter rows ~f:(fun (vcpus, name, mem) ->
    if show_spot
    then (
      let spot_str =
        match Map.find spot_prices name with
        | Some (price, az) -> sprintf "$%s (%s)" price az
        | None -> "n/a"
      in
      printf "%4d  %-28s %6s  %s\n" vcpus name mem spot_str)
    else printf "%4d  %-28s %s\n" vcpus name mem);
  return ()
;;

let () =
  let cmd =
    Command.async
      ~summary:"find the box with the most cores (and optionally spot prices)"
      (let%map_open.Command min_vcpus =
         flag
           "--min-vcpus"
           (optional_with_default 64 int)
           ~doc:"N minimum vCPUs (default: 64)"
       and show_spot = flag "--spot" no_arg ~doc:" show current spot prices" in
       fun () -> find_box_with_most_cores ~min_vcpus ~show_spot)
  in
  Command_unix.run cmd
;;
