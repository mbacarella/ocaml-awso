module Ec2 = Awso_ec2_eio

let print_row a b c d = Printf.printf "%-16s  %-15s  %-39s  %-20s\n" a b c d

let print_instance instance =
  let name =
    Option.bind instance.Ec2.Instance.tags (fun tags ->
      List.find_map
        (function
          | { Ec2.Tag.key = Some "Name"; value = Some v } -> Some v
          | _ -> None)
        tags)
  in
  let instance_type =
    match instance.instanceType with
    | Some it -> Ec2.InstanceType.to_string it
    | None -> ""
  in
  print_row
    instance_type
    (Option.value instance.publicIpAddress ~default:"")
    (Option.value instance.ipv6Address ~default:"")
    (Option.value name ~default:"")
;;

let main env =
  let cfg = Awso_eio.Cfg.get_exn ~env () in
  match Ec2.describe_instances ~cfg (Ec2.DescribeInstancesRequest.make ()) with
  | Error e ->
    failwith
      (Printf.sprintf
         "Ec2.describe_instances: %s"
         (Yojson.Safe.to_string (Ec2.Ec2_error.to_json e)))
  | Ok { reservations; _ } -> (
    let instances =
      reservations
      |> Option.value ~default:[]
      |> List.concat_map (function
        | { Ec2.Reservation.instances = None; _ } -> []
        | { instances = Some instances; _ } -> instances)
    in
    match instances with
    | [] -> print_endline "no instances"
    | instances ->
      print_row "instance-type" "public ipv4" "public ipv6" "name";
      print_row
        (String.make 16 '-')
        (String.make 15 '-')
        (String.make 39 '-')
        (String.make 20 '-');
      List.iter print_instance instances)
;;

let () = Eio_main.run main
