open! Import

type t = string

let all =
  [ "af-south-1"
  ; "ap-east-1"
  ; "ap-east-2"
  ; "ap-northeast-1"
  ; "ap-northeast-2"
  ; "ap-northeast-3"
  ; "ap-south-1"
  ; "ap-south-2"
  ; "ap-southeast-1"
  ; "ap-southeast-2"
  ; "ap-southeast-3"
  ; "ap-southeast-4"
  ; "ap-southeast-5"
  ; "ap-southeast-6"
  ; "ap-southeast-7"
  ; "ca-central-1"
  ; "ca-west-1"
  ; "cn-north-1"
  ; "cn-northwest-1"
  ; "eu-central-1"
  ; "eu-central-2"
  ; "eu-isoe-west-1"
  ; "eu-north-1"
  ; "eu-south-1"
  ; "eu-south-2"
  ; "eu-west-1"
  ; "eu-west-2"
  ; "eu-west-3"
  ; "eusc-de-east-1"
  ; "il-central-1"
  ; "me-central-1"
  ; "me-south-1"
  ; "mx-central-1"
  ; "sa-east-1"
  ; "us-east-1"
  ; "us-east-2"
  ; "us-gov-east-1"
  ; "us-gov-west-1"
  ; "us-iso-east-1"
  ; "us-iso-west-1"
  ; "us-isob-east-1"
  ; "us-isob-west-1"
  ; "us-isof-east-1"
  ; "us-isof-south-1"
  ; "us-west-1"
  ; "us-west-2"
  ]
;;

let of_string (x : string) =
  if List.mem all x ~equal:String.equal
  then x
  else failwith (sprintf "invalid region: %s" x)
;;

let to_string (x : t) = x
let compare = String.compare
let yojson_of_t (x : t) = `String x

let t_of_yojson = function
  | `String s -> of_string s
  | _ -> failwith "expected string"
;;

(* Asia Pacific *)
let ap_northeast_1 = "ap-northeast-1"
let ap_northeast_2 = "ap-northeast-2"
let ap_northeast_3 = "ap-northeast-3"
let ap_south_1 = "ap-south-1"
let ap_southeast_1 = "ap-southeast-1"
let ap_southeast_2 = "ap-southeast-2"

(* Canada *)
let ca_central_1 = "ca-central-1"

(* China *)
let cn_north_1 = "cn-north-1"
let cn_northwest_1 = "cn-northwest-1"

(* EU *)
let eu_central_1 = "eu-central-1"
let eu_north_1 = "eu-north-1"
let eu_west_1 = "eu-west-1"
let eu_west_2 = "eu-west-2"
let eu_west_3 = "eu-west-3"

(* South America *)
let sa_east_1 = "sa-east-1"

(* US *)
let us_east_1 = "us-east-1"
let us_east_2 = "us-east-2"
let us_west_1 = "us-west-1"
let us_west_2 = "us-west-2"

(* AWS GovCloud *)
let us_gov_east_1 = "us-gov-east-1"
let us_gov_west_1 = "us-gov-west-1"

let test_error call x =
  match call x with
  | _ -> failwith "unexpected success"
  | exception e -> Stdlib.print_endline (Stdlib.Printexc.to_string e)
;;

let%expect_test "of_string" =
  let test x = printf "%s" (of_string x) in
  test_error of_string "";
  [%expect {|Failure("invalid region: ")|}];
  test_error of_string "foo";
  [%expect {|Failure("invalid region: foo")|}];
  test "eu-central-1";
  [%expect {| eu-central-1 |}]
;;

let%expect_test "to_string" =
  let test x = printf "%s" (to_string x) in
  test us_east_1;
  [%expect {|us-east-1|}]
;;
