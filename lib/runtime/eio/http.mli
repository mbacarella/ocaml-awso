(** Eio HTTP backend, plugged in by the codegen-emitted per-service [io.ml].
    Eio is direct-style, so ['a t = 'a] and the monad ops are identity. *)

module Io : sig
  type 'a t = 'a

  val return : 'a -> 'a
  val bind : 'a -> ('a -> 'b) -> 'b
  val map : 'a -> ('a -> 'b) -> 'b

  val call
    :  ?endpoint_url:string
    -> cfg:Cfg.t
    -> service:Awso.Service.t
    -> Awso.Http.Meth.t
    -> Awso.Http.Request.t
    -> Uri.t
    -> Awso.Http.Response.t

  (** Unlike async/lwt where this can fall back to reading the AWS config files
      on its own, the eio backend needs [env] to build a [Cfg.t] — so users must
      pass [~cfg] explicitly. This function raises on [None]. *)
  val resolve_cfg : Cfg.t option -> Cfg.t
end
