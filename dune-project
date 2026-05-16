(lang dune 3.0)

(name awso)

(generate_opam_files true)

(license MIT)

(authors "Ashish Agarwal <ashish@solvuu.com>" "Solvuu Inc." "Michael Bacarella <m@bacarella.com>")

(maintainers "Michael Bacarella <m@bacarella.com>")

(homepage "https://github.com/mbacarella/awso")

(source
 (github mbacarella/awso))

(package
 (name awso)
 (synopsis "AWS API base library")
 (depends
  (ocaml
   (>= 4.14))
  awso-codegen
  (cohttp
   (>= 0.21.0))
  cryptokit
  ppx_expect
  ppx_yojson_conv
  (re
   (>= 1.7.2))
  xmlm
  zarith))

(package
 (name awso-async)
 (synopsis "AWS API base library Async")
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
 (synopsis "AWS API base library Lwt")
 (depends
  (ocaml
   (>= 4.14))
  awso
  lwt
  lwt_ppx
  cohttp-lwt-unix))

(package
 (name awso-common)
 (synopsis "Jane Street Core/Base compatibility shim")
 (depends
  (ocaml
   (>= 4.14))
  ppx_expect))

(package
 (name awso-codegen)
 (synopsis "AWS botocore code generator")
 (depends
  (ocaml
   (>= 4.14))
  awso-common
  ocamlgraph
  ppxlib
  ppx_expect
  (re
   (>= 1.7.2))
  (sedlex
   (>= 2.3))
  uri
  xmlm
  yojson))

(package
 (name awso-unix)
 (synopsis "AWS API base library Unix")
 (depends
  (ocaml
   (>= 4.14))
  awso
  ppx_expect))
