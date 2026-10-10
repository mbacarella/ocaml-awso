#!/usr/bin/env bash
# Generic benchmark for an ocaml/ocaml pull request, run on the test box by
# test_ocaml_pr.exe (or by hand: PR=14925 ./bench-pr.sh in a directory
# holding the benchmark programs).
#
# Builds the compiler without and with the PR, compiles every *.ml here
# with each build at four code alignments (so a layout effect can't pass
# for a codegen one), and prints cycles and instructions per program.
#
# env: PR          pull request number (required)
#      BASE        ref to compare against (default: merge-base with trunk);
#                  the PR's commits are cherry-picked onto it, so a release
#                  tag works too (conflicts in Changes take BASE's version)
#      PER_COMMIT  1 = one build per cumulative PR commit instead of just
#                  base and the whole PR
#      FLAMBDA     1 = configure with --enable-flambda
#      J           make jobs per build (default: nproc / number of builds)
#      W           work directory (default ./_bench)
# A program's arguments come from <prog>.args (one line), default none.
set -euo pipefail
: "${PR:?set PR to an ocaml/ocaml pull request number}"
HERE=$(pwd)
W=${W:-$HERE/_bench}
mkdir -p "$W"
say() { echo "$*"; }

[ -d "$W/ocaml/.git" ] || git clone -q --filter=blob:none https://github.com/ocaml/ocaml "$W/ocaml"
git -C "$W/ocaml" fetch -q origin trunk "pull/$PR/head:pr-$PR"
head=$(git -C "$W/ocaml" rev-parse "pr-$PR")
mb=$(git -C "$W/ocaml" merge-base origin/trunk "$head")
base=${BASE:-$mb}
case $base in
  [0-9]*.[0-9]*) git -C "$W/ocaml" fetch -q origin "refs/tags/$base:refs/tags/$base" ;;
esac
commits=$(git -C "$W/ocaml" rev-list --reverse --no-merges "$mb..$head")
[ -n "$commits" ] || { say "PR $PR has no commits over its merge-base"; exit 1; }
say "PR $PR: $(echo $commits | wc -w) commit(s) over $(git -C "$W/ocaml" rev-parse --short "$mb"); base = $base"

# Variants: name -> commits to apply on top of base.
names=(base); applies=("")
if [ "${PER_COMMIT:-0}" = 1 ]; then
  acc=""
  for c in $commits; do
    acc="$acc $c"
    names+=("c$(( ${#names[@]} ))-$(git -C "$W/ocaml" rev-parse --short=7 "$c")"); applies+=("$acc")
  done
else
  names+=(pr); applies+=("$commits")
fi
for i in "${!names[@]}"; do
  [ "$i" = 0 ] && continue
  say "  ${names[$i]}: $(git -C "$W/ocaml" log -1 --format=%s "$(echo ${applies[$i]} | awk '{print $NF}')")"
done

flags=""; [ "${FLAMBDA:-0}" = 1 ] && flags="--enable-flambda"
J=${J:-$(( $(nproc) / ${#names[@]} ))}; [ "$J" -ge 1 ] || J=1
build() {  # build NAME COMMITS...
  local name=$1; shift
  local src=$W/src-$name prefix=$W/inst-$name
  [ -x "$prefix/bin/ocamlopt.opt" ] && return
  rm -rf "$src"; git -C "$W/ocaml" worktree prune
  git -C "$W/ocaml" worktree add -q --detach "$src" "$base"
  for c in "$@"; do
    if ! git -C "$src" cherry-pick -n "$c" >/dev/null 2>&1; then
      git -C "$src" checkout HEAD -- Changes 2>/dev/null || true
      if git -C "$src" diff --name-only --diff-filter=U | grep -q .; then
        echo "$name: $c does not apply onto $base"; return 1
      fi
    fi
    git -C "$src" cherry-pick --quit 2>/dev/null || true
  done
  (cd "$src" && ./configure -q --prefix="$prefix" $flags \
     && make -j"$J" && make install) > "$W/build-$name.log" 2>&1 \
    || { tail -n 20 "$W/build-$name.log"; echo "$name: build failed"; return 1; }
}
say "building ${#names[@]} compilers${flags:+ ($flags)} ..."
pids=()
for i in "${!names[@]}"; do build "${names[$i]}" ${applies[$i]} & pids+=($!); done
for p in "${pids[@]}"; do wait "$p"; done

# Four code alignments: a pad object linked first shifts all code.
for p in 0 16 32 48; do
  printf '__attribute__((used)) void bench_pad(void){ __asm__ volatile(".skip %d, 0"); }\n' \
    $((p + 1)) > "$W/pad$p.c"
  cc -O0 -c "$W/pad$p.c" -o "$W/pad$p.o"
done
ev=cpu_cycles:u
perf stat -x, -e $ev true > /dev/null 2>&1 || ev=cycles:u
count() {  # count EVENT CMD... -> the counter's value
  local e=$1; shift
  perf stat -x, -e "$e" -- "$@" 2>&1 >/dev/null | awk -F, -v e="$e" '$3 == e {print $1; exit}'
}

shopt -s nullglob
progs=("$HERE"/*.ml)
[ ${#progs[@]} -gt 0 ] || { say "no *.ml programs in $HERE"; exit 1; }
for prog in "${progs[@]}"; do
  pn=$(basename "$prog" .ml)
  args=""; [ -f "$HERE/$pn.args" ] && args=$(head -n 1 "$HERE/$pn.args")
  say ""
  say "$pn $args   (Mcycles, min of 3 runs, at code shifts +0/+16/+32/+48; Minstr)"
  printf -v hdr '%-18s %8s %8s %8s %8s %16s %8s' build +0 +16 +32 +48 'median vs base' Minstr; say "$hdr"
  basemed=""
  for v in "${names[@]}"; do
    cyc=()
    for p in 0 16 32 48; do
      d=$W/b-$pn-$v-$p; mkdir -p "$d"; cp "$prog" "$d/"
      (cd "$d" && "$W/inst-$v/bin/ocamlopt.opt" -O3 -ccopt "$W/pad$p.o" -o prog "$pn.ml" 2>/dev/null \
         || "$W/inst-$v/bin/ocamlopt.opt" -ccopt "$W/pad$p.o" -o prog "$pn.ml")
      best=""
      for _ in 1 2 3; do
        c=$(count $ev "$d/prog" $args)
        if [ -z "$best" ] || [ "$c" -lt "$best" ]; then best=$c; fi
      done
      cyc+=($((best / 1000000)))
    done
    med=$(printf '%s\n' "${cyc[@]}" | sort -n | awk '{a[NR]=$1} END {print int((a[2] + a[3]) / 2)}')
    ins=$(( $(count instructions:u "$W/b-$pn-$v-0/prog" $args) / 1000000 ))
    rel=""; [ -n "$basemed" ] && rel=$(awk -v m="$med" -v b="$basemed" 'BEGIN {printf "%+.1f%%", (m / b - 1) * 100}')
    [ -z "$basemed" ] && basemed=$med
    printf -v row '%-18s %8d %8d %8d %8d %16s %8d' "$v" "${cyc[@]}" "$med${rel:+ $rel}" "$ins"
    say "$row"
  done
done
