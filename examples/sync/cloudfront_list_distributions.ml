(* List CloudFront distributions using the synchronous backend.
   CloudFront is a global service; the API endpoint is region-agnostic. *)

module CF = Awso_cloudfront_sync

let () =
  match CF.list_distributions (CF.ListDistributionsRequest.make ()) with
  | Error err ->
    let s =
      err |> CF.ListDistributionsResult.error_to_json |> Yojson.Safe.to_string
    in
    prerr_endline ("list_distributions failed: " ^ s);
    exit 1
  | Ok response ->
    let dl =
      match response.distributionList with
      | Some dl -> dl
      | None ->
        prerr_endline "no DistributionList in response";
        exit 1
    in
    let items = Option.value dl.items ~default:[] in
    Printf.printf "%d distribution(s):\n" (List.length items);
    List.iter
      (fun (d : CF.DistributionSummary.t) ->
         Printf.printf
           "  %s  %s  [%s]\n"
           (d.id :> string)
           (d.domainName :> string)
           (d.status :> string))
      items
;;
