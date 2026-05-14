open! Import

module Io : sig
  include Awso.Http.Io.S with type 'a s := 'a Lwt.t and type 'a stream := 'a Lwt_stream.t

  val call
    :  ?endpoint_url:string
    -> cfg:Awso.Cfg.t
    -> service:Awso.Service.t
    -> Awso.Http.Meth.t
    -> Awso.Http.Request.t
    -> Uri.t
    -> ((t Awso.Http.Response.t, Awso.Http.Io.Error.call) result, t) Awso.Http.Monad.app
end
