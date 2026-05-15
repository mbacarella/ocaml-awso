(* Core/Base compatibility shim.
   AWSO used to depend on Jane Street's Core/Base but we removed that dependency out of
   the non-Async parts to keep the build lightweight for general release.

   This module re-implements the subset of the Core API that we actually use,
   built on top of Stdlib. Existing code can keep using Core-style calls
   (e.g. List.map ~f:, String.concat ~sep:, etc.) without changes.

   You should not be calling these functions from the Jane/Async runtime or
   utilities as the real Jane versions are better optimized. *)

let sprintf = Printf.sprintf
let printf = Printf.printf
let eprintf = Printf.eprintf
let bprintf = Printf.bprintf
let failwithf fmt = Printf.ksprintf failwith fmt
let ksprintf = Printf.ksprintf
let ( ^/ ) = Filename.concat

(* Shadow polymorphic compare/equality with int-only versions,
   matching Jane Street Base/Core convention. *)
let ( = ) (a : int) (b : int) = a = b
let ( <> ) (a : int) (b : int) = a <> b
let ( < ) (a : int) (b : int) = a < b
let ( > ) (a : int) (b : int) = a > b
let ( <= ) (a : int) (b : int) = a <= b
let ( >= ) (a : int) (b : int) = a >= b
let compare (a : int) (b : int) = Stdlib.compare a b
let equal (a : int) (b : int) = a = b
let phys_equal (a : 'a) (b : 'a) = a == b

module Char = struct
  include Stdlib.Char

  let equal (a : char) (b : char) = Stdlib.( = ) a b
  let is_uppercase c = Stdlib.( >= ) c 'A' && Stdlib.( <= ) c 'Z'
  let is_lowercase c = Stdlib.( >= ) c 'a' && Stdlib.( <= ) c 'z'
end

module Fn = struct
  let id x = x
  let compose f g x = f (g x)
end

module List = struct
  include Stdlib.List

  let map l ~f = Stdlib.List.map f l
  let iter l ~f = Stdlib.List.iter f l
  let filter l ~f = Stdlib.List.filter f l
  let filter_map l ~f = Stdlib.List.filter_map f l
  let find l ~f = Stdlib.List.find_opt f l
  let find_map l ~f = Stdlib.List.find_map f l
  let for_all l ~f = Stdlib.List.for_all f l
  let concat_map l ~f = Stdlib.List.concat_map f l
  let mapi l ~f = Stdlib.List.mapi f l
  let fold l ~init ~f = Stdlib.List.fold_left f init l
  let fold_right l ~init ~f = Stdlib.List.fold_right f l init
  let fold_left l ~init ~f = Stdlib.List.fold_left f init l
  let stable_sort l ~compare = Stdlib.List.stable_sort compare l
  let sort l ~compare = Stdlib.List.sort compare l
  let mem l x ~equal = Stdlib.List.exists (equal x) l
  let dedup_and_sort ~compare l = Stdlib.List.sort_uniq compare l
  let filter_opt l = Stdlib.List.filter_map Fn.id l

  let is_empty = function
    | [] -> true
    | _ -> false
  ;;

  let hd_exn = function
    | x :: _ -> x
    | [] -> failwith "List.hd_exn: empty list"
  ;;

  let return x = [ x ]
  let partition_tf l ~f = Stdlib.List.partition f l

  let init n ~f =
    let rec aux acc i = if i < 0 then acc else aux (f i :: acc) (i - 1) in
    aux [] (n - 1)
  ;;

  let take l n =
    let rec aux acc n = function
      | [] -> Stdlib.List.rev acc
      | _ when n <= 0 -> Stdlib.List.rev acc
      | x :: rest -> aux (x :: acc) (n - 1) rest
    in
    aux [] n l
  ;;

  let nth_exn l n =
    match Stdlib.List.nth_opt l n with
    | Some x -> x
    | None -> failwith (sprintf "List.nth_exn: index %d out of bounds" n)
  ;;

  let chunks_of l ~length =
    let rec aux acc current current_len = function
      | [] -> (
        match current with
        | [] -> Stdlib.List.rev acc
        | _ -> Stdlib.List.rev (Stdlib.List.rev current :: acc))
      | x :: rest ->
        if current_len >= length
        then aux (Stdlib.List.rev current :: acc) [ x ] 1 rest
        else aux acc (x :: current) (current_len + 1) rest
    in
    aux [] [] 0 l
  ;;

  module Assoc = struct
    type ('k, 'v) t = ('k * 'v) list

    let find l key ~equal =
      let rec aux = function
        | [] -> None
        | (k, v) :: _ when equal k key -> Some v
        | _ :: rest -> aux rest
      in
      aux l
    ;;

    let find_exn l key ~equal =
      match find l key ~equal with
      | Some v -> v
      | None -> failwith "List.Assoc.find_exn: key not found"
    ;;
  end
end

