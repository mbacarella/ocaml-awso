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

Nearly all of AWS's 300+ APIs are supported. Three I/O flavors:

- `awso-async` — Jane Street Async backend
- `awso-lwt` — Lwt backend
- `awso-sync` — synchronous (blocking) backend; uses libcurl under the hood

There is additionally a command-line tool `awso-cli` for
all APIs composed using Core.Command.

## Getting started

```shell
opam install awso-async   # Async
opam install awso-lwt     # Lwt
opam install awso-sync    # synchronous (blocking)
opam install awso-cli     # umbrella CLI binary
```

Note: the AWS surface is massive (~300 services) and this package can take
a lengthy amount of time to build. About 5 minutes of building on a typical workstation.

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

## Repository layout

| Path | Purpose | Shipped to opam? |
|---|---|---|
| `lib/runtime/awso/` | Core runtime: auth, HTTP, config, regions | Yes (`awso`) |
| `lib/runtime/async/` | Async backend | Yes (`awso-async`) |
| `lib/runtime/lwt/` | Lwt backend | Yes (`awso-lwt`) |
| `lib/runtime/sync/` | Synchronous (blocking) backend, libcurl-based | Yes (`awso-sync`) |
| `lib/runtime/unix/` | Sync Unix backend | Yes (`awso-unix`) |
| `lib/common/` | Jane Street Core/Base compatibility shim | Yes (`awso-common`) |
| `aws/<service>/` | Auto-generated per-service bindings (~300 services) | Yes (under `awso`, `awso-async`, `awso-lwt`, `awso-sync`) |
| `awso-cli/` | A bit like the Python aws cli | Yes (`awso-cli`) |
| `lib/codegen/` | The code generator that produces `aws/<service>/` from botocore JSON | **No**: private library |
| `vendor/botocore/` | Vendored botocore JSON used by the codegen | **No**: not in release tarballs |
| `dogfood/` | Internal maintenance tools that use `awso` itself | **No**: not packaged |
| `examples/` | Example programs | **No**: not installed |

### Why is the `aws/` tree committed to git?

`aws/<service>/` contains roughly 300 services worth of generated OCaml. We
commit it on purpose so that `opam install awso-async` (or any sibling
package) never has to run the codegen at install time. End users get a
~25-dependency build instead of ~50+ — `ppxlib`, `sedlex`, `ocamlgraph`, and
the rest of the codegen toolchain stay private to maintainers. The decision
trades repo size for install-time simplicity and predictability.

Regeneration is a maintainer concern:

```
make generate-code   # re-runs awso-codegen against vendor/botocore/
```

After regenerating, commit the resulting diff alongside whatever change
prompted it.

## Documentation

Generate API docs locally with `opam install odoc` then `make doc`.
