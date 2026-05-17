open Core
open Async
module Ec2 = Awso_ec2_async

let ec2_describe_instances () =
  match%bind Ec2.describe_instances (Ec2.DescribeInstancesRequest.make ()) with
  | Error aws ->
    let errstr = aws |> Ec2.Ec2_error.to_json |> Yojson.Safe.to_string in
    failwithf "AWS says your query had an error: %s\n" errstr ()
  | Ok result ->
    result.reservations
    |> Option.value_exn ~here:[%here]
    |> List.iter ~f:(fun reservation ->
      reservation.Ec2.Reservation.instances
      |> Option.value ~default:[]
      |> List.iter ~f:(fun instance ->
        let str = instance |> Ec2.Instance.to_json |> Yojson.Safe.pretty_to_string in
        print_endline str));
    return ()
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
