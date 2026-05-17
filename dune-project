(lang dune 3.6)

(name awso)

(version 0.9.0)

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
  awso-common
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
 (synopsis "AWSO common library")
 (depends
  (ocaml
   (>= 4.14))
  ppx_expect))

(package
 (name awso-sync)
 (synopsis "Synchronous (blocking) AWS client")
 (depends
  (ocaml
   (>= 4.14))
  awso
  ocurl
  ppx_expect))

(package
 (name awso-cli)
 (synopsis "A pure OCaml aws-cli")
 (depends
  (ocaml
   (>= 4.14))
  awso-async
  core_unix
  ppx_jane))
