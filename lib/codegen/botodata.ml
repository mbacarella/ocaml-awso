(** Boto specification for Amazon services

    Boto library includes a
    {{:https://github.com/boto/botocore/tree/develop/botocore/data} description}
    of Amazon services in JSON format. This module provides types to represent
    the contents of the specification, which includes three main parts: -
    service metadata (constants) - operations (along with their signature) -
    input and output types for operations

    The exact way a specification should be interpreted to provide an
    implementation depends on the {! protocol} specified in the {! metadata} of
    the service.

    Input/output types for operations are specified as a composition of {!
    shape}s, where a shape is basically a standard programming type with some
    optional additional constraints (for instance, integer with bounds).
*)

open! Import

module Int64 = struct
  type t = int64
end

type checksumFormat =
  [ `md5
  | `sha256
  ]

type timestampFormat =
  [ `unixTimestamp
  | `rfc822
  | `iso8601
  ]

type protocol =
  [ `query
  | `json
  | `rest_json
  | `rest_xml
  | `ec2
  ]

type location =
  [ `header
  | `headers
  | `querystring
  | `uri
  | `statusCode
  ]

type metadata =
  { apiVersion : string
  ; checksumFormat : checksumFormat option
  ; endpointPrefix : string
  ; globalEndpoint : Uri_json.t option
  ; serviceAbbreviation : string option
  ; serviceFullName : string
  ; serviceId : string option
  ; signatureVersion : string
  ; timestampFormat : timestampFormat option
  ; protocol : protocol
  ; jsonVersion : string option
  ; targetPrefix : Uri_json.t option
  ; signingName : string option
  ; xmlNamespace : Uri_json.t option
  ; uid : string option
  }

let empty_metadata_for_tests =
  { apiVersion = ""
  ; checksumFormat = None
  ; endpointPrefix = ""
  ; globalEndpoint = None
  ; serviceAbbreviation = None
  ; serviceFullName = ""
  ; serviceId = None
  ; signatureVersion = ""
  ; timestampFormat = None
  ; protocol = `rest_json
  ; jsonVersion = None
  ; targetPrefix = None
  ; signingName = None
  ; xmlNamespace = None
  ; uid = None
  }
;;

type http_method =
  [ `GET
  | `POST
  | `PUT
  | `DELETE
  | `HEAD
  | `PATCH
  ]

let http_method_of_string = function
  | "DELETE" -> Ok `DELETE
  | "GET" -> Ok `GET
  | "HEAD" -> Ok `HEAD
  | "PATCH" -> Ok `PATCH
  | "POST" -> Ok `POST
  | "PUT" -> Ok `PUT
  | s -> Error (sprintf "Unknown HTTP method %s" s)
;;

type requestUri_token =
  [ `Slash
  | `String of string
  | `Variable of string * bool
  | `Ampersand
  | `Qmark
  | `Equal
  ]

type requestUri = requestUri_token list

type http =
  { method_ : http_method
  ; requestUri : requestUri
  ; responseCode : int option
  }

type xmlNamespace =
  { uri : Uri_json.t
  ; prefix : string option
  }

type httpChecksum =
  { requestValidationModeMember : string option
  ; requestAlgorithmMember : string option
  ; requestChecksumRequired : bool option
  ; responseAlgorithms : string list option
  }

type operation_input =
  { shape : string
  ; documentation : string option
  ; deprecated : bool option
  ; xmlNamespace : xmlNamespace option
  ; locationName : string option
  }

type operation_output =
  { shape : string
  ; documentation : string option
  ; deprecated : bool option
  ; locationName : string option
  ; resultWrapper : string option
  ; wrapper : bool option
  ; xmlOrder : string list option
  }

type error =
  { code : string option
  ; httpStatusCode : int
  ; senderFault : bool option
  }

type operation_error =
  { shape : string
  ; documentation : string option
  ; exception_ : bool option
  ; fault : bool option
  ; error : error option
  ; xmlOrder : string list option
  }

type operation_endpoint = { hostPrefix : string }
type operation_endpointdiscovery = { required : bool option }

type operation =
  { name : string
  ; http : http
  ; input : operation_input option
  ; output : operation_output option
  ; errors : operation_error list option
  ; documentation : string option
  ; documentationUrl : Uri_json.t option
  ; alias : string option
  ; deprecated : bool option
  ; deprecatedMessage : string option
  ; authtype : string option
  ; idempotent : bool option
  ; httpChecksum : httpChecksum option
  ; endpoint : operation_endpoint option
  ; endpointdiscovery : operation_endpointdiscovery option
  }

type shape_member =
  { shape : string
  ; deprecated : bool option
  ; deprecatedMessage : string option
  ; location : location option
  ; locationName : string option
  ; documentation : string option
  ; xmlNamespace : xmlNamespace option
  ; streaming : bool option
  ; xmlAttribute : bool option
  ; queryName : string option
  ; box : bool option
  ; flattened : bool option
  ; idempotencyToken : bool option
  ; eventpayload : bool option
  ; hostLabel : bool option
  ; jsonvalue : bool option
  }

type retryable = { throttling : bool }

type structure_shape =
  { required : string list option
  ; members : (string * shape_member) list
  ; error : error option
  ; exception_ : bool option
  ; fault : bool option
  ; documentation : string option
  ; document : bool option
  ; payload : string option
  ; xmlNamespace : xmlNamespace option
  ; wrapper : bool option
  ; deprecated : bool option
  ; deprecatedMessage : string option
  ; sensitive : bool option
  ; xmlOrder : string list option
  ; locationName : string option
  ; event : bool option
  ; eventstream : bool option
  ; retryable : retryable option
  ; union : bool option
  ; box : bool option
  }

let empty_structure_shape =
  { required = None
  ; members = []
  ; error = None
  ; exception_ = None
  ; fault = None
  ; documentation = None
  ; document = None
  ; payload = None
  ; xmlNamespace = None
  ; wrapper = None
  ; deprecated = None
  ; deprecatedMessage = None
  ; sensitive = None
  ; xmlOrder = None
  ; locationName = None
  ; event = None
  ; eventstream = None
  ; retryable = None
  ; union = None
  ; box = None
  }
;;

type map_shape =
  { key : string
  ; value : string
  ; min : int option
  ; max : int option
  ; flattened : bool option
  ; locationName : string option
  ; documentation : string option
  ; sensitive : bool option
  }

type string_shape =
  { pattern : string option
  ; min : int option
  ; max : int option
  ; sensitive : bool option
  ; documentation : string option
  ; deprecated : bool option
  ; deprecatedMessage : string option
  }

type list_shape =
  { member : shape_member
  ; min : int option
  ; max : int option
  ; documentation : string option
  ; flattened : bool option
  ; sensitive : bool option
  ; deprecated : bool option
  ; deprecatedMessage : string option
  }

type boolean_shape =
  { box : bool option
  ; documentation : string option
  }

type integer_shape =
  { box : bool option
  ; min : int option
  ; max : int option
  ; documentation : string option
  ; deprecated : bool option
  ; deprecatedMessage : string option
  }

type long_shape =
  { box : bool option
  ; min : Int64.t option
  ; max : Int64.t option
  ; documentation : string option
  }

type float_shape =
  { box : bool option
  ; min : float option
  ; max : float option
  ; documentation : string option
  }

type double_shape =
  { box : bool option
  ; min : float option
  ; max : float option
  ; documentation : string option
  }

type enum_shape =
  { cases : string list
  ; documentation : string option
  ; min : int option
  ; max : int option
  ; pattern : string option
  ; deprecated : bool option
  ; deprecatedMessage : string option
  ; sensitive : bool option
  }

type blob_shape =
  { streaming : bool option
  ; sensitive : bool option
  ; min : int option
  ; max : int option
  ; documentation : string option
  }

type timestamp_shape =
  { timestampFormat : timestampFormat option
  ; documentation : string option
  }

type shape =
  | Boolean_shape of boolean_shape
  | Long_shape of long_shape
  | Double_shape of double_shape
  | Float_shape of float_shape
  (* TODO why does this shape have no extra typing ? *)
  | Blob_shape of blob_shape
  | Integer_shape of integer_shape
  | String_shape of string_shape
  | List_shape of list_shape
  | Enum_shape of enum_shape
  | Structure_shape of structure_shape
  | Timestamp_shape of timestamp_shape
  | Map_shape of map_shape

let yojson_of_shape = function
  | Boolean_shape _ -> `String "Boolean_shape"
  | Long_shape _ -> `String "Long_shape"
  | Double_shape _ -> `String "Double_shape"
  | Float_shape _ -> `String "Float_shape"
  | Blob_shape _ -> `String "Blob_shape"
  | Integer_shape _ -> `String "Integer_shape"
  | String_shape _ -> `String "String_shape"
  | List_shape _ -> `String "List_shape"
  | Enum_shape _ -> `String "Enum_shape"
  | Structure_shape _ -> `String "Structure_shape"
  | Timestamp_shape _ -> `String "Timestamp_shape"
  | Map_shape _ -> `String "Map_shape"
;;

let request_id_shape =
  String_shape
    { pattern = Some "A-Za-z[0-9]"
    ; min = None
    ; max = None
    ; sensitive = None
    ; documentation = None
    ; deprecated = None
    ; deprecatedMessage = None
    }
;;

let response_metadata_shape =
  let members =
    [ ( "RequestId"
      , { shape = "RequestId"
        ; deprecated = None
        ; deprecatedMessage = None
        ; location = None
        ; locationName = None
        ; documentation = None
        ; xmlNamespace = None
        ; streaming = None
        ; xmlAttribute = None
        ; queryName = None
        ; box = None
        ; flattened = None
        ; idempotencyToken = None
        ; eventpayload = None
        ; hostLabel = None
        ; jsonvalue = None
        } )
    ]
  in
  Structure_shape { empty_structure_shape with members }
;;

type service =
  { metadata : metadata
  ; documentation : string option
  ; version : string option
  ; operations : operation list
  ; shapes : (string * shape) list
  }

type value =
  [ `Boolean of bool
  | `Long of Int64.t
  | `Double of float
  | `Float of float
  | `Blob of string
  | `Integer of int
  | `String of string
  | `List of value list
  | `Enum of string
  | `Structure of (string * value) list
  | `Timestamp of string
  | `Map of (value * value) list
  ]
