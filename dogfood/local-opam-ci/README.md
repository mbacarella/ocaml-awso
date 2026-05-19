# local-opam-ci

Run [ocurrent/opam-repo-ci](https://github.com/ocurrent/opam-repo-ci)'s
`opam-ci-check` against this working tree locally, so we catch lint regressions
(missing deps, malformed fields, etc.) before bothering opam-repository
maintainers.

This handles **lint only** for now. Build/test (which require Docker or a real
build environment) will live elsewhere — the plan is to farm them out to AWS
spot instances via the `ci-spot-build-in-aws` sibling tool.

## Prerequisites

- `git`
- `opam`
- `opam-ci-check` installed in the current switch (see `bootstrap`).

## Workflow

```
./run.sh bootstrap        # clones opam-repository into ~/.cache/awso-ci/
./run.sh bootstrap pin    # additionally `opam pin add opam-ci-check ...`
./run.sh lint             # stages our *.opam files and runs the linter
```

`stage` is a separate command if you want to inspect what landed in the clone
before running the linter:

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
