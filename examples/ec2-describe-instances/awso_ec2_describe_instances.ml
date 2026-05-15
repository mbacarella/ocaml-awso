open Core
open Async
module Ec2 = Awso_ec2_async

let ec2_describe_instances () =
  let%bind response =
    Ec2.describe_instances (Ec2.Values.DescribeInstancesRequest.make ())
  in
  let reservations =
    match response with
    | Error (`Transport err) ->
      let errstr = err |> Awso.Http.Io.Error.yojson_of_call |> Yojson.Safe.pretty_to_string in
      failwithf "Transport error communicating with EC2: %s\n" errstr ()
    | Error (`AWS aws) ->
      let errstr = aws |> Ec2.Values.Ec2_error.to_json |> Awso.Json.to_string in
      failwithf "AWS says your query had an error: %s\n" errstr ()
    | Ok result -> result.reservations
  in
  let () =
    reservations
    |> Option.value_exn ~here:[%here]
    |> List.iter ~f:(fun reservation ->
      reservation.Ec2.Values.Reservation.instances
      |> Option.value ~default:[]
      |> List.iter ~f:(fun instance ->
        let str = instance |> Ec2.Values.Instance.to_json |> Awso.Json.to_string in
        print_endline str))
  in
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
