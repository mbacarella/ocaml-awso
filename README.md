# awso - OCaml AWS client

There are a few AWS libraries for OCaml but none are comprehensive and polished. This is an attempt to continue the [awso](https://github.com/solvuu/awso) library that was abandoned at the 99 yard line.

Pure OCaml client for AWS. Code is auto-generated for all services
based on the API declared in
[botocore](https://github.com/boto/botocore/). Higher level functions
are often implemented on top of this base, e.g. to support multi-part
uploads to S3.

Sub-libraries are provided for Async and Lwt versions of all code.

## Table of Contents

- [Features](#features)
- [Getting started](#getting-started)
  - [Install](#install)
  - [Examples](#examples)
- [Documentation](#documentation)
- [License](#license)
- [How to contribute](#how-to-contribute)


## Features

Nearly all of AWS's 300 APIs are supported. Async and Lwt concurrency interfaces are
provided. There is additionally a command-line tool for all APIs composed using Core.Command.

## Getting started

### Install and build with local OPAM switch and lock file

The library is massive and not currently released to OPAM to avoid overwhelming the package
repository.

To use awso in your project, we recommend cloning it into a sub-directory and using
dune rules to access desired APIs.

```
cd your-existing-project
git clone git@github.com:mbacarella/awso awso
cd awso
make install-deps
eval $(opam env)
```

If you get stack overflow errors, you will need to increase stack size.
Some auto-generated modules are enormous and overwhelm the OCaml compiler.

```
prlimit --stack=unlimited dune ...
```

### Examples

See the [examples](./examples) directory for some examples.

In this README we will construct an example that simply lists all servers in EC2.

Make yourself a directory in this repo.

```shell
mkdir ec2-describe-instances
cd ec2-describe-instances
```

Set set up your dune file.

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

Write some code.

Note that instead of functors, `awso` uses [lightweight higher-kinded
polymorphism](https://www.cl.cam.ac.uk/~jdy22/papers/lightweight-higher-kinded-polymorphism.pdf)
to generalize over concurrency libraries (Async and Lwt).

```ocaml
(* awso_ec2_describe_instances.ml *)
(* The Cfg module is needed to access credentials and other configuration settings. *)
module Cfg = Awso_async.Cfg

(* This local module isn't strictly necessary but if you use multiple APIs it will keep
   API specific functions tidy.

   For the lwt version, you would simply replace "_async" with "_lwt". *)
module Ec2 = struct
  module Values = Awso_ec2_async.Values
  module Io = Awso_ec2_async.Io

  let call = Awso_async.Http.Io.call ~service:Values.service
end

let ec2_describe_instances ~cfg =
  (* Call EC2 API "describe-instances", which lists all servers in EC2 *)
  let%bind response =
    Ec2.Io.describe_instances
      (Ec2.call ~cfg)
      (Ec2.Values.DescribeInstancesRequest.make ())
  in
  (* Retrieve 'reservations' from the EC2 result, translating any errors on the way. *)
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
  (* Use sexp-expressions to pretty print the instances. *)
  let () =
    reservations
    |> Option.value_exn ~here:[%here]
    |> List.iter ~f:(fun reservation ->
      reservation.Ec2.Values.Reservation.instances
      |> Option.value ~default:[]
      |> List.iter ~f:(fun instance ->
        let str = instance |> Ec2.Values.Instance.sexp_of_t |> Sexp.to_string_hum in
        print_endline str))
  in
  return ()
;;

let main () =
  let%bind cfg = Awso_async.Cfg.get_exn () in
  ec2_describe_instances ~cfg
;;

let () =
  let cmd =
    Command.async
      ~summary:"List all EC2 instances in a region"
      (let%map_open.Command () = return () in
       fun () -> main ())
  in
  Command_unix.run cmd
;;
```

Next, make sure to populate your `~/.aws/config` and `~/.aws/credentials` file in the usual way.

Finally, run `dune exec`

```
dune exec ./awso_ec2_describe_instances.exe
```

You should see a sexp output of all compute instances you have in EC2.


## Documentation

To generate the awso API documentation locally you need `odoc`:
`opam install odoc`.

Then run `make doc`.


## License

Awso is released under the [MIT license](./LICENSE.md).


## How to contribute

See [CONTRIBUTING](./CONTRIBUTING.md) for how to help out.
