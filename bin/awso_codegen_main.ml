let () =
  try
    let argv = Array.sub Sys.argv 1 (Array.length Sys.argv - 1) in
    Awso_codegen.Cmd.main argv
  with
  | e ->
    Printf.eprintf "%s\n" (Printexc.to_string e);
    exit 1
;;
