(lang dune 3.8)

(name awso)

(generate_opam_files true)

(opam_file_location inside_opam_directory)

(license MIT)

(authors "Solvuu Inc.")

(maintainers "Michael Bacarella <m@bacarella.com>")

(homepage "https://github.com/solvuu/awso")

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
  cryptokit
  xmlm
  zarith))

(package
 (name awso-async)
 (synopsis "AWS API base library Async")
 (depends
  awso
  cohttp-async
  (async
   (>= v0.11.0))
  async_ssl))

(package
 (name awso-lwt)
 (synopsis "AWS API base library Lwt")
 (depends awso lwt cohttp-lwt-unix))

(package
 (name awso-codegen)
 (synopsis "AWS botocore code generator")
 (depends
  cohttp
  ocamlgraph
  ppxlib
  (re
   (>= 1.7.2))
  (sedlex
   (>= 2.3))
  xmlm
  yojson))

(package
 (name awso-unix)
 (synopsis "AWS API base library Unix"))
