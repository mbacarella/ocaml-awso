open! Core
open! Async
open! Import

module Io : Awso.Http.Io.S with type 'a t := 'a Deferred.t

include
  Awso.Http.S
    with module Deferred := Deferred
    with module Pipe := Pipe
    with type Response.t = Cohttp.Response.t
    with type Body.t = Cohttp.Body.t
