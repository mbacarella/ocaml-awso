(* The Cfg module is needed to access credentials and other configuration settings. *)
module Cfg = Awso_async.Cfg

(* This local module isn't strictly necessary but if you use multiple APIs it will keep
   API specific functions tidy.

   For the lwt version, you would simply replace "_async" with "_lwt". *)
module Ec2 = struct
  module Values = Awso_ec2_async.Values
  module Io = Awso_ec2_async.Io

  let call = Awso_async.Http.Io.call ~service:Values.service
end

(*
   let dispatch_exn ~name ~sexp_of_error ~f =
   match%bind f () with
   | Ok v -> return v
   | Error (`Transport err) -> raise_transport_error ~name err
   | Error (`AWS aws) ->
   failwithf "%s: %s" name (aws |> sexp_of_error |> Sexp.to_string_hum) ()
   ;;
*)

let ec2_describe_instances ~cfg =
  (* Make EC2 API call *)
  let%bind response =
    Ec2.Io.describe_instances
      (Ec2.call ~cfg)
      (Ec2.Values.DescribeInstancesRequest.make ())
  in
  (* Retrieve 'reservations' from result *)
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
  (* Use sexp-expressions to pretty print the instances. *)
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
