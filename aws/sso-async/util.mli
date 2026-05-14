module Cfg : sig
  (* This is an SSO credentials aware version of Cfg. It internally calls to
     Awso.Cfg.get () and may dispatch to Sso.get_role_credentials.
     The returned Cfg.t can be used with all other AWS calls. *)

  val get
    :  ?profile:string
    -> ?region:Awso.Region.t
    -> ?output:string
    -> unit
    -> (Awso.Cfg.t, exn) Result.t Deferred.t

  val get_exn
    :  ?profile:string
    -> ?region:Awso.Region.t
    -> ?output:string
    -> unit
    -> Awso.Cfg.t Deferred.t
end