module String = struct
  include Stdlib.String

  let equal = Stdlib.String.equal
  let concat ?(sep = "") l = Stdlib.String.concat sep l
  let map s ~f = Stdlib.String.map f s
  let capitalize = Stdlib.String.capitalize_ascii
  let uncapitalize = Stdlib.String.uncapitalize_ascii
  let lowercase = Stdlib.String.lowercase_ascii
  let is_prefix s ~prefix = Stdlib.String.starts_with ~prefix s
  let is_suffix s ~suffix = Stdlib.String.ends_with ~suffix s
  let of_char c = Stdlib.String.make 1 c

  let strip s =
    let len = Stdlib.String.length s in
    let is_ws c =
      Char.equal c ' ' || Char.equal c '\t' || Char.equal c '\n' || Char.equal c '\r'
    in
    let i = ref 0 in
    while !i < len && is_ws (Stdlib.String.get s !i) do
      incr i
    done;
    let j = ref (len - 1) in
    while !j >= !i && is_ws (Stdlib.String.get s !j) do
      decr j
    done;
    if !i > !j then "" else Stdlib.String.sub s !i (!j - !i + 1)
  ;;

  let lsplit2 s ~on =
    match Stdlib.String.index_opt s on with
    | None -> None
    | Some i ->
      Some
        ( Stdlib.String.sub s 0 i
        , Stdlib.String.sub s (i + 1) (Stdlib.String.length s - i - 1) )
  ;;

  let chop_suffix_exn s ~suffix =
    if Stdlib.String.ends_with ~suffix s
    then Stdlib.String.sub s 0 (Stdlib.String.length s - Stdlib.String.length suffix)
    else failwithf "%S does not end with %S" s suffix ()
  ;;

  let chop_prefix s ~prefix =
    if Stdlib.String.starts_with ~prefix s
    then
      Some
        (Stdlib.String.sub
           s
           (Stdlib.String.length prefix)
           (Stdlib.String.length s - Stdlib.String.length prefix))
    else None
  ;;

  let concat_map s ~f =
    let buf = Buffer.create (Stdlib.String.length s * 2) in
    Stdlib.String.iter (fun c -> Buffer.add_string buf (f c)) s;
    Buffer.contents buf
  ;;

  let split s ~on = Stdlib.String.split_on_char on s

  let substr_replace_all s ~pattern ~with_ =
    let plen = Stdlib.String.length pattern in
    if plen = 0
    then s
    else (
      let buf = Buffer.create (Stdlib.String.length s) in
      let slen = Stdlib.String.length s in
      let i = ref 0 in
      while !i <= slen - plen do
        if Stdlib.String.equal (Stdlib.String.sub s !i plen) pattern
        then (
          Buffer.add_string buf with_;
          i := !i + plen)
        else (
          Buffer.add_char buf (Stdlib.String.get s !i);
          incr i)
      done;
      while !i < slen do
        Buffer.add_char buf (Stdlib.String.get s !i);
        incr i
      done;
      Buffer.contents buf)
  ;;

  module Set = struct
    include Set.Make (Stdlib.String)

    let of_list l = Stdlib.List.fold_left (fun s x -> add x s) empty l
    let to_list s = elements s
  end

  module Map = struct
    include Map.Make (Stdlib.String)

    let of_alist_exn l =
      Stdlib.List.fold_left
        (fun m (k, v) ->
           if mem k m
           then failwithf "String.Map.of_alist_exn: duplicate key %S" k ()
           else add k v m)
        empty
        l
    ;;

    let find_exn k m =
      match find_opt k m with
      | Some v -> v
      | None -> failwithf "String.Map.find_exn: key %S not found" k ()
    ;;
  end

  module Table = struct
    let create () : (string, 'a) Stdlib.Hashtbl.t = Stdlib.Hashtbl.create 64
  end

  module Caseless = struct
    let equal a b = Stdlib.String.equal (lowercase_ascii a) (lowercase_ascii b)
  end

  let ( = ) = Stdlib.String.equal
end

module Set = struct
  type 'a t = String.Set.t

  let diff = String.Set.diff
  let to_list = String.Set.to_list
  let add s x = String.Set.add x s
  let mem s x = String.Set.mem x s
  let is_empty = String.Set.is_empty
  let of_list = String.Set.of_list
  let empty = String.Set.empty
end

module Map = struct
  type ('k, 'v) t = 'v String.Map.t

  let find m k = String.Map.find_opt k m
  let find_exn m k = String.Map.find_exn k m
  let of_alist_exn = String.Map.of_alist_exn
end

module Hashtbl = struct
  include Stdlib.Hashtbl

  let add_exn tbl ~key ~data =
    if Stdlib.Hashtbl.mem tbl key
    then failwith "Hashtbl.add_exn: key already present"
    else Stdlib.Hashtbl.replace tbl key data
  ;;

  let find tbl key = Stdlib.Hashtbl.find_opt tbl key
end

module Option = struct
  let value x ~default =
    match x with
    | Some v -> v
    | None -> default
  ;;

  let value_exn ?here:_ ?error:_ ?message x =
    match x, message with
    | Some v, _ -> v
    | None, Some msg -> failwith msg
    | None, None -> failwith "Option.value_exn: None"
  ;;

  let map x ~f =
    match x with
    | Some v -> Some (f v)
    | None -> None
  ;;

  let bind x ~f =
    match x with
    | Some v -> f v
    | None -> None
  ;;

  let is_some = function
    | Some _ -> true
    | None -> false
  ;;

  let is_none = function
    | None -> true
    | Some _ -> false
  ;;

  let some x = Some x
  let some_if cond x = if cond then Some x else None

  let first_some a b =
    match a with
    | Some _ -> a
    | None -> b
  ;;

  let try_with f =
    try Some (f ()) with
    | _ -> None
  ;;

  let equal eq a b =
    match a, b with
    | None, None -> true
    | Some a, Some b -> eq a b
    | _ -> false
  ;;

  module Let_syntax = struct
    module Let_syntax = struct
      let map x ~f = map x ~f
      let bind x ~f = bind x ~f

      let both a b =
        match a, b with
        | Some a, Some b -> Some (a, b)
        | _ -> None
      ;;
    end

    let ( >>| ) x f = map x ~f
    let ( >>= ) x f = bind x ~f
  end

  let ( >>| ) x f = map x ~f
  let ( >>= ) x f = bind x ~f
end

module Result = struct
  type ('a, 'e) t = ('a, 'e) Stdlib.result

  let map x ~f =
    match x with
    | Ok v -> Ok (f v)
    | Error _ as e -> e
  ;;

  let map_error x ~f =
    match x with
    | Ok _ as ok -> ok
    | Error e -> Error (f e)
  ;;

  let bind x ~f =
    match x with
    | Ok v -> f v
    | Error _ as e -> e
  ;;

  let all l =
    let rec aux acc = function
      | [] -> Ok (Stdlib.List.rev acc)
      | Ok x :: rest -> aux (x :: acc) rest
      | (Error _ as e) :: _ -> e
    in
    aux [] l
  ;;

  let failf fmt = Printf.ksprintf (fun s -> Error s) fmt

  let ok_or_failwith = function
    | Ok x -> x
    | Error s -> failwith s
  ;;

  let of_option x ~error =
    match x with
    | Some v -> Ok v
    | None -> Error error
  ;;

  let return x = Ok x

  let try_with f =
    try Ok (f ()) with
    | e -> Error e
  ;;

  module Let_syntax = struct
    module Let_syntax = struct
      let map x ~f = map x ~f
      let bind x ~f = bind x ~f

      let both a b =
        match a, b with
        | Ok a, Ok b -> Ok (a, b)
        | (Error _ as e), _ -> e
        | _, (Error _ as e) -> e
      ;;
    end
  end
end

module Int = struct
  include Stdlib.Int

  let compare (a : int) (b : int) = Stdlib.compare a b
  let equal (a : int) (b : int) = Stdlib.( = ) a b
  let ( > ) (a : int) (b : int) = Stdlib.( > ) a b
  let ( < ) (a : int) (b : int) = Stdlib.( < ) a b
  let ( >= ) (a : int) (b : int) = Stdlib.( >= ) a b
  let ( <= ) (a : int) (b : int) = Stdlib.( <= ) a b
  let ( = ) (a : int) (b : int) = Stdlib.( = ) a b
  let to_string = Stdlib.string_of_int
  let of_string = Stdlib.int_of_string
  let of_float = Stdlib.int_of_float
  let to_int64 = Stdlib.Int64.of_int
  let max_value = Stdlib.max_int
end

module Int64 = struct
  include Stdlib.Int64

  let of_float = Stdlib.Int64.of_float
end

module Float = struct
  include Stdlib.Float

  let of_int = Stdlib.float_of_int
  let to_int = Stdlib.int_of_float
  let round_up x = Stdlib.ceil x
  let ( / ) = ( /. )
end

module Bool = struct
  include Stdlib.Bool

  let to_string = Stdlib.string_of_bool
  let of_string = Stdlib.bool_of_string
  let equal (a : bool) (b : bool) = Stdlib.( = ) a b
end

module Memo = struct
  let general (type a b) (f : a -> b) : a -> b =
    let tbl = Stdlib.Hashtbl.create 16 in
    fun x ->
      match Stdlib.Hashtbl.find_opt tbl x with
      | Some y -> y
      | None ->
        let y = f x in
        Stdlib.Hashtbl.replace tbl x y;
        y
  ;;
end

let read_file path = In_channel.with_open_bin path In_channel.input_all

let write_file path data =
  Out_channel.with_open_bin path (fun oc -> output_string oc data)
;;
