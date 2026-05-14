open! Import

module Io : sig
  include
    Awso.Http.Io.S with type 'a s := 'a Deferred.t and type 'a stream := 'a Pipe.Reader.t

  val call
    :  ?endpoint_url:string
    -> cfg:Awso.Cfg.t
    -> service:Awso.Service.t
    -> Awso.Http.Meth.t
    -> Awso.Http.Request.t
    -> Uri.t
    -> ((t Awso.Http.Response.t, Awso.Http.Io.Error.call) result, t) Awso.Http.Monad.app
end

include
  Awso.Http.S
    with module Deferred := Deferred
    with module Pipe := Pipe
    with type Response.t = Cohttp.Response.t
    with type Body.t = Cohttp.Body.t
