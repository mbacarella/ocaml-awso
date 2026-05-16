open Core
open Async
open Awso_athena_async


let dispatch_exn ~name ~error_to_json ~f =
  match%bind f () with
  | Ok v -> return v
  | Error err ->
    failwithf "%s: %s" name (err |> error_to_json |> Yojson.Safe.to_string) ()
;;

module Query = struct
  type query_id_params =
    { execution_id : string
    ; next_token : string option
    }
  
  type athena_start =
    { result_configuration : ResultConfiguration.t
    ; query_execution_output : StartQueryExecutionOutput.t
    }
  
  type t =
    [ `Athena_execution_id of string
    | `Athena_start of athena_start
    | `Athena_execution of GetQueryExecutionOutput.t
    ]
  
  let of_id id : [< t ] = `Athena_execution_id id

  let submit ?idem_potency_token ?output_location ~query_string ~bucket cfg =
    let idem_potency_token =
      match idem_potency_token with
      | Some token -> token
      | None -> Uuid.create_random Random.State.default |> Uuid.to_string
    in
    let clientRequestToken = idem_potency_token |> IdempotencyToken.make in
    let result_configuration =
      ResultConfiguration.make
        ~outputLocation:
          (Option.value
             ~default:(sprintf "s3://%s/athena-output/%s" bucket idem_potency_token)
             output_location)
        ()
    in
    dispatch_exn
      ~name:"athena.start_query_execution"
      ~error_to_json:StartQueryExecutionOutput.error_to_json
      ~f:(fun () ->
      start_query_execution
        ~cfg
        (StartQueryExecutionInput.make
           ~clientRequestToken
           ~queryString:(QueryString.make query_string)
           ?queryExecutionContext:None
           ~resultConfiguration:result_configuration
           ()))
    >>| fun query_execution_output ->
    `Ok (`Athena_start { result_configuration; query_execution_output })
  ;;

  let execution_id : [< t ] -> string option = function
    | `Athena_execution_id id -> Some id
    | `Athena_execution
        { GetQueryExecutionOutput.queryExecution =
            Some { QueryExecution.queryExecutionId; _ }
        } -> queryExecutionId
    | `Athena_start
        { result_configuration = _
        ; query_execution_output = { StartQueryExecutionOutput.queryExecutionId }
        } -> queryExecutionId
    | `Athena_execution { GetQueryExecutionOutput.queryExecution = None } -> None
  ;;

  let as_execution_id : [< t ] -> [ `Athena_execution_id of string ] option =
   fun t -> execution_id t |> Option.map ~f:(fun id -> `Athena_execution_id id)
 ;;

  let status : [< t ] -> QueryExecutionStatus.t option = function
    | `Athena_execution
        { GetQueryExecutionOutput.queryExecution =
            Some { QueryExecution.status; _ }
        } -> status
    | `Athena_start _ | `Athena_execution_id _ -> None
    | `Athena_execution { GetQueryExecutionOutput.queryExecution = None } -> None
  ;;

  let state t =
    status t
    |> Option.bind ~f:(function { QueryExecutionStatus.state; _ } -> state)
  ;;

  let is_state t s =
    Option.fold ~init:false (state t) ~f:(fun acc state -> acc || Poly.( = ) state s)
  ;;

  let succeeded (t : [< t ]) = is_state t QueryExecutionState.SUCCEEDED
  let canceled (t : [< t ]) = is_state t QueryExecutionState.CANCELLED
  let running (t : [< t ]) = is_state t QueryExecutionState.RUNNING

  let refresh cfg (t : [< t ])
    : [ `Ok of [< t > `Athena_execution ] | `Missing_execution_id ] Deferred.t
    =
    match execution_id t with
    | None -> return `Missing_execution_id
    | Some execution_id ->
      dispatch_exn
        ~name:"athena.get_query_execution"
        ~error_to_json:GetQueryExecutionOutput.error_to_json
        ~f:(fun () ->
        get_query_execution
          ~cfg
          (GetQueryExecutionInput.make ~queryExecutionId:execution_id ()))
      >>| fun x -> `Ok (`Athena_execution x)
  ;;

  let get_query_results_page ?next_token ~execution_id cfg =
    Log.Global.debug
      ?tags:None
      ?time:None
      "%s %s"
      (Option.value ~default:"none" next_token)
      execution_id;
    dispatch_exn
      ~name:"athena.get_query_results"
      ~error_to_json:GetQueryResultsOutput.error_to_json
      ~f:(fun () ->
      get_query_results
        ~cfg
        (GetQueryResultsInput.make
           ?nextToken:next_token
           ~queryExecutionId:execution_id
           ()))
    >>| fun x -> `Ok (`Athena_result x)
  ;;

  let results ?(close_on_exception = false) (cfg : Awso.Cfg.t) (t : [< t ]) =
    match execution_id t with
    | None -> return @@ `Missing_execution_id
    | Some execution_id -> (
      get_query_results_page cfg ?next_token:None ~execution_id
      >>= (function
            | `Ok
                (`Athena_result
                  { GetQueryResultsOutput.resultSet
                  ; nextToken = next_token
                  ; updateCount = _
                  }) -> (
              match resultSet with
              | None
              | Some { ResultSet.rows = _; resultSetMetadata = None }
              | Some
                  { ResultSet.rows = _
                  ; resultSetMetadata =
                      Some { ResultSetMetadata.columnInfo = None }
                  } ->
                return (`Missing_result_set_metadata { execution_id; next_token = None })
              | Some
                  { ResultSet.rows
                  ; resultSetMetadata =
                      Some { ResultSetMetadata.columnInfo = Some column_infos }
                  } ->
                let rows = Option.value ~default:[] rows in
                return (`Ok (rows, next_token, column_infos))))
      >>= function
      | `Missing_result_set_metadata _ as e -> return e
      | `Ok (rows, next_token, result_set_metadata) ->
        let pipe =
          Pipe.create_reader ~close_on_exception (fun writer ->
            let rec folder next_token =
              match next_token with
              | None ->
                Log.Global.debug
                  ?tags:None
                  ?time:None
                  "Query.results.create_reader: %s %s"
                  (Option.value ~default:"none" next_token)
                  execution_id;
                return ()
              | Some (next_token : string) -> (
                get_query_results_page cfg ~next_token ~execution_id
                >>= function
                | `Ok
                    (`Athena_result
                      { GetQueryResultsOutput.resultSet
                      ; nextToken = next_token
                      ; updateCount = _
                      }) -> (
                  match resultSet with
                  | None -> return ()
                  | Some { ResultSet.rows = rows_opt; resultSetMetadata = _ } ->
                    let rows = Option.value ~default:[] rows_opt in
                    Deferred.List.iter ~how:`Sequential rows ~f:(Pipe.write writer)
                    >>= fun () -> folder next_token))
            in
            Deferred.List.iter ~how:`Sequential rows ~f:(Pipe.write writer)
            >>= fun () -> folder next_token)
        in
        return (`Ok (result_set_metadata, pipe)))
  ;;

  let output_location (t : [< t ]) =
    match t with
    | `Athena_execution_id _ -> None
    | `Athena_execution { GetQueryExecutionOutput.queryExecution = None } -> None
    | `Athena_execution
        { GetQueryExecutionOutput.queryExecution =
            Some
              { queryExecutionId = _
              ; query = _
              ; resultConfiguration = None
              ; queryExecutionContext = _
              ; status = _
              ; statistics = _
              ; statementType = _
              ; workGroup = _
              ; engineVersion = _
              }
        } -> None
    | `Athena_execution
        { GetQueryExecutionOutput.queryExecution =
            Some
              { queryExecutionId = _
              ; query = _
              ; resultConfiguration =
                  Some
                    { outputLocation
                    ; encryptionConfiguration = _
                    ; expectedBucketOwner = _
                    ; aclConfiguration = _
                    }
              ; queryExecutionContext = _
              ; status = _
              ; statistics = _
              ; statementType = _
              ; workGroup = _
              ; engineVersion = _
              }
        } -> outputLocation
    | `Athena_start
        { query_execution_output = _
        ; result_configuration =
            { outputLocation
            ; encryptionConfiguration = _
            ; expectedBucketOwner = _
            ; aclConfiguration = _
            }
        } -> outputLocation
  ;;

  let ls ?max_results ?(close_on_exception = true) cfg
    : [< t > `Athena_execution_id ] Pipe.Reader.t
    =
    let rec paginator ?next_token writer =
      dispatch_exn
        ~name:"athena.list_query_executions"
        ~error_to_json:ListQueryExecutionsOutput.error_to_json
        ~f:(fun () ->
        list_query_executions
          ~cfg
          (ListQueryExecutionsInput.make
             ?maxResults:(Option.map max_results ~f:MaxQueryExecutionsCount.make)
             ?nextToken:next_token
             ()))
      >>= fun { ListQueryExecutionsOutput.nextToken = next_token
              ; queryExecutionIds
              } ->
      let ids =
        Option.value ~default:[] queryExecutionIds
        |> List.map ~f:(fun s -> `Athena_execution_id s)
      in
      Deferred.List.iter ids ~how:`Sequential ~f:(Pipe.write writer)
      >>= fun () ->
      match next_token with
      | None -> return ()
      | Some next_token -> paginator ~next_token writer
    in
    let f : [< t > `Athena_execution_id ] Pipe.Writer.t -> unit Deferred.t =
      paginator ?next_token:None
    in
    Pipe.create_reader ~close_on_exception f
  ;;
end

let ls_main () =
  let%bind cfg = Awso_async.Cfg.get_exn () in
  let pipe = Query.ls ~max_results:10 cfg in
  let%bind lst = Pipe.to_list pipe in
  printf "athena query results:\n";
  List.iter lst ~f:(function `Athena_execution_id x -> printf "execution_id: %s\n" x);
  return ()
;;

let () =
  let group =
    Command.group
      ~summary:"athena demo"
      [ ( "ls"
        , Command.async
            ~summary:"list queries"
            (Command.Param.return (fun () -> ls_main ())) )
      ]
  in
  Command_unix.run group
;;
