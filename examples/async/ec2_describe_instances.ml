open! Core
open! Async
module Ec2 = Awso_ec2_async

let print_row a b c d = printf "%-16s  %-15s  %-39s  %-20s\n" a b c d

let print_instance instance =
  let name =
    Option.bind instance.Ec2.Instance.tags ~f:(fun tags ->
      List.find_map tags ~f:(function
        | { Ec2.Tag.key = Some "Name"; value = Some v } -> Some v
        | _ -> None))
  in
  let instance_type =
    match instance.Ec2.Instance.instanceType with
    | Some it -> Ec2.InstanceType.to_string it
    | None -> ""
  in
  print_row
    instance_type
    (Option.value instance.publicIpAddress ~default:"")
    (Option.value instance.ipv6Address ~default:"")
    (Option.value name ~default:"")
;;

let ec2_describe_instances () =
  match%bind Ec2.describe_instances (Ec2.DescribeInstancesRequest.make ()) with
  | Error e ->
    failwithf !"Ec2.describe_instances: %{Yojson.Safe}" (Ec2.Ec2_error.to_json e) ()
  | Ok { reservations; _ } -> (
    let instances =
      reservations
      |> Option.value ~default:[]
      |> List.concat_map ~f:(function
        | { Ec2.Reservation.instances = None; _ } -> []
        | { instances = Some instances; _ } -> instances)
    in
    match instances with
    | [] ->
      print_endline "no instances";
      return ()
    | instances ->
      print_row "instance-type" "public ipv4" "public ipv6" "name";
      print_row
        (String.make 16 '-')
        (String.make 15 '-')
        (String.make 39 '-')
        (String.make 20 '-');
      List.iter instances ~f:print_instance;
      return ())
;;

let () =
  let cmd =
    Command.async
      ~summary:"Test script: list EC2 instances in default region"
      (let%map_open.Command () = return () in
       fun () -> ec2_describe_instances ())
  in
  Command_unix.run cmd
;;
