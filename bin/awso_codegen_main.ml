let () =
  try
    let argv = Array.sub Sys.argv 1 (Array.length Sys.argv - 1) in
    Awso_codegen.Cmd.main argv
  with
  | e ->
    Printf.eprintf "%s\n%s" (Printexc.to_string e) (Printexc.get_backtrace ());
    exit 1
;;
