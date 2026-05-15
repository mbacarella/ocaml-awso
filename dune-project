(lang dune 3.8)

(name awso)

(generate_opam_files true)

(opam_file_location inside_opam_directory)

(license MIT)

(authors "Solvuu Inc.")

(maintainers "Michael Bacarella <m@bacarella.com>")

(homepage "https://github.com/mbacarella/awso")

(source
 (github mbacarella/awso))

(package
 (name awso)
 (synopsis "AWS API base library")
 (depends
  awso-codegen
  (base64
   (>= 3.1.0))
  (cohttp
   (>= 0.21.0))
  core
  core_unix
  cryptokit
  ppx_expect
  ppx_jane
  (re
   (>= 1.7.2))
  xmlm
  zarith))

(package
 (name awso-async)
 (synopsis "AWS API base library Async")
 (depends
  awso
  cohttp-async
  core_unix
  ppx_jane
  (async
   (>= v0.11.0))
  async_ssl))

(package
 (name awso-lwt)
 (synopsis "AWS API base library Lwt")
 (depends awso core_unix lwt lwt_ppx cohttp-lwt-unix))

(package
 (name awso-common)
 (synopsis "Jane Street Core/Base compatibility shim")
 (depends ppx_expect))

(package
 (name awso-codegen)
 (synopsis "AWS botocore code generator")
 (depends
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
 (depends awso ppx_jane))
