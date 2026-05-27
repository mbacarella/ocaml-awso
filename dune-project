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
   (>= 5.3.0))
  awso-common
  (cohttp
   (>= 6.0.0))
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
   (>= 5.3.0))
  awso
  cohttp-async
  (core_unix
   (>= v0.16.0))
  (ppx_jane
   (>= v0.16.0))
  ppx_yojson_conv
  (async
   (>= v0.16.0))
  (async_ssl
   ; only the *-2 revisions suppress both -Wimplicit-function-declaration
   ; (needed on OpenSSL builds without the ENGINE_* API, e.g. centos-10)
   ; and -Wincompatible-pointer-types (OpenSSL 3 stricter pointer types,
   ; e.g. debian-13). The intermediate -1 revisions only suppress the
   ; pointer-types warning, which leaves the ENGINE_* errors uncaught.
   (and
    (>= v0.16.1-2)
    (or
     (< v0.17.0)
     (>= v0.17.0-2))))))

(package
 (name awso-eio)
 (synopsis "AWS client for Eio (400+ services, auto-generated from botocore)")
 (description
  "AWS service bindings backed by the Eio I/O library. Generated from botocore for ~400 services. Use this if your codebase is Eio-flavored. Requires OCaml 5+.")
 (depends
  (ocaml
   (>= 5.0))
  awso
  (eio
   (>= 0.12))
  (cohttp-eio
   (>= 6.2.1))
  ; 2.1.0 fixes CVE-2026-45388 (missing client-side keyUsage /
  ; extendedKeyUsage validation in TLS 1.3). awso-eio is a TLS client.
  (tls
   (>= 2.1.0))
  (tls-eio
   (>= 2.1.0))
  ca-certs
  ; 1.2.0 introduced Mirage_crypto_rng_unix.use_default (replacement for
  ; the now-deprecated initialize).
  (mirage-crypto-rng
   (>= 1.2.0))))

(package
 (name awso-lwt)
 (synopsis "AWS client for Lwt (400+ services, auto-generated from botocore)")
 (description
  "AWS service bindings backed by the Lwt I/O library. Generated from botocore for ~400 services. Use this if your codebase is Lwt-flavored.")
 (depends
  (ocaml
   (>= 5.3.0))
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
   (>= 5.3.0))
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
   (>= 5.3.0))
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
   (>= 5.3.0))
  awso-async
  (core_unix
   (>= v0.16.0))
  (ppx_jane
   (>= v0.16.0))))
