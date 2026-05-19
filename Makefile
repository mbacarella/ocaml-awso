SHELL=/bin/bash
.PHONY: default install-deps start-ocaml doc format runtest generate-code clean publish-to-opam publish-to-opam-dry-run publish-doc opam-ci-bootstrap opam-ci-lint opam-ci-build opam-ci-remove-pins

# Force dune-release to talk to github over SSH.
export DUNE_RELEASE_DEV_REPO = git@github.com:mbacarella/ocaml-awso.git

default: build

install-deps:
	test -d _opam || opam switch create . 5.3.0 --no-install --yes
	opam install . --deps-only --yes
	opam install ocamlformat ocaml-lsp-server utop dune-release --yes

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

build:
	dune build

runtest:
	dune build @runtest

generate-code:
	# generate some pre-flight modules in lib/runtime/awso
	dune exec -- bin/awso_bootstrap.exe build-service-module --botocore-data vendor/botocore/botocore/data --runtime-dir lib/runtime/awso
	# generate all services to aws/
	dune exec -- bin/awso_codegen_main.exe generate-all --botocore-data vendor/botocore/botocore/data -o aws --runtime-dir lib/runtime/awso --cli-dir awso-cli

clean:
	dune clean

opam-ci-bootstrap:
	dogfood/local-opam-ci/run.sh bootstrap

opam-ci-lint:
	dogfood/local-opam-ci/run.sh lint

opam-ci-build:
	dogfood/local-opam-ci/run.sh build

opam-ci-remove-pins:
	dogfood/local-opam-ci/run.sh remove-pins

publish-to-opam:
	dune-release

publish-to-opam-dry-run:
	@echo "=== building distribution tarball (real, but harmless) ==="
	dune-release distrib
	@echo
	@echo "=== contents of generated tarball ==="
	@ls -lh _build/*.tbz
	@echo "  (full listing: tar tjf _build/*.tbz)"
	@tar tjf _build/*.tbz | head -40
	@echo
	@echo "=== publish distrib (dry-run) ==="
	dune-release publish -t distrib --dry-run
	@echo
	@echo "=== opam pkg (dry-run) ==="
	dune-release opam pkg --dry-run
	@echo
	@echo "=== opam submit (dry-run) ==="
	dune-release opam submit --dry-run

publish-doc: doc
	dune-release publish -t doc
