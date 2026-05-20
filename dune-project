(lang dune 3.6)

(name awso)

(version 0.9.0)

(generate_opam_files true)

(license MIT)

(authors "Ashish Agarwal <ashish@solvuu.com>" "Solvuu Inc." "Michael Bacarella <m@bacarella.com>")

(maintainers "Michael Bacarella <m@bacarella.com>")

(homepage "https://github.com/mbacarella/ocaml-awso")

(documentation "https://mbacarella.github.io/ocaml-awso/")

(source
 (github mbacarella/ocaml-awso))

(package
 (name awso)
 (synopsis "AWS API base library (400+ services, auto-generated from botocore)")
 (description
  "Logic-only runtime for the awso family of packages: request signing (SigV4), HTTP plumbing, credential discovery, region/endpoint tables, and shared types. I/O bindings live in sibling packages (awso-async, awso-lwt, awso-sync).")
 (depends
  (ocaml
   (>= 4.14))
  awso-common
  (cohttp
   (>= 0.21.0))
  cryptokit
  ppx_expect
  ppx_yojson_conv
  (re
   (>= 1.7.2))
  xmlm
  (yojson
   (>= 2.0.0))
  zarith))

(package
 (name awso-async)
 (synopsis "AWS client for Async (400+ services, auto-generated from botocore)")
 (description
  "AWS service bindings backed by Jane Street's Async I/O library. Generated from botocore for ~400 services. Use this if your codebase is already Async-flavored.")
 (depends
  (ocaml
   (>= 4.14))
  awso
  cohttp-async
  core_unix
  ppx_jane
  ppx_yojson_conv
  (async
   (>= v0.11.0))
  async_ssl))

(package
 (name awso-lwt)
 (synopsis "AWS client for Lwt (400+ services, auto-generated from botocore)")
 (description
  "AWS service bindings backed by the Lwt I/O library. Generated from botocore for ~400 services. Use this if your codebase is Lwt-flavored.")
 (depends
  (ocaml
   (>= 4.14))
  awso
  lwt
  lwt_ppx
  cohttp-lwt-unix))

(package
 (name awso-common)
 (synopsis "AWSO common library")
 (description
  "Small compatibility shim providing Jane Street Core-like helpers (Result, Option, List combinators) without dragging Core itself into non-Async/Lwt builds. Used by awso and the codegen.")
 (depends
  (ocaml
   (>= 4.14))
  ppx_expect
  (yojson
   (>= 2.0.0))))

(package
 (name awso-sync)
 (synopsis "Synchronous (blocking) AWS client (400+ services, auto-generated from botocore)")
 (description
  "AWS service bindings with a synchronous (blocking) I/O backend implemented over libcurl. Generated from botocore for ~400 services. Useful for scripts, CLIs, and any context where pulling in a concurrent scheduler is overkill.")
 (depends
  (ocaml
   (>= 4.14))
  awso
  ocurl
  ppx_expect))

(package
 (name awso-cli)
 (synopsis "A pure OCaml aws-cli covering 400+ services")
 (description
  "For fun, an umbrella command-line binary that exposes every awso-async service as a subcommand, similar in spirit to the Python aws-cli. Ships as bytecode because linking ~400 native service libraries exceeds ARM64 executable sizes. Fast enough for interactive use.")
 (depends
  (ocaml
   (>= 4.14))
  awso-async
  core_unix
  ppx_jane))
