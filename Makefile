SHELL=/bin/bash
.PHONY: default install-deps start-ocaml doc format runtest generate-code clean

default: start-ocaml

install-deps:
	test -d _opam || opam switch create . 5.3.0 --no-install --yes
	opam install . --deps-only --yes
	opam install ocamlformat ocaml-lsp-server utop --yes

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

doc:
	dune build @doc

format:
	dune fmt

runtest:
	dune build @runtest

generate-code:
	dune exec -- bin/awso_bootstrap.exe build-service-module --botocore-data vendor/botocore/botocore/data
	dune exec -- bin/awso_codegen_main.exe generate-all --botocore-data vendor/botocore/botocore/data -o aws --runtime-dir lib/runtime/awso

clean:
	dune clean
