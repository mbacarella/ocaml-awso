(* List the domains registered in this AWS account, using the synchronous
   backend. Route53Domains is only deployed in us-east-1, so we force that
   region regardless of the caller's default. *)

module RD = Awso_route53domains_sync

let () =
  let cfg = Awso_sync.Cfg.get_exn ~region:(Awso.Region.of_string "us-east-1") () in
  match RD.list_domains ~cfg (RD.ListDomainsRequest.make ()) with
  | Error err ->
    let s = err |> RD.ListDomainsResponse.error_to_json |> Yojson.Safe.to_string in
    prerr_endline ("list_domains failed: " ^ s);
    exit 1
  | Ok response ->
    let domains = Option.value response.domains ~default:[] in
    Printf.printf "%d registered domain(s):\n" (List.length domains);
    List.iter
      (fun (d : RD.DomainSummary.t) ->
         Printf.printf "  %s\n" (Option.value d.domainName ~default:"<none>"))
      domains
;;
