(* Fetch a single S3 object using awso-sync. No Async, no Lwt — direct
   blocking call. Usage:

     dune exec ./s3_sync_get.exe -- <bucket> <key> <output-file>

   Credentials are picked up from the usual ~/.aws/{config,credentials} +
   environment chain — see Awso.Cfg. *)

module S3 = Awso_s3_sync

let usage_and_die () =
  prerr_endline "usage: s3_sync_get <bucket> <key> <output-file>";
  exit 2
;;

let () =
  let bucket, key, output_file =
    match Sys.argv with
    | [| _; b; k; o |] -> b, k, o
    | _ -> usage_and_die ()
  in
  let request = S3.GetObjectRequest.make ~bucket ~key () in
  match S3.get_object request with
  | Error err ->
    let s = err |> S3.GetObjectOutput.error_to_json |> Yojson.Safe.to_string in
    prerr_endline ("S3 get_object failed: " ^ s);
    exit 1
  | Ok response ->
    let body =
      match response.body with
      | Some b -> b
      | None ->
        prerr_endline "S3 response had no body";
        exit 1
    in
    let oc = open_out output_file in
    output_string oc body;
    close_out oc;
    let len = String.length body in
    Printf.eprintf "wrote %d bytes to %s\n" len output_file
;;
