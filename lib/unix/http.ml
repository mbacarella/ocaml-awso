open! Import

module Io = struct
  let return x = x
  let bind x f = f x
  let map x f = f x

  let call ?endpoint_url:_ ~cfg:_ ~service:_ _meth _request _uri =
    failwith "awso_unix.Http.Io.call: not implemented (use awso_async or awso_lwt)"
  ;;

  let resolve_cfg = function
    | Some cfg -> cfg
    | None -> failwith "awso_unix.Http.Io.resolve_cfg: cfg is required"
  ;;
end
