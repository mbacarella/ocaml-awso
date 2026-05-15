# awso - OCaml AWS client

Forked from [awsm](https://github.com/solvuu/awsm), Copyright (c) Solvuu, Inc.
Released under the [MIT license](./LICENSE.md).

Pure OCaml client for AWS. Code is auto-generated for all services
based on the API declared in
[botocore](https://github.com/boto/botocore/). Higher level functions
are often implemented on top of this base, e.g. to support multi-part
uploads to S3.

Sub-libraries are provided for Async and Lwt versions of all code.

## Features

Nearly all of AWS's 300+ APIs are supported. Async and Lwt concurrency
interfaces are provided. There is additionally a command-line tool for
all APIs composed using Core.Command.

## Getting started

The library is massive and not currently released to OPAM to avoid
overwhelming the package repository.

To use awso in your project, we recommend cloning it into a
sub-directory and using dune rules to access desired APIs.

```
cd your-existing-project
git clone git@github.com:mbacarella/awso awso
cd awso
make install-deps
eval $(opam env)
```

If you get stack overflow errors during compilation, increase stack size:

```
prlimit --stack=unlimited dune ...
```

### Examples

See the [examples](./examples) directory.

Here is a short example that lists all EC2 instances:

```dune
; dune
(executable
 (name awso_ec2_describe_instances)
 (libraries awso-ec2-async core_unix.command_unix)
 (flags
  (:standard -open Core -open Async))
 (preprocess
  (pps ppx_jane)))
```

```ocaml
(* awso_ec2_describe_instances.ml *)
module Ec2 = Awso_ec2_async

let ec2_describe_instances () =
  let%bind response =
    Ec2.describe_instances (Ec2.Values.DescribeInstancesRequest.make ())
  in
  let reservations =
    match response with
    | Error (`Transport err) ->
      let errstr = err |> Awso.Http.Io.Error.sexp_of_call |> Sexp.to_string_hum in
      failwithf "Transport error communicating with EC2: %s\n" errstr ()
    | Error (`AWS aws) ->
      let errstr = aws |> Ec2.Values.Ec2_error.sexp_of_t |> Sexp.to_string_hum in
      failwithf "AWS says your query had an error: %s\n" errstr ()
    | Ok result -> result.reservations
  in
  reservations
  |> Option.value_exn ~here:[%here]
  |> List.iter ~f:(fun reservation ->
    reservation.Ec2.Values.Reservation.instances
    |> Option.value ~default:[]
    |> List.iter ~f:(fun instance ->
      let str = instance |> Ec2.Values.Instance.sexp_of_t |> Sexp.to_string_hum in
      print_endline str));
  return ()
;;

let () =
  let cmd =
    Command.async
      ~summary:"List all EC2 instances in a region"
      (let%map_open.Command () = return () in
       fun () -> ec2_describe_instances ())
  in
  Command_unix.run cmd
;;
```

Populate `~/.aws/config` and `~/.aws/credentials` in the usual way, then:

```
dune exec ./awso_ec2_describe_instances.exe
```

## Documentation

Generate API docs locally with `opam install odoc` then `make doc`.
