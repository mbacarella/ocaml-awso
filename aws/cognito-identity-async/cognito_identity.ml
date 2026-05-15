open! Values
open! Core
open! Async

let default_max_results = 20

let list_identity_pools cfg ?(max_results = default_max_results) ()
  : IdentityPoolShortDescription.t list Deferred.t
  =
  let maxResults = QueryLimit.make max_results in
  Io.list_identity_pools
    ~cfg
    (ListIdentityPoolsInput.make ~maxResults ())
  >>| function
  | Ok response -> Option.value response.identityPools ~default:[]
  | _ -> failwithf "list_identity_pools error" ()
;;

let identity_pools_to_json t = IdentityPoolsList.to_json t
let identity_pools_to_string t = t |> identity_pools_to_json |> Yojson.Safe.to_string
