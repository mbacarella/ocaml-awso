open! Import

module Io = struct
  include Awso.Http.Monad.Make (struct
    type +'a t = 'a
  end)

  let monad = { Awso.Http.Monad.bind = (fun x f -> f (prj x)); return = (fun x -> inj x) }
  let make_stream stream () = inj (stream ())
  let make_http http meth request uri = inj (http meth request uri)
end
