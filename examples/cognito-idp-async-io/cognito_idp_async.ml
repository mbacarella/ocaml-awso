open Core
open Awso_cognito_idp_async
open Awso_cognito_idp.Values

let failwithf fmt = Format.kasprintf failwith fmt

let pool_name =
  let open Command.Param in
  anon ("pool_name" %: string)
;;

module List_user_pools = struct
  let run () =
    let open Async.Deferred in
    Awso_async.Cfg.get_exn ()
    >>= fun cfg ->
    list_user_pools ~cfg (ListUserPoolsRequest.make ~maxResults:10 ())
    >>| function
    | Ok response ->
      response |> ListUserPoolsResponse.to_json |> Yojson.Safe.to_string |> print_endline
    | Error err ->
      failwithf
        "list_user_pools: %s"
        (err |> ListUserPoolsResponse.error_to_json |> Yojson.Safe.to_string)
        ()
  ;;

  let param =
    let open Command.Param in
    return run
  ;;

  let command = Async.Command.async ~summary:"List user pools" param
end

module Create_user_pool = struct
  let run poolName () =
    let open Async.Deferred in
    Awso_async.Cfg.get_exn ()
    >>= fun cfg ->
    create_user_pool ~cfg (CreateUserPoolRequest.make ~poolName ())
    >>| function
    | Ok response ->
      response |> CreateUserPoolResponse.to_json |> Yojson.Safe.to_string |> print_endline
    | Error err ->
      failwithf
        "create_user_pool: %s"
        (err |> CreateUserPoolResponse.error_to_json |> Yojson.Safe.to_string)
        ()
  ;;

  let param =
    let open Command.Param in
    return run <*> pool_name
  ;;

  let command = Async.Command.async ~summary:"Create a user pool" param
end

let command =
  Command.group
    ~summary:"Interact with the Cognito IDP API"
    [ "list-user-pools", List_user_pools.command
    ; "create-user-pool", Create_user_pool.command
    ]
;;

let () = Command_unix.run command
