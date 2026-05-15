open Lwt.Infix
module Cfg = Awso_lwt.Cfg

module Ec2 = Awso_ec2_lwt
module Ecs = Awso_ecs_lwt
module Ecr = Awso_ecr_lwt
module S3 = Awso_s3_lwt

let pr = Caml.print_endline

let dispatch_exn ~name ~error_to_json ~f =
  match%bind f () with
  | Ok v -> return v
  | Error (`Transport err) ->
    failwithf "%s: %s" name (Awso.Http.Io.Error.yojson_of_call err |> Yojson.Safe.pretty_to_string) ()
  | Error (`AWS aws) ->
    failwithf "%s: %s" name (aws |> error_to_json |> Yojson.Safe.to_string) ()
;;

let suite_main ~sso bucket () =
  let%bind cfg =
    match sso with
    | true -> Awso_sso_lwt.Util.Cfg.get_exn ()
    | false -> Cfg.get_exn ()
  in
  let%bind () =
    pr "=== EC2 ===";
    dispatch_exn
      ~name:"ec2.describe_instances"
      ~error_to_json:Ec2.Ec2_error.to_json
      ~f:(fun () ->
      Ec2.describe_instances
        ~cfg
        (Ec2.DescribeInstancesRequest.make ()))
    >|= fun v ->
    Option.iter v.Ec2.DescribeInstancesResult.reservations ~f:(fun reservation ->
      List.iter reservation ~f:(fun x ->
        Option.iter x.Ec2.Reservation.ownerId ~f:pr))
  in
  let%bind () =
    pr "=== ECS ===";
    dispatch_exn
      ~name:"ecs.describe_clusters"
      ~error_to_json:Ecs.DescribeClustersResponse.error_to_json
      ~f:(fun () ->
      Ecs.describe_clusters
        ~cfg
        (Ecs.DescribeClustersRequest.make ()))
    >|= fun v ->
    Option.iter v.Ecs.DescribeClustersResponse.clusters ~f:(fun cluster ->
      List.iter cluster ~f:(fun repo ->
        Option.iter repo.Ecs.Cluster.clusterName ~f:pr))
  in
  let%bind () =
    pr "=== ECR ===";
    let repositoryName = Ecr.RepositoryName.make "delme/delme" in
    let%bind () =
      dispatch_exn
        ~name:"ecr.get_authorization_token"
        ~error_to_json:Ecr.GetAuthorizationTokenResponse.error_to_json
        ~f:(fun () ->
        Ecr.get_authorization_token
          ~cfg
          (Ecr.GetAuthorizationTokenRequest.make ()))
      >|= fun v ->
      Option.iter
        v.Ecr.GetAuthorizationTokenResponse.authorizationData
        ~f:(fun xl ->
        List.iter xl ~f:(fun ad ->
          Option.iter
            (ad.Ecr.AuthorizationData.authorizationToken :> string option)
            ~f:pr))
    in
    let%bind () =
      dispatch_exn
        ~name:"ecr.create_repository"
        ~error_to_json:Ecr.CreateRepositoryResponse.error_to_json
        ~f:(fun () ->
        Ecr.create_repository
          ~cfg
          (Ecr.CreateRepositoryRequest.make ~repositoryName ()))
      >|= fun _v -> ()
    in
    let%bind () =
      dispatch_exn
        ~name:"ecr.describe_repositories"
        ~error_to_json:Ecr.DescribeRepositoriesResponse.error_to_json
        ~f:(fun () ->
        Ecr.describe_repositories
          ~cfg
          (Ecr.DescribeRepositoriesRequest.make ()))
      >>= fun v ->
      Option.value_map
        v.Ecr.DescribeRepositoriesResponse.repositories
        ~default:(return ())
        ~f:(fun repos ->
        let foreach repo =
          Option.value_map
            repo.Ecr.Repository.repositoryName
            ~default:(return (Ok ()))
            ~f:(fun repositoryName ->
            pr (repositoryName :> string);
            dispatch_exn
              ~name:"ecr.list_images"
              ~error_to_json:Ecr.ListImagesResponse.error_to_json
              ~f:(fun () ->
              Ecr.list_images
                ~cfg
                (Ecr.ListImagesRequest.make ~repositoryName ()))
            >|= fun images ->
            let imageIds =
              Option.value
                (images.Ecr.ListImagesResponse.imageIds
                  :> Ecr.ImageIdentifier.t list option)
                ~default:[]
            in
            Ok
              (List.iter imageIds ~f:(fun id ->
                 Option.iter id.Ecr.ImageIdentifier.imageTag ~f:(fun id ->
                   pr ("\t" ^ id)))))
        in
        Lwt_list.map_s foreach repos >|= Result.all >|= ignore)
    in
    let%bind () =
      dispatch_exn
        ~name:"ecr.delete_repository"
        ~error_to_json:Ecr.DeleteRepositoryResponse.error_to_json
        ~f:(fun () ->
        Ecr.delete_repository
          ~cfg
          (Ecr.DeleteRepositoryRequest.make ~repositoryName ()))
      >|= fun _v -> ()
    in
    return ()
  in
  let%bind () =
    pr "=== S3 ===";
    let%bind () =
      dispatch_exn
        ~name:"s3.list_buckets"
        ~error_to_json:S3.ListBucketsOutput.error_to_json
        ~f:(fun () -> S3.list_buckets ~cfg ())
      >|= fun _ -> ()
    in
    dispatch_exn
      ~name:"s3.list_objects"
      ~error_to_json:S3.ListObjectsOutput.error_to_json
      ~f:(fun () ->
      S3.list_objects ~cfg (S3.ListObjectsRequest.make ~bucket ()))
    >|= fun v ->
    Option.iter v.S3.ListObjectsOutput.name ~f:pr;
    let contents = Option.value ~default:[] v.S3.ListObjectsOutput.contents in
    List.iter contents ~f:(fun oo ->
      Option.iter (oo.S3.Object.key :> string option) ~f:pr)
  in
  return ()
