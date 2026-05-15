open! Values
open! Core
open! Async

let dispatch_exn ~name ~f ~error_to_json =
  match%bind f () with
  | Ok v -> return v
  | Error (`AWS aws) ->
    failwithf "%s: %s" name (aws |> error_to_json |> Yojson.Safe.to_string) ()
  | Error (`Transport err) ->
    failwithf
      "%s: transport error: %s"
      name
      (err |> Awso.Http.Io.Error.yojson_of_call |> Yojson.Safe.pretty_to_string)
      ()
;;

let unit_json () = `Assoc []

let add_permission cfg ~queue_url ~label ~aws_account_ids ~actions =
  dispatch_exn ~name:"sqs.add_permission" ~error_to_json:unit_json ~f:(fun () ->
    Io.add_permission
      ~cfg
      (AddPermissionRequest.make
         ~queueUrl:queue_url
         ~label
         ~aWSAccountIds:aws_account_ids
         ~actions
         ()))
;;

let change_message_visibility cfg ~queue_url ~receipt_handle ~visibility_timeout =
  dispatch_exn
    ~name:"sqs.change_message_visibility"
    ~error_to_json:unit_json
    ~f:(fun () ->
    Io.change_message_visibility
      ~cfg
      (ChangeMessageVisibilityRequest.make
         ~queueUrl:queue_url
         ~receiptHandle:receipt_handle
         ~visibilityTimeout:visibility_timeout
         ()))
;;

let change_message_visibility_batch cfg ~queue_url ~entries =
  dispatch_exn
    ~name:"sqs.message_visibility_batch"
    ~error_to_json:ChangeMessageVisibilityBatchResult.error_to_json
    ~f:(fun () ->
    Io.change_message_visibility_batch
      ~cfg
      (ChangeMessageVisibilityBatchRequest.make ~queueUrl:queue_url ~entries ()))
;;

let create_queue ?attributes cfg ~queue_name =
  dispatch_exn
    ~name:"sqs.create_queue"
    ~error_to_json:CreateQueueResult.error_to_json
    ~f:(fun () ->
    Io.create_queue
      ~cfg
      (CreateQueueRequest.make ?attributes ~queueName:queue_name ()))
;;

let delete_message cfg ~queue_url ~receipt_handle =
  dispatch_exn ~name:"sqs.delete_message" ~error_to_json:unit_json ~f:(fun () ->
    Io.delete_message
      ~cfg
      (DeleteMessageRequest.make
         ~queueUrl:queue_url
         ~receiptHandle:receipt_handle
         ()))
;;

let delete_message_batch cfg ~queue_url ~entries =
  dispatch_exn
    ~name:"sqs.delete_message_batch"
    ~error_to_json:DeleteMessageBatchResult.error_to_json
    ~f:(fun () ->
    Io.delete_message_batch
      ~cfg
      (DeleteMessageBatchRequest.make ~queueUrl:queue_url ~entries ()))
;;

let delete_queue cfg ~queue_url =
  dispatch_exn ~name:"sqs.delete_queue" ~error_to_json:unit_json ~f:(fun () ->
    Io.delete_queue ~cfg (DeleteQueueRequest.make ~queueUrl:queue_url ()))
;;

let get_queue_attributes ?attribute_names cfg ~queue_url =
  dispatch_exn
    ~name:"sqs.get_queue_attributes"
    ~error_to_json:GetQueueAttributesResult.error_to_json
    ~f:(fun () ->
    Io.get_queue_attributes
      ~cfg
      (GetQueueAttributesRequest.make
         ?attributeNames:attribute_names
         ~queueUrl:queue_url
         ()))
;;

let get_queue_url ?queue_owner_aws_account_id cfg ~queue_name =
  dispatch_exn
    ~name:"sqs.get_queue_url"
    ~error_to_json:GetQueueUrlResult.error_to_json
    ~f:(fun () ->
    Io.get_queue_url
      ~cfg
      (GetQueueUrlRequest.make
         ?queueOwnerAWSAccountId:queue_owner_aws_account_id
         ~queueName:queue_name
         ()))
;;

let list_dead_letter_source_queues cfg ~queue_url =
  dispatch_exn
    ~name:"sqs.list_dead_letter_source_queues"
    ~error_to_json:ListDeadLetterSourceQueuesResult.error_to_json
    ~f:(fun () ->
    Io.list_dead_letter_source_queues
      ~cfg
      (ListDeadLetterSourceQueuesRequest.make ~queueUrl:queue_url ()))
;;

let list_queue_tags cfg ~queue_url =
  dispatch_exn
    ~name:"sqs.list_queue_tags"
    ~error_to_json:ListQueueTagsResult.error_to_json
    ~f:(fun () ->
    Io.list_queue_tags
      ~cfg
      (ListQueueTagsRequest.make ~queueUrl:queue_url ()))
;;

let list_queues ?queue_name_prefix cfg =
  dispatch_exn
    ~name:"sqs.list_queues"
    ~error_to_json:ListQueuesResult.error_to_json
    ~f:(fun () ->
    Io.list_queues
      ~cfg
      (ListQueuesRequest.make ?queueNamePrefix:queue_name_prefix ()))
;;

let purge_queue cfg ~queue_url =
  dispatch_exn ~name:"sqs.purge_queue" ~error_to_json:unit_json ~f:(fun () ->
    Io.purge_queue ~cfg (PurgeQueueRequest.make ~queueUrl:queue_url ()))
;;

let receive_message
  ?attribute_names
  ?message_attribute_names
  ?max_number_of_messages
  ?visibility_timeout
  ?wait_time_seconds
  ?receive_request_attempt_id
  cfg
  ~queue_url
  =
  dispatch_exn
    ~name:"sqs.receive_message"
    ~error_to_json:ReceiveMessageResult.error_to_json
    ~f:(fun () ->
    Io.receive_message
      ~cfg
      (ReceiveMessageRequest.make
         ?attributeNames:attribute_names
         ?messageAttributeNames:message_attribute_names
         ?maxNumberOfMessages:max_number_of_messages
         ?visibilityTimeout:visibility_timeout
         ?waitTimeSeconds:wait_time_seconds
         ?receiveRequestAttemptId:receive_request_attempt_id
         ~queueUrl:queue_url
         ()))
;;

let remove_permission cfg ~queue_url ~label =
  dispatch_exn ~name:"sqs.remove_permission" ~error_to_json:unit_json ~f:(fun () ->
    Io.remove_permission
      ~cfg
      (RemovePermissionRequest.make ~queueUrl:queue_url ~label ()))
;;

let send_message
  ?delay_seconds
  ?message_attributes
  ?message_deduplication_id
  ?message_group_id
  cfg
  ~queue_url
  ~message_body
  =
  dispatch_exn
    ~name:"sqs.send_message"
    ~error_to_json:SendMessageResult.error_to_json
    ~f:(fun () ->
    Io.send_message
      ~cfg
      (SendMessageRequest.make
         ?delaySeconds:delay_seconds
         ?messageAttributes:message_attributes
         ?messageDeduplicationId:message_deduplication_id
         ?messageGroupId:message_group_id
         ~queueUrl:queue_url
         ~messageBody:message_body
         ()))
;;

let send_message_batch cfg ~queue_url ~entries =
  dispatch_exn
    ~name:"sqs.send_message_batch"
    ~error_to_json:SendMessageBatchResult.error_to_json
    ~f:(fun () ->
    Io.send_message_batch
      ~cfg
      (SendMessageBatchRequest.make ~queueUrl:queue_url ~entries ()))
;;

let set_queue_attributes cfg ~queue_url ~attributes =
  dispatch_exn ~name:"sqs.set_queue_attributes" ~error_to_json:unit_json ~f:(fun () ->
    Io.set_queue_attributes
      ~cfg
      (SetQueueAttributesRequest.make ~queueUrl:queue_url ~attributes ()))
;;

let tag_queue cfg ~queue_url ~tags =
  dispatch_exn ~name:"sqs.tag_queue" ~error_to_json:unit_json ~f:(fun () ->
    Io.tag_queue ~cfg (TagQueueRequest.make ~queueUrl:queue_url ~tags ()))
;;

let untag_queue cfg ~queue_url ~tag_keys =
  dispatch_exn ~name:"sqs.untag_queue" ~error_to_json:unit_json ~f:(fun () ->
    Io.untag_queue
      ~cfg
      (UntagQueueRequest.make ~queueUrl:queue_url ~tagKeys:tag_keys ()))
;;
