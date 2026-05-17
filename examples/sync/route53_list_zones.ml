(* List the Route53 hosted zones in this AWS account, using the synchronous
   backend. Route53 is a "global" service; the API endpoint is region-agnostic
   so we just use whatever Cfg.get picks up by default. *)

module R53 = Awso_route53_sync

let () =
  match R53.list_hosted_zones (R53.ListHostedZonesRequest.make ()) with
  | Error err ->
    let s = err |> R53.ListHostedZonesResponse.error_to_json |> Yojson.Safe.to_string in
    prerr_endline ("list_hosted_zones failed: " ^ s);
    exit 1
  | Ok response ->
    let zones = Option.value response.hostedZones ~default:[] in
    let str x = Option.value x ~default:"?" in
    Printf.printf "%d hosted zone(s):\n" (List.length zones);
    List.iter
      (fun (z : R53.HostedZone.t) -> Printf.printf "  %s  (%s)\n" (str z.name) (str z.id))
      zones
;;
