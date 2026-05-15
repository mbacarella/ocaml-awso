let () =
  try Command_unix.run Awso_codegen.Cmd.main with
  | e -> eprintf "%s\n" (Exn.to_string e)
;;
