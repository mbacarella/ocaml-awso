#!/usr/bin/env bash
# ocaml/ocaml #15161 + #15162 (issue #15160: native array indexing overflows).
# Builds base (the PRs' merge-base) and base + both PRs (Changes conflict:
# keep both entries), then runs the cases in cases.tar.gz (adv.ml: 54
# adversarial cases; adv2.ml: 12 more 1-byte cases; probe.ml: what the
# #15161 tagged/offset cases read or
# write; cases.sh: the runner) plus the PRs' three tests, bytecode vs native,
# on each build, then testsuite/tests/array-functions and the full testsuite.
set -u
# number every line: the launcher prints each distinct console line only once
exec > >(n=0; while IFS= read -r l; do n=$((n+1)); printf '%03d %s\n' $n "$l"; done) 2>&1
W=/root/work/w; mkdir -p "$W/cases"; cd "$W"
tar xzf /root/work/cases.tar.gz -C cases
apt-get install -y -q parallel >/dev/null 2>&1 || echo "no GNU parallel"
echo "kernel $(uname -r) $(uname -m)"
git clone -q --filter=blob:none https://github.com/ocaml/ocaml ocaml
g() { git -C "$W/ocaml" -c user.name=t -c user.email=t@t "$@"; }
g fetch -q origin trunk pull/15161/head:pr15161 pull/15162/head:pr15162
mb=$(g merge-base pr15161 pr15162)
echo "pr15161 $(g rev-parse --short pr15161) pr15162 $(g rev-parse --short pr15162) base $(g rev-parse --short $mb)"
g worktree add -q --detach "$W/base" "$mb"
g worktree add -q --detach "$W/both" "$mb"
git -C both -c user.name=t -c user.email=t@t merge -q --no-edit pr15161
if ! git -C both -c user.name=t -c user.email=t@t merge -q --no-edit pr15162 >/dev/null 2>&1; then
  echo "merge conflicts: $(git -C both diff --name-only --diff-filter=U | tr '\n' ' ')"
  sed -i -e '/^<<<<<<< /d' -e '/^=======$/d' -e '/^>>>>>>> /d' both/Changes
  git -C both add Changes; git -C both -c user.name=t -c user.email=t@t commit -q --no-edit
fi
J=$(( $(nproc) / 2 )); pids=()  # explicit pids: a bare wait would also wait for the numbering process substitution
for b in base both; do
  ( cd $b && s=$(date +%s) && ./configure --enable-ocamltest > ../$b.cfg.log 2>&1 && make -j$J > ../$b.build.log 2>&1 \
      && echo "$b built in $(( $(date +%s) - s ))s" || { tail -n 15 ../$b.build.log; echo "$b BUILD FAILED"; } ) & pids+=($!)
done
wait "${pids[@]}"; pids=()
cp both/testsuite/tests/array-functions/{array_indexing_offset,array_indexing_tagged,checkbound_const_index}.ml cases/
ulimit -c 0
for b in base both; do
  echo "== cases on $b: $(cases/cases.sh "$W/$b" "$W/res-$b")"
  grep '^DIFF' res-$b/diff.txt | sed 's/^DIFF //' | tr '\n' ' '; echo
done
echo "== base native, probe + PR tests (raw output; rc 139 = SIGSEGV, 135 = SIGBUS, 132 = SIGILL)"
grep -E '^(probe|array_indexing|checkbound)' res-base/nat.txt
echo "== base native, adv cases"
grep '^adv' res-base/nat.txt | sed 's/^adv:/  /'
echo "== both native vs byte, PR tests"
grep -E '^(array_indexing|checkbound)' res-both/nat.txt
for b in base both; do
  echo "== testsuite/tests/array-functions on $b"
  make -C $b/testsuite one DIR=tests/array-functions 2>&1 | grep -E 'passed|skipped|failed|=> ' | grep -vE '=> passed' | tail -n 12
done
for b in base both; do
  ( s=$(date +%s); make -j$J -C $b/testsuite parallel > $b.tests.log 2>&1
    echo "== full testsuite on $b ($(( $(date +%s) - s ))s)"
    sed -n '/^Summary:/,/tests considered/p' $b.tests.log ) & pids+=($!)
done
wait "${pids[@]}"; pids=()
# failed / unexpected-error / skipped lists, then the differences
for b in base both; do
  awk '/^List of (failed tests|unexpected errors):/ {on=1; next} /^List of/ || /^$/ || /^Summary/ {on=0} on' $b.tests.log | sort > $b.failed
  awk '/List of skipped tests:/ {on=1; next} /^List of/ || /^$/ || /^Summary/ {on=0} on' $b.tests.log | sort > $b.skipped
done
echo "== failed or errored: base $(wc -l < base.failed), both $(wc -l < both.failed)"; cat both.failed
echo "== failing only in both:"; comm -13 base.failed both.failed
echo "== failing only in base:"; comm -23 base.failed both.failed
echo "== skipped lists identical: $(cmp -s base.skipped both.skipped && echo yes || echo no)"
