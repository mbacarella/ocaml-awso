(* Find coffee shops near a city. Two step demo of geo-places API. *)

open Core
open Async
module Geo_places = Awso_geo_places_async

let fail_result ~name error_to_json e =
  failwithf "%s: %s" name (e |> error_to_json |> Yojson.Safe.to_string) ()
;;

let geocode_place cfg query =
  Geo_places.geocode
    ~cfg
    (Geo_places.GeocodeRequest.make ~queryText:query ~maxResults:1 ())
  >>| function
  | Error e -> fail_result ~name:"geocode" Geo_places.GeocodeResponse.error_to_json e
  | Ok { resultItems = Some (item :: _); _ } ->
    let title = Option.value item.title ~default:query in
    let pos =
      Option.value_exn item.position ~message:(sprintf "no position for %S" title)
    in
    title, pos
  | Ok _ -> failwithf "no geocode result for %S" query ()
;;

let search_coffee cfg ~bias_position =
  Geo_places.search_text
    ~cfg
    (Geo_places.SearchTextRequest.make
       ~queryText:"coffee"
       ~biasPosition:bias_position
       ~maxResults:10
       ())
  >>| function
  | Error e ->
    fail_result ~name:"search_text" Geo_places.SearchTextResponse.error_to_json e
  | Ok { resultItems; _ } -> Option.value resultItems ~default:[]
;;

let format_result (item : Geo_places.SearchTextResultItem.t) =
  let title = Option.value item.title ~default:"?" in
  let label =
    match item.address with
    | Some { label = Some lbl; _ } -> lbl
    | _ -> "(no address)"
  in
  let dist =
    match item.distance with
    | Some d -> sprintf "%Ld m" d
    | None -> "?"
  in
  sprintf "  %-40s  %8s  %s" title dist label
;;

let main place =
  let%bind cfg = Awso_async.Cfg.get_exn () in
  let%bind matched, pos = geocode_place cfg place in
  printf
    "Geocoded %S -> %s @ [%s]\n%!"
    place
    matched
    (String.concat ~sep:", " (List.map pos ~f:(sprintf "%.4f")));
  let%bind items = search_coffee cfg ~bias_position:pos in
  if List.is_empty items
  then printf "No coffee found near %s.\n" matched
  else (
    printf "%d coffee result(s) near %s:\n" (List.length items) matched;
    List.iter items ~f:(fun r -> print_endline (format_result r)));
  return ()
;;

let command =
  Command.async
    ~summary:
      "Find coffee shops near a place (city, address, landmark, etc.) via Amazon \
       Location Service."
    (let%map_open.Command place = anon ("PLACE" %: string) in
     fun () -> main place)
;;

let () = Command_unix.run command
