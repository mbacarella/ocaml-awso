#!/usr/bin/env bash
# Local opam-repository CI runner. Drives ocurrent/opam-repo-ci's opam-ci-check
# against the .opam files in this working tree, so we don't have to bug
# opam-repository maintainers with stuff a lint would have caught.
#
# Usage: ./run.sh {bootstrap|stage|lint}
#
# Pin versions live here (in tool config) rather than in awso's dune-project
# so they don't bleed into the package metadata.

set -euo pipefail

PROJECT_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/awso-ci"
OPAM_REPO="$CACHE_DIR/opam-repository"
OPAM_REPO_URL="https://github.com/ocaml/opam-repository.git"

# Pin sources. Bump the # ref when you want a new version.
OPAM_REPO_CI_REPO="https://github.com/ocurrent/opam-repo-ci.git"
OPAM_REPO_CI_REF="master"
# TODO: pin obuilder to a specific version once we know which one opam-ci-check
# at OPAM_REPO_CI_REF actually wants. For now leave to opam's resolver.

usage() {
  cat <<EOF
Usage: $0 {bootstrap|stage|lint}

  bootstrap   Clone opam-repository into $OPAM_REPO and tell you how to
              install opam-ci-check (only does the pin if invoked with
              "bootstrap pin").
  stage       Copy this tree's *.opam files into the local opam-repository
              clone under packages/<pkg>/<pkg>.<ver>/opam.
  lint        Stage, then run opam-ci-check lint against the staged packages.
EOF
}

ensure_clone() {
  mkdir -p "$CACHE_DIR"
  if [ ! -d "$OPAM_REPO/.git" ]; then
    echo "[local-opam-ci] cloning $OPAM_REPO_URL -> $OPAM_REPO"
    git clone --depth 1 "$OPAM_REPO_URL" "$OPAM_REPO"
  else
    echo "[local-opam-ci] updating $OPAM_REPO"
    git -C "$OPAM_REPO" fetch --depth 1 origin master
    git -C "$OPAM_REPO" reset --hard origin/master
  fi
}

bootstrap() {
  ensure_clone
  if command -v opam-ci-check >/dev/null 2>&1; then
    echo "[local-opam-ci] opam-ci-check already installed"
  else
    cat <<EOF
[local-opam-ci] opam-ci-check is not installed. opam-ci-check depends on
opam-ci-check-lint, which lives in the same repo, so pin both:

  opam pin add opam-ci-check-lint $OPAM_REPO_CI_REPO#$OPAM_REPO_CI_REF
  opam pin add opam-ci-check      $OPAM_REPO_CI_REPO#$OPAM_REPO_CI_REF

Or invoke "$0 bootstrap pin" to have this script do it for you.
EOF
    if [ "${2:-}" = "pin" ]; then
      opam pin add -y opam-ci-check-lint "$OPAM_REPO_CI_REPO#$OPAM_REPO_CI_REF"
      opam pin add -y opam-ci-check      "$OPAM_REPO_CI_REPO#$OPAM_REPO_CI_REF"
    fi
  fi
}

opam_version_of() {
  # Read the version: field from an opam file. Tolerates extra whitespace.
  local file="$1"
  awk -F'"' '/^version:/ { print $2; exit }' "$file"
}

stage() {
  if [ ! -d "$OPAM_REPO/.git" ]; then
    echo "[local-opam-ci] opam-repository clone missing; run '$0 bootstrap' first" >&2
    exit 1
  fi
  cd "$PROJECT_ROOT"
  shopt -s nullglob
  local opam
  for opam in *.opam; do
    local pkg ver dest
    pkg="${opam%.opam}"
    ver="$(opam_version_of "$opam")"
    if [ -z "$ver" ]; then
      echo "[local-opam-ci] skipping $opam (no version: field)" >&2
      continue
    fi
    dest="$OPAM_REPO/packages/$pkg/$pkg.$ver"
    mkdir -p "$dest"
    # Strip the version: field — opam-repository derives version from the
    # directory name and opam-ci-check flags an explicit field as redundant.
    sed '/^version: *"/d' "$opam" > "$dest/opam"
    echo "[local-opam-ci] staged $pkg.$ver"
  done
}

lint() {
  stage
  cd "$PROJECT_ROOT"
  shopt -s nullglob
  local specs=()
  local opam
  for opam in *.opam; do
    local pkg ver
    pkg="${opam%.opam}"
    ver="$(opam_version_of "$opam")"
    [ -z "$ver" ] && continue
    # src=$PROJECT_ROOT so opam-ci-check can read the in-tree source for any
    # checks that need it. new=true tells it these are newly-published.
    # Format is pkg.ver:k1=v1,k2=v2 (one colon, comma-separated kvs).
    specs+=("$pkg.$ver:src=$PROJECT_ROOT,new=true")
  done
  if [ "${#specs[@]}" -eq 0 ]; then
    echo "[local-opam-ci] no .opam files found at $PROJECT_ROOT" >&2
    exit 1
  fi
  opam-ci-check lint -r "$OPAM_REPO" "${specs[@]}"
}

cmd="${1:-}"
case "$cmd" in
  bootstrap) bootstrap "$@";;
  stage) stage;;
  lint) lint;;
  -h|--help|help|"") usage;;
  *) usage; exit 2;;
esac
