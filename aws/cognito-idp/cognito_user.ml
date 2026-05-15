open Ppx_yojson_conv_lib.Yojson_conv.Primitives
open! Awso.Import
module Stdlib = Stdlib

module Attribute = struct
  type raw_attribute =
    { name : string
    ; value : string option
    }
  [@@deriving yojson]

  type t =
    [ `Unknown of raw_attribute
    | `Custom of raw_attribute
    | `Gender of string
    | `Family_name of string
    | `Locale of string
    | `Middle_name of string option
    | `Nickname of string
    | `Profile of string option
    | `Website of string option
    | `Picture of string
    | `Email of string
    | `Name of string
    | `Updated_at of string
    | `Preferred_user_name of string option
    | `Given_name of string
    ]
  [@@deriving yojson]
end

type attribute = Attribute.t [@@deriving yojson]

type t =
  { username : string
  ; attributes : attribute list
  ; access_token : string
  }
[@@deriving yojson]

type msg = string

let required_attribute t ~name ~f =
  match List.find_map t.attributes ~f with
  | Some x -> Ok x
  | None -> Error (sprintf "%s attribute required but not present" name)
;;

let required_attribute_exn t ~name ~f =
  Result.ok_or_failwith (required_attribute t ~name ~f)
;;

let%expect_test "required_attribute" =
  let call ~attributes =
    let user = { username = ""; attributes; access_token = "" } in
    let name = "name" in
    let f = function
      | `Name n -> Some n
      | _ -> None
    in
    required_attribute user ~name ~f
  in
  let test ~attributes =
    match call ~attributes with
    | Ok s -> printf "Ok %s" s
    | Error s -> printf "Error %s" s
  in
  test ~attributes:[ `Name "foo" ];
  [%expect {|Ok foo|}];
  test ~attributes:[ `Email "foo" ];
  [%expect {|Error name attribute required but not present|}]
;;

let optional_attribute t ~f = List.find_map t.attributes ~f

let%expect_test "optional_attribute" =
  let test ~attributes =
    let user = { username = ""; attributes; access_token = "" } in
    let f = function
      | `Name n -> Some n
      | _ -> None
    in
    match optional_attribute user ~f with
    | Some s -> printf "Some %s" s
    | None -> printf "None"
  in
  test ~attributes:[ `Name "foo" ];
  [%expect {|Some foo|}];
  test ~attributes:[ `Email "foo" ];
  [%expect {|None|}]
;;

let email t =
  required_attribute t ~name:"email" ~f:(function
    | `Email e -> Some e
    | _ -> None)
;;

let email_exn t = Result.ok_or_failwith (email t)

let%expect_test "email" =
  let call ~attributes = email { username = ""; attributes; access_token = "" } in
  let test ~attributes =
    match call ~attributes with
    | Ok s -> printf "Ok %s" s
    | Error s -> printf "Error %s" s
  in
  test ~attributes:[ `Email "foo" ];
  [%expect {|Ok foo|}];
  test ~attributes:[ `Name "foo" ];
  [%expect {|Error email attribute required but not present|}]
;;

let preferred_name t =
  optional_attribute t ~f:(function
    | `Preferred_user_name e -> Some e
    | _ -> None)
;;

let%expect_test "preferred_name" =
  let test ~attributes =
    match preferred_name { username = ""; attributes; access_token = "" } with
    | Some (Some s) -> printf "Some (Some %s)" s
    | Some None -> printf "Some None"
    | None -> printf "None"
  in
  test ~attributes:[ `Preferred_user_name (Some "foo") ];
  [%expect {|Some (Some foo)|}];
  test ~attributes:[ `Preferred_user_name None ];
  [%expect {|Some None|}];
  test ~attributes:[ `Email "foo" ];
  [%expect {|None|}]
;;

let family_name t =
  required_attribute t ~name:"family_name" ~f:(function
    | `Family_name e -> Some e
    | _ -> None)
;;

let family_name_exn t = Result.ok_or_failwith (family_name t)

let%expect_test "family_name" =
  let call ~attributes = family_name { username = ""; attributes; access_token = "" } in
  let test ~attributes =
    match call ~attributes with
    | Ok s -> printf "Ok %s" s
    | Error s -> printf "Error %s" s
  in
  test ~attributes:[ `Family_name "foo" ];
  [%expect {|Ok foo|}];
  test ~attributes:[ `Name "foo" ];
  [%expect {|Error family_name attribute required but not present|}]
;;

let name t =
  optional_attribute t ~f:(function
    | `Name e -> Some e
    | _ -> None)
;;

let%expect_test "name" =
  let test ~attributes =
    match name { username = ""; attributes; access_token = "" } with
    | Some s -> printf "Some %s" s
    | None -> printf "None"
  in
  test ~attributes:[ `Name "foo" ];
  [%expect {|Some foo|}];
  test ~attributes:[ `Email "foo" ];
  [%expect {|None|}]
;;

module Exn = struct
  let required_attribute = required_attribute_exn
  let email = email_exn
  let family_name = family_name_exn
end
