open Core
open Async

open Awso_sqs_async

let main () =
  let%bind cfg = Awso_async.Cfg.get_exn () in
  let queue_name = "my-foo-test-queue" in
  printf "creating queue: %s\n" queue_name;
  let%bind res = Sqs.create_queue cfg ~queue_name in
  printf
    "create_queue result: %s\n"
    (res |> CreateQueueResult.to_json |> Yojson.Safe.to_string);
  let queue_url =
    res.CreateQueueResult.createQueueResult.queueUrl
    |> Option.value_exn ~message:"No queueUrl"
  in
  printf "listing queues\n";
  let%bind res = Sqs.list_queues cfg in
  let lqr = res.ListQueuesResult.listQueuesResult in
  Option.iter lqr.ListQueuesResult.queueUrls ~f:(fun queue_urls ->
    List.iter queue_urls ~f:(fun url -> printf "- %s\n" url));
  let message_body = sprintf !"Test message body %{Time_float_unix}" (Time_float_unix.now ()) in
  printf "sending message '%s' to queue %s\n" message_body queue_url;
  let%bind res = Sqs.send_message cfg ~queue_url ~message_body in
  printf
    "send_message result: %s\n"
    (res |> SendMessageResult.to_json |> Yojson.Safe.to_string);
  printf "receive_message: %s\n" queue_url;
  let%bind res = Sqs.receive_message cfg ~queue_url in
  printf
    "receive_message result: %s\n"
    (res |> ReceiveMessageResult.to_json |> Yojson.Safe.to_string);
  let%bind () = Sqs.delete_queue cfg ~queue_url in
  printf "queue %s deleted\n" queue_url;
  return ()
;;

let () =
  don't_wait_for
    (Monitor.try_with (fun () -> main ())
    >>= fun res ->
    match res with
    | Ok () ->
      Shutdown.shutdown 0;
      return ()
    | Error e ->
      eprintf "error: %s\n" (Exn.to_string e);
      Shutdown.shutdown 1;
      return ());
  never_returns (Scheduler.go ())
;;