;;

let default_chunk_size = 10 * 1024 * 1024

let slice ~file_size ~chunk_size i =
  i * chunk_size, min (chunk_size * (i + 1)) file_size - 1
;;

let read_slice ~start ~end_ fn =
  Lwt_preemptive.detach
    (fun () ->
      let len = end_ - start + 1 in
      let buf = Bytes.create len in
      In_channel.with_file fn ~f:(fun ic ->
        In_channel.seek ic (Int64.of_int start);
        match In_channel.really_input ic ~buf ~pos:0 ~len with
        | None -> assert false
        | Some () -> ());
      buf |> Bytes.to_string)
    ()
;;

let multipart_main ~sso bucket key file () =
  let%bind cfg =
    match sso with
    | true -> Awso_sso_lwt.Util.Cfg.get_exn ()
    | false -> Cfg.get_exn ()
  in
  Lwt_unix.stat file
  >>= fun { st_size = file_size; _ } ->
  let nb_parts = min ((file_size / default_chunk_size) + 1) 10000 in
  let chunk_size =
    int_of_float (Float.round ~dir:`Up (float file_size /. float nb_parts))
  in
  let%bind uploadId =
    dispatch_exn
      ~name:"s3.create_multipart"
      ~error_to_json:S3.CreateMultipartUploadOutput.error_to_json
      ~f:(fun () ->
      S3.create_multipart_upload
        ~cfg
        (S3.CreateMultipartUploadRequest.make
           ~bucket
           ~key:(S3.ObjectKey.make key)
           ()))
    >|= function
    | { S3.CreateMultipartUploadOutput.uploadId; _ } ->
      Option.value_exn ~message:"no uploadId" uploadId
  in
  let upload_part i =
    let start, end_ = slice ~file_size ~chunk_size i in
    let%bind part = read_slice ~start ~end_ file in
    dispatch_exn
      ~name:"s3.upload_part_request"
      ~error_to_json:S3.UploadPartOutput.error_to_json
      ~f:(fun () ->
      S3.upload_part
        ~cfg
        (S3.UploadPartRequest.make
           ~bucket
           ~uploadId
           ~partNumber:(i + 1)
           ~body:(S3.Body.of_string part)
           ~contentLength:(part |> String.length |> Int64.of_int)
           ~key
           ~contentMD5:(Awso.Client.content_md5 part)
           ()))
    >|= fun uploadPartResp ->
    let eTag = Option.value_exn uploadPartResp.S3.UploadPartOutput.eTag in
    printf "%d: eTag = %s\n%!" i eTag;
    S3.CompletedPart.make ~eTag ~partNumber:(i + 1) ()
  in
  Lwt_list.map_s upload_part (List.init nb_parts ~f:Fn.id)
  >>= fun upload_threads ->
  Lwt_list.fold_left_s (fun accu x -> return (x :: accu)) [] upload_threads
  >>= fun rev_etags ->
  dispatch_exn
    ~name:"s3.completed_multipart_upload_request"
    ~error_to_json:S3.CompleteMultipartUploadOutput.error_to_json
    ~f:(fun () ->
    let req =
      S3.CompleteMultipartUploadRequest.make
        ~multipartUpload:
          (S3.CompletedMultipartUpload.make ~parts:(List.rev rev_etags) ())
        ~bucket
        ~key
        ~uploadId
        ()
    in
    S3.complete_multipart_upload ~cfg req)
  >|= fun _ -> ()
;;

module Param = struct
  let bucket = Command.Param.(anon ("bucket" %: string))
  let key = Command.Param.(anon ("key" %: string))
  let file = Command.Param.(anon ("file" %: Filename_unix.arg_type))
end

let suite_command =
  let open Command.Let_syntax in
  Command.basic
    ~summary:"Test script"
    [%map_open
      let bucket = Param.bucket in
      fun () -> Lwt_main.run (suite_main ~sso:false bucket ())]
;;

let sso_suite_command =
  let open Command.Let_syntax in
  Command.basic
    ~summary:"Test script"
    [%map_open
      let bucket = Param.bucket in
      fun () -> Lwt_main.run (suite_main ~sso:true bucket ())]
;;

let multipart_command =
  let open Command.Let_syntax in
  Command.basic
    ~summary:"Multipart upload test"
    [%map_open
      let bucket = Param.bucket
      and key = Param.key
      and file = Param.file in
      fun () -> Lwt_main.run (multipart_main ~sso:false bucket key file ())]
;;

let sso_multipart_command =
  let open Command.Let_syntax in
  Command.basic
    ~summary:"Multipart upload test (but with Sso auth)"
    [%map_open
      let bucket = Param.bucket
      and key = Param.key
      and file = Param.file in
      fun () -> Lwt_main.run (multipart_main ~sso:true bucket key file ())]
;;

let () =
  Command.group
    ~summary:"Awso test app"
    [ "test-suite", suite_command
    ; "sso-test-suite", sso_suite_command
    ; "multipart-test", multipart_command
    ; "sso-multipart-test", sso_multipart_command
    ]
  |> Command_unix.run
;;
