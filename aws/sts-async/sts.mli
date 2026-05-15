open! Core
open! Async

module Statement : sig
  type effect_ =
    | Accept
    | Deny
  [@@deriving yojson]

  type action = string list [@@deriving yojson]
  type resource = string list [@@deriving yojson]

  val effect_to_string : effect_ -> string

  type t =
    { sid : string
    ; effect_ : effect_
    ; action : action
    ; resource : resource
    }
  [@@deriving yojson]

  val create
    :  ?effect_:effect_
    -> ?sid:string
    -> action:action
    -> resource:resource
    -> unit
    -> t

  val to_json : t -> Yojson.Safe.t
end

module Policy : sig
  type t =
    { version : string
    ; statement : Statement.t list
    }
  [@@deriving yojson]

  val to_json : t -> Awso.Json.t
  val create : ?version:string -> Statement.t list -> t
end

val assume_role
  :  ?policy:Policy.t
  -> ?retry_delay:Time_float_unix.Span.t
  -> ?retry_cnt:int
  -> ?duration_sec:int
  -> session_name:string
  -> role:string
  -> Awso.Cfg.t
  -> Values.AssumeRoleResponse.t Deferred.t

val assume_role_with_saml
  :  ?policy:Policy.t
  -> ?retry_delay:Time_float_unix.Span.t
  -> ?retry_cnt:int
  -> ?duration_sec:int
  -> principal_arn:string
  -> saml_assertion:string
  -> role:string
  -> Awso.Cfg.t
  -> Values.AssumeRoleWithSAMLResponse.t Deferred.t
