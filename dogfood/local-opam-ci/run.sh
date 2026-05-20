#!/usr/bin/env bash
# Local opam-repository CI runner. Drives ocurrent/opam-repo-ci's opam-ci-check
# against the .opam files in this working tree, so we don't have to bug
# opam-repository maintainers with stuff a lint would have caught.
#
# Usage: ./run.sh {bootstrap|stage|lint|build|remove-pins}
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

DEFAULT_DISTRO="debian-12"
DEFAULT_COMPILER="5.3.0"

# build needs each opam file to have a `url:` field pointing at a fetchable
# tarball. Our checked-in .opam files don't (dune-release fills it in at
# publish time), so build amends the staged copy with a url block pointing
# at the GitHub release tarball for the latest git tag.
RELEASE_GH_REPO="mbacarella/ocaml-awso"

usage() {
  cat <<EOF
Usage: $0 {bootstrap|stage|lint|build [opts]|remove-pins}

  bootstrap     Clone opam-repository into $OPAM_REPO and tell you how to
                install opam-ci-check (only does the pin if invoked with
                "bootstrap pin").
  stage         Copy this tree's *.opam files into the local opam-repository
                clone under packages/<pkg>/<pkg>.<ver>/opam.
  lint          Stage, then run opam-ci-check lint against the staged
                packages.
  build         Stage, then run opam-ci-check build per package via Docker.
                Sequential; one container at a time. Forwards any extra args
                to opam-ci-check build (e.g. --with-test, --lower-bounds).

                Defaults: --distro $DEFAULT_DISTRO --compiler $DEFAULT_COMPILER.
                Override either via the corresponding flag at the end.
  remove-pins   Undo bootstrap's opam pin add (opam-ci-check and
                opam-ci-check-lint).
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

latest_release_tag() {
  # Highest semver-shaped tag in the local repo. dune-release tags as plain
  # "0.9.0". Filter to N.N.N(.N)? to exclude stray tags ("changes", "v1.0",
  # etc.).
  git -C "$PROJECT_ROOT" tag --sort=-v:refname \
    | grep -E '^[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?$' \
    | head -n1
}

ensure_release_tarball() {
  # Fetch the release tarball into the cache once and emit its sha256 on stdout.
  local tag="$1"
  local url="https://github.com/$RELEASE_GH_REPO/releases/download/$tag/awso-$tag.tbz"
  local tarball="$CACHE_DIR/awso-$tag.tbz"
  if [ ! -f "$tarball" ]; then
    echo "[local-opam-ci] fetching $url" >&2
    curl -sSfL -o "$tarball" "$url"
  fi
  sha256sum "$tarball" | awk '{print $1}'
}

append_url_to_staged() {
  # Append url{} block referencing the release tarball to each staged opam.
  local tag="$1" sha="$2"
  local url="https://github.com/$RELEASE_GH_REPO/releases/download/$tag/awso-$tag.tbz"
  shopt -s nullglob
  local opam pkg ver dest
  for opam in "$PROJECT_ROOT"/*.opam; do
    pkg="$(basename "$opam" .opam)"
    ver="$(opam_version_of "$opam")"
    [ -z "$ver" ] && continue
    dest="$OPAM_REPO/packages/$pkg/$pkg.$ver/opam"
    [ ! -f "$dest" ] && continue
    cat >>"$dest" <<EOF
url {
  src: "$url"
  checksum: "sha256=$sha"
}
EOF
  done
}

build() {
  shift  # drop the "build" subcommand
  if ! command -v docker >/dev/null 2>&1; then
    echo "[local-opam-ci] docker not found; build requires Docker" >&2
    exit 1
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "[local-opam-ci] docker daemon not reachable" >&2
    exit 1
  fi

  # Default --distro and --compiler unless the caller passes their own.
  local extra=()
  local has_distro=0 has_compiler=0
  for arg in "$@"; do
    case "$arg" in
      --distro|--distro=*) has_distro=1 ;;
      --compiler|--compiler=*) has_compiler=1 ;;
    esac
  done
  [ "$has_distro" -eq 0 ] && extra+=(--distro "$DEFAULT_DISTRO")
  [ "$has_compiler" -eq 0 ] && extra+=(--compiler "$DEFAULT_COMPILER")

  stage

  local tag sha
  tag="$(latest_release_tag)"
  if [ -z "$tag" ]; then
    echo "[local-opam-ci] no git tags found; tag a release first (dune-release tag)" >&2
    exit 1
  fi
  echo "[local-opam-ci] using release tag $tag"
  sha="$(ensure_release_tarball "$tag")"
  append_url_to_staged "$tag" "$sha"

  cd "$PROJECT_ROOT"
  shopt -s nullglob
  local opam
  for opam in *.opam; do
    local pkg ver
    pkg="${opam%.opam}"
    ver="$(opam_version_of "$opam")"
    [ -z "$ver" ] && continue
    echo "[local-opam-ci] building $pkg.$ver ..."
    # 'build' takes just <name.version>; src/new attributes are lint-only.
    opam-ci-check build "$pkg.$ver" \
      -r "$OPAM_REPO" \
      "${extra[@]}" \
      "$@"
  done
}

remove_pins() {
  opam pin remove -y opam-ci-check      || true
  opam pin remove -y opam-ci-check-lint || true
}

cmd="${1:-}"
case "$cmd" in
  bootstrap) bootstrap "$@";;
  stage) stage;;
  lint) lint;;
  build) build "$@";;
  remove-pins) remove_pins;;
  -h|--help|help|"") usage;;
  *) usage; exit 2;;
esac
