open Core
open Async
module Ec2 = Awso_ec2_async

let or_die = function
  | Ok result -> result
  | Error aws ->
    let s = aws |> Ec2.Ec2_error.to_json |> Yojson.Safe.to_string in
    failwithf "aws error: %s" s ()
;;

let fetch_instance_types ~min_vcpus ~max_vcpus =
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
      | Some name, Some vcpus when vcpus >= min_vcpus && vcpus < max_vcpus ->
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

let fetch_placement_score ~region ~instance_type =
  let req =
    Ec2.GetSpotPlacementScoresRequest.make
      ~instanceTypes:[ instance_type ]
      ~singleAvailabilityZone:true
      ~regionNames:[ region ]
      ~targetCapacity:1
      ()
  in
  match%map Ec2.get_spot_placement_scores req with
  | Error _ -> None
  | Ok result ->
    Option.value result.spotPlacementScores ~default:[]
    |> List.filter_map ~f:(fun s -> s.Ec2.SpotPlacementScore.score)
    |> List.max_elt ~compare:Int.compare
;;

let fetch_placement_scores ~region instance_types =
  let%map results =
    Deferred.List.filter_map ~how:(`Max_concurrent_jobs 10) instance_types ~f:(fun it ->
      match%map fetch_placement_score ~region ~instance_type:it with
      | Some score -> Some (it, score)
      | None -> None)
  in
  String.Map.of_alist_exn results
;;

let score_label = function
  | n when n <= 0 -> "none"
  | 1 -> "tight"
  | 2 -> "marginal"
  | 3 -> "ok"
  | 4 | 5 | 6 -> "good"
  | _ -> "plentiful"
;;

let find_box_with_most_cores ~min_vcpus ~max_vcpus ~no_spot ~no_scores ~region =
  let%bind rows = fetch_instance_types ~min_vcpus ~max_vcpus in
  let names = List.map rows ~f:(fun (_, name, _) -> name) in
  let%bind spot_prices, scores =
    Deferred.both
      (if no_spot
       then return String.Map.empty
       else fetch_spot_prices ~instance_types:names)
      (if no_scores then return String.Map.empty else fetch_placement_scores ~region names)
  in
  if no_spot && no_scores
  then (
    printf "%4s  %-28s %s\n" "vCPU" "Instance Type" "Memory (GB)";
    printf "%s\n" (String.make 50 '-'))
  else (
    printf
      "%4s  %-28s %6s  %-12s  %s\n"
      "vCPU"
      "Instance Type"
      "Mem GB"
      "Capacity"
      "Spot $/hr (best AZ)";
    printf "%s\n" (String.make 86 '-'));
  let rows =
    if no_spot || no_scores
    then rows
    else
      List.sort rows ~compare:(fun a b ->
        let a_vcpus = fst3 a in
        let b_vcpus = fst3 b in
        match Int.compare b_vcpus a_vcpus with
        | 1 -> 1
        | -1 -> -1
        | 0 -> (
          let b_name = snd3 b in
          let a_name = snd3 a in
          let spot_a =
            Map.find spot_prices a_name
            |> Option.map ~f:(Fn.compose Float.of_string fst)
            |> Option.value ~default:Float.max_value
          in
          let spot_b =
            Map.find spot_prices b_name
            |> Option.map ~f:(Fn.compose Float.of_string fst)
            |> Option.value ~default:Float.max_value
          in
          match Float.compare spot_a spot_b with
          | -1 -> -1
          | 0 ->
            let score_a = Map.find scores a_name |> Option.value ~default:(-1) in
            let score_b = Map.find scores b_name |> Option.value ~default:(-1) in
            Int.compare score_b score_a
          | 1 -> 1
          | _ -> assert false)
        | _ -> assert false)
  in
  List.iter rows ~f:(fun (vcpus, name, mem) ->
    if no_spot && no_scores
    then printf "%4d  %-28s %s\n" vcpus name mem
    else (
      let spot_str =
        match Map.find spot_prices name with
        | Some (price, az) -> sprintf "$%s (%s)" price az
        | None -> if no_spot then "" else "n/a"
      in
      let capacity_str =
        match Map.find scores name with
        | Some s -> sprintf "%s (%d)" (score_label s) s
        | _ -> if no_scores then "" else "?"
      in
      printf "%4d  %-28s %6s  %-12s  %s\n" vcpus name mem capacity_str spot_str));
  return ()
;;

let () =
  let cmd =
    Command.async
      ~summary:"find best and most available spot-instance boxes for given num vcpus"
      (let%map_open.Command min_vcpus =
         flag
           "--min-vcpus"
           (optional_with_default 32 int)
           ~doc:"N minimum vCPUs (default: 32)"
       and max_vcpus =
         flag
           "--max-vcpus"
           (optional_with_default 64 int)
           ~doc:"N minimum vCPUs (default: 64)"
       and no_spot = flag "--no-spot" no_arg ~doc:" don't fetch current spot prices"
       and no_scores =
         flag
           "--no-scores"
           no_arg
           ~doc:" don't fetch spot placement scores (saves ~one API call per type)"
       and region =
         flag
           "--region"
           (optional_with_default "us-east-1" string)
           ~doc:"REGION AWS region for spot scores (default us-east-1)"
       in
       fun () ->
         find_box_with_most_cores ~min_vcpus ~max_vcpus ~no_spot ~no_scores ~region)
  in
  Command_unix.run cmd
;;
