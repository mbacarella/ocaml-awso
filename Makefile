SHELL=/bin/bash

.PHONY: default
default: start-ocaml

.PHONY: install-deps
install-deps:
	test -d _opam || opam switch create . 5.3.0 --no-install --yes
	( eval $$(opam env) && opam install . --deps-only --yes )
	( eval $$(opam env) && opam install ocamlformat ocaml-lsp-server utop --yes )

.PHONY: start-ocaml
start-ocaml:
	dune build @all -w

# start-ocaml builds all packages. That can be slow. The following command builds a
# single package. For example, try `make aws-s3`.
aws-%:
	dune build @aws/$*/all -w

botodata-%:
	wget https://github.com/boto/botocore/archive/$*.tar.gz
	tar xzf $*.tar.gz
	rm -f $*.tar.gz
	mkdir -p vendor/botocore/botocore
	cp -Rpifn botocore-$*/botocore/data vendor/botocore/botocore/
	cp -fn botocore-$*/CONTRIBUTING.rst botocore-$*/LICENSE.txt botocore-$*/NOTICE botocore-$*/README.rst vendor/botocore/
	rm -rf botocore-$*
	git add vendor

.PHONY: doc
doc:
	dune build @doc

.PHONY: format
format:
	dune fmt

.PHONY: runtest
runtest:
	dune build @runtest

.PHONY: build-services
build-services:
	dune exec bin/awso_codegen_main.exe -- services --botocore-data vendor/botocore/botocore/data -o aws

.PHONY: clean
clean:
	dune clean

FORCE:
