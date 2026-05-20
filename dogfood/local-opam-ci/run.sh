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
# at a tarball produced locally by `dune-release distrib`. The tarball is
# copied into the opam-repo clone so it shows up inside opam-ci-check's
# docker build context, and the url{} src is a file:// URL pointing at its
# in-container path (opam-ci-check copies the whole opam-repo clone into
# /home/opam/opam-repository/ inside the container).

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
  build         Stage, run \`dune-release distrib\` to build a local tarball,
                copy it into the opam-repo clone, then run opam-ci-check build
                per package via Docker. Sequential; one container at a time.
                Forwards any extra args to opam-ci-check build (e.g.
                --with-test, --lower-bounds).

                Defaults: --distro $DEFAULT_DISTRO --compiler $DEFAULT_COMPILER.
                Override either via the corresponding flag at the end.

                --head builds from current HEAD instead of the latest release
                tag, via a throwaway tag local-<sha>. Cleaned up on exit.
                Uncommitted changes are NOT in the archive — commit first.
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
  # stage [version-override]: if version-override is set, every package is
  # staged under that version (used by --head builds with a synthetic version).
  local version_override="${1:-}"
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
    if [ -n "$version_override" ]; then
      ver="$version_override"
    else
      ver="$(opam_version_of "$opam")"
    fi
    if [ -z "$ver" ]; then
      echo "[local-opam-ci] skipping $opam (no version: field)" >&2
      continue
    fi
    # Wipe any prior staging of this package so stale tarball stashes from a
    # previous `build` (or stale --head version dirs) don't trip lint or
    # accumulate. None of these packages exist upstream in opam-repository
    # yet, so there's nothing to preserve.
    rm -rf "$OPAM_REPO/packages/$pkg"
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

build_local_tarball() {
  # build_local_tarball <tag> <version>
  # Run `dune-release distrib` to produce the source archive from <tag>,
  # stamping <version> into the opam files. Caches by tag; rerun once the
  # tarball is gone (e.g. dune clean). --skip-lint --skip-build avoids the
  # slow unpack-and-build verification — we hand the archive off to
  # opam-ci-check, which does that for real.
  #
  # dune-release names the archive _build/awso-<tag>.tbz (NOT -<version>);
  # -V only controls the version field written into the opam files inside.
  local tag="$1" version="$2"
  local out="$PROJECT_ROOT/_build/awso-$tag.tbz"
  if [ ! -f "$out" ]; then
    echo "[local-opam-ci] dune-release distrib -t $tag -V $version" >&2
    (cd "$PROJECT_ROOT" \
       && dune-release distrib -t "$tag" -V "$version" \
            --skip-lint --skip-build) >&2
  fi
  echo "$out"
}

inject_local_tarball() {
  # inject_local_tarball <tag> <version>
  # Build the distrib archive, copy it into the opam-repo clone (so it lands
  # in opam-ci-check's docker build context), and append a file:// url{} block
  # pointing at its in-container path to each staged opam under <version>.
  local tag="$1" version="$2"
  local tarball sha
  tarball="$(build_local_tarball "$tag" "$version")"
  sha="$(sha256sum "$tarball" | awk '{print $1}')"
  # Stash under awso's package dir / files/ — that subdir is a standard
  # opam-repository convention so `opam repository set-url --strict` won't
  # object, and one copy is enough since opam-ci-check copies the whole
  # opam-repo clone into every container.
  local stash_dir="$OPAM_REPO/packages/awso/awso.$version/files"
  mkdir -p "$stash_dir"
  cp "$tarball" "$stash_dir/awso-$version.tbz"
  local in_container="/home/opam/opam-repository/packages/awso/awso.$version/files/awso-$version.tbz"
  shopt -s nullglob
  local opam pkg dest
  for opam in "$PROJECT_ROOT"/*.opam; do
    pkg="$(basename "$opam" .opam)"
    dest="$OPAM_REPO/packages/$pkg/$pkg.$version/opam"
    [ ! -f "$dest" ] && continue
    cat >>"$dest" <<EOF
url {
  src: "file://$in_container"
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

  # Default --distro/--compiler unless the caller passes them; extract our
  # own --head flag so it doesn't get forwarded to opam-ci-check.
  local extra=()
  local has_distro=0 has_compiler=0 use_head=0
  local rest=()
  for arg in "$@"; do
    case "$arg" in
      --head) use_head=1 ;;
      --distro|--distro=*) has_distro=1; rest+=("$arg") ;;
      --compiler|--compiler=*) has_compiler=1; rest+=("$arg") ;;
      *) rest+=("$arg") ;;
    esac
  done
  set -- "${rest[@]}"
  [ "$has_distro" -eq 0 ] && extra+=(--distro "$DEFAULT_DISTRO")
  [ "$has_compiler" -eq 0 ] && extra+=(--compiler "$DEFAULT_COMPILER")

  local tag version
  if [ "$use_head" -eq 1 ]; then
    # Throwaway tag at HEAD, version "<base>+local-<sha>" so it's obviously
    # not a real release. The tag is deleted on exit (success or failure).
    local base sha head_sha existing
    base="$(latest_release_tag)"
    [ -z "$base" ] && base="0.0.0"
    sha="$(git -C "$PROJECT_ROOT" rev-parse --short=8 HEAD)"
    version="$base+local-$sha"
    tag="local-$sha"
    head_sha="$(git -C "$PROJECT_ROOT" rev-parse HEAD)"
    existing="$(git -C "$PROJECT_ROOT" rev-parse -q --verify "refs/tags/$tag" || true)"
    if [ -z "$existing" ]; then
      git -C "$PROJECT_ROOT" tag "$tag" HEAD
    elif [ "$existing" != "$head_sha" ]; then
      git -C "$PROJECT_ROOT" tag -d "$tag" >/dev/null
      git -C "$PROJECT_ROOT" tag "$tag" HEAD
    fi
    # shellcheck disable=SC2064
    trap "git -C '$PROJECT_ROOT' tag -d '$tag' >/dev/null 2>&1 || true" EXIT
    # Force a rebuild — the same tarball name from a previous --head run on
    # a different HEAD would otherwise be wrongly reused.
    rm -f "$PROJECT_ROOT/_build/awso-$tag.tbz"
    echo "[local-opam-ci] --head: throwaway tag $tag at HEAD, version $version"
  else
    tag="$(latest_release_tag)"
    if [ -z "$tag" ]; then
      echo "[local-opam-ci] no git tags found; tag a release first (dune-release tag)" >&2
      exit 1
    fi
    version="$tag"
    echo "[local-opam-ci] using release tag $tag"
  fi

  stage "$version"
  inject_local_tarball "$tag" "$version"

  cd "$PROJECT_ROOT"
  shopt -s nullglob
  local opam
  for opam in *.opam; do
    local pkg
    pkg="${opam%.opam}"
    echo "[local-opam-ci] building $pkg.$version ..."
    # 'build' takes just <name.version>; src/new attributes are lint-only.
    opam-ci-check build "$pkg.$version" \
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
