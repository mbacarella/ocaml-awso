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
interfaces are provided. There is additionally a command-line tool `awso-cli` for
all APIs composed using Core.Command.

## Getting started

The library is massive and not currently released to OPAM to avoid
overwhelming the package repository.

To use awso in your project, we recommend installing it with `opam`. It's big, it may take awhile.

```shell
opam install awso-async # if using async
opam install awso-lwt   # if using lwt
```

### Examples

See the [examples](./examples) directory.

Here is a short example that lists all EC2 instances, using Async I/O:

```dune
; dune
(executable
 (name awso_ec2_describe_instances)
 (libraries awso-async.ec2 core_unix.command_unix)
 (preprocess
  (pps ppx_jane)))
```

```ocaml
(* ec2_describe_instances.ml *)
open Core
open Async
module Ec2 = Awso_ec2_async

let ec2_describe_instances () =
  match%bind Ec2.describe_instances (Ec2.DescribeInstancesRequest.make ()) with
  | Error aws ->
    let errstr = aws |> Ec2.Ec2_error.to_json |> Yojson.Safe.to_string in
    failwithf "AWS says your query had an error: %s\n" errstr ()
  | Ok result ->
    result.reservations
    |> Option.value_exn ~here:[%here]
    |> List.iter ~f:(fun reservation ->
      reservation.Ec2.Reservation.instances
      |> Option.value ~default:[]
      |> List.iter ~f:(fun instance ->
        let str = instance |> Ec2.Instance.to_json |> Yojson.Safe.pretty_to_string in
        print_endline str));
    return ()
;;

let () =
  let cmd =
    Command.async
      ~summary:"list EC2 instances in default region"
      (let%map_open.Command () = return () in
       fun () -> ec2_describe_instances ())
  in
  Command_unix.run cmd
;;
```

Populate `~/.aws/config` and `~/.aws/credentials` in the usual way, then:

```
dune exec ./ec2_describe_instances.exe
```

## Documentation

Generate API docs locally with `opam install odoc` then `make doc`.
