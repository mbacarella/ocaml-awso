# local-opam-ci

The idea is we run [ocurrent/opam-repo-ci](https://github.com/ocurrent/opam-repo-ci)'s
`opam-ci-check` against this working tree locally, so we catch lint regressions
(missing deps, malformed fields, etc.) before bothering opam-repository
maintainers.

Handles **lint** (no Docker) and **build** (sequential local Docker). For
parallel/sharded builds, the plan is to farm them out to AWS spot instances
via the `ci-spot-build-in-aws` sibling tool, eventually.

## Workflow

```
./run.sh bootstrap        # clones opam-repository into ~/.cache/awso-ci/
./run.sh bootstrap pin    # additionally `opam pin add opam-ci-check ...`
./run.sh lint             # stages our *.opam files and runs the linter
./run.sh build            # stages, then `opam-ci-check build` per package
                          # (Docker, sequential, defaults: debian-12 + 5.3.0)
./run.sh build --with-test --lower-bounds
                          # forwards any extra flags to opam-ci-check build
./run.sh build --distro ubuntu-24.04 --compiler 5.4.0
                          # override defaults
```

`stage` is a separate command if you want to inspect what landed in the clone
before running anything:

```
./run.sh stage
ls ~/.cache/awso-ci/opam-repository/packages/awso/awso.0.9.0/
```

## Versions / pinning

The script's `bootstrap` step uses:

- `opam-repository` at `master` (cloned to `~/.cache/awso-ci/opam-repository`).
- `opam-ci-check` pinned to `ocurrent/opam-repo-ci#master`.
- `obuilder` — not pinned. TODO: pick a version compatible with the
  `opam-ci-check` ref above.

These pin sources live in `run.sh`, not in `dune-project`, so they don't bleed
into the awso package metadata.
