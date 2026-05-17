module Cfg : sig
  (** SSO-aware version of Cfg. Internally calls Awso_lwt.Cfg.get and may
      dispatch to Sso.get_role_credentials. The returned Cfg.t works with
      all other AWS calls. *)

  val get
    :  ?profile:string
    -> ?region:Awso.Region.t
    -> ?output:string
    -> unit
    -> (Awso.Cfg.t, exn) result Lwt.t

  val get_exn
    :  ?profile:string
    -> ?region:Awso.Region.t
    -> ?output:string
    -> unit
    -> Awso.Cfg.t Lwt.t
end
