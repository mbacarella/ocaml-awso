(* Minimal repro for ocaml/ocaml#14925 on Graviton4: an unknown 2-argument
   call on a closure that the immediately preceding call just allocated.

   With the PR, the call site checks the callee's arity itself. Commit 2
   reads it as one byte (offset 7 of the closure-info word); commit 1 reads
   the whole word and shifts. Here the info word was written by [make] a few
   instructions earlier, as one 8-byte store.

   [Sys.opaque_identity] keeps both functions unknown, and keeps [make] at
   arity 1 (otherwise [fun a -> fun x y -> ...] is merged into one 3-argument
   function and [make i] becomes a partial application).

   Usage: repro N    (prints a checksum) *)

let make = Sys.opaque_identity (fun a -> Sys.opaque_identity (fun x y -> a + x + y))

let () =
  let n = int_of_string Sys.argv.(1) in
  let acc = ref 0 in
  for i = 1 to n do
    let g = make i in
    acc := g !acc i land 0xffffff
  done;
  Printf.printf "%d\n" !acc
