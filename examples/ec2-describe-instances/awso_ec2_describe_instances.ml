module Ec2 = struct
  module Values = Awso_ec2_async.Values
  module Io = Awso_ec2_async.Io
end

let ec2_describe_instances ~cfg =
  let%bind response =
    Ec2.Io.describe_instances
      ~cfg
      (Ec2.Values.DescribeInstancesRequest.make ())
  in
  let reservations =
    match response with
    | Error (`Transport err) ->
      let errstr = err |> Awso.Http.Io.Error.sexp_of_call |> Sexp.to_string_hum in
      failwithf "Transport error communicating with EC2: %s\n" errstr ()
    | Error (`AWS aws) ->
      let errstr = aws |> Ec2.Values.Ec2_error.sexp_of_t |> Sexp.to_string_hum in
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
        let str = instance |> Ec2.Values.Instance.sexp_of_t |> Sexp.to_string_hum in
        print_endline str))
  in
  return ()
;;

let main () =
  let%bind cfg = Awso_async.Cfg.get_exn () in
  ec2_describe_instances ~cfg
;;

let () =
  let cmd =
    Command.async
      ~summary:"Test script: list EC2 instances in default region"
      (let%map_open.Command () = return () in
       fun () -> main ())
  in
  Command_unix.run cmd
;;
