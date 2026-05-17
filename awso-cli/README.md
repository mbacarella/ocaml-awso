# awso-cli

The `awso-cli` binary exposes every AWS service as a subcommand:
`awso-cli s3 list-buckets`, `awso-cli ec2 describe-instances`, etc.

It's meant to be a quick replacement for the Python `aws` tool, in case you
don't want a Python environment alongside your OCaml.

## Why is this bytecode (`byte_complete`) and not native?

The `awso` binary links a library per AWS service, almost 300 of them.
The resultant native binary is several hundred MB and fails to build on ARM64 Linux.

So, to keep things simple, for all platforms we produce bytecode with the
ocamlrun interpreter embedded in it. 
