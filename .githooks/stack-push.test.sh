#!/usr/bin/env bash
# .githooks/stack-push.test.sh — tests for .githooks/stack-push.sh
# Run: bash .githooks/stack-push.test.sh
set -euo pipefail
SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/stack-push.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
commit() { git -C "$1" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "$2"; }

# fixtures: local bare "remotes", each seeded with one commit on main
mkdir -p "$T/remotes" "$T/work/stacks"
make_remote() {
  git init -q --bare -b main "$T/remotes/$1.git"
  git init -q -b main "$T/seed-$1"
  commit "$T/seed-$1" init
  git -C "$T/seed-$1" push -q "$T/remotes/$1.git" main
}
for r in alpha beta epsilon zeta eta; do make_remote "$r"; done

# clones: alpha up-to-date, beta will be ahead, epsilon will diverge,
# zeta gets no upstream, eta's upstream branch gets deleted remotely
git clone -q "$T/remotes/alpha.git"   "$T/work/stacks/x/alpha"
git clone -q "$T/remotes/beta.git"    "$T/work/stacks/y/beta"
git clone -q "$T/remotes/epsilon.git" "$T/work/stacks/v/epsilon"
git clone -q "$T/remotes/zeta.git"    "$T/work/stacks/u/zeta"
git clone -q "$T/remotes/eta.git"     "$T/work/stacks/t/eta"

commit "$T/work/stacks/y/beta" ahead
echo dirty > "$T/work/stacks/y/beta/DIRTY"          # uncommitted, must survive
commit "$T/work/stacks/v/epsilon" local
git clone -q "$T/remotes/epsilon.git" "$T/seed-eps2"
commit "$T/seed-eps2" remote
git -C "$T/seed-eps2" push -q origin main           # epsilon: ahead AND behind
git -C "$T/work/stacks/u/zeta" branch -q --unset-upstream
commit "$T/work/stacks/t/eta" eta-ahead
git -C "$T/work/stacks/t/eta" push -q origin main
git -C "$T/remotes/eta.git" config receive.denyDeleteCurrent ignore
git -C "$T/work/stacks/t/eta" push -q origin --delete main  # upstream gone

# fixture: manifest — header, normal rows, no-url row, comment, missing repo
{
  printf 'path;url;status\n'
  printf 'stacks/x/alpha;%s;unverified\n'   "$T/remotes/alpha.git"
  printf 'stacks/y/beta;%s;incomplete\n'    "$T/remotes/beta.git"
  printf 'stacks/z/gamma;-;unverified\n'
  printf 'stacks/w/delta;%s;incomplete\n'   "$T/remotes/alpha.git"
  printf 'stacks/v/epsilon;%s;unverified\n' "$T/remotes/epsilon.git"
  printf 'stacks/u/zeta;%s;unverified\n'    "$T/remotes/zeta.git"
  printf 'stacks/t/eta;%s;unverified\n'     "$T/remotes/eta.git"
  printf '# comment line\n\n'
} > "$T/work/stacks.csv"

# run 1: beta pushed, epsilon diverged (exit 1), others reported/skipped
rc=0
out="$(STACKS_ROOT="$T/work" bash "$SCRIPT" 2>&1)" || rc=$?
[[ "$rc" -eq 1 ]] || fail "expected exit 1 with a diverged repo, got $rc"
grep -q "pushed=1 up-to-date=1 diverged=1 no-upstream=2 missing=1 failed=0" <<<"$out" \
  || fail "wrong summary counts: $out"
grep -q "not pushing: 'stacks/v/epsilon'" <<<"$out" || fail "epsilon not reported diverged"
grep -q "missing repo 'stacks/w/delta'" <<<"$out" || fail "delta not reported missing"
grep -q "no url for 'stacks/z/gamma'" <<<"$out" || fail "gamma (url -) not reported"
grep -q "no upstream for 'stacks/u/zeta'" <<<"$out" || fail "zeta not reported no-upstream"
grep -q "no upstream for 'stacks/t/eta'" <<<"$out" || fail "eta not reported no-upstream"
[[ "$(git -C "$T/remotes/beta.git" log -1 --format=%s main)" == "ahead" ]] \
  || fail "beta commit not pushed to remote"
[[ "$(git -C "$T/remotes/epsilon.git" log -1 --format=%s main)" == "remote" ]] \
  || fail "epsilon remote was modified despite divergence"
[[ -f "$T/work/stacks/y/beta/DIRTY" ]] || fail "uncommitted file lost"
[[ -n "$(git -C "$T/work/stacks/y/beta" status --porcelain)" ]] || fail "dirty state lost"

# run 2: idempotent — beta now up to date, nothing pushed again
rc=0
out="$(STACKS_ROOT="$T/work" bash "$SCRIPT" 2>&1)" || rc=$?
[[ "$rc" -eq 1 ]] || fail "expected exit 1 on second run, got $rc"
grep -q "pushed=0 up-to-date=2 diverged=1 no-upstream=2 missing=1 failed=0" <<<"$out" \
  || fail "wrong summary counts on second run: $out"

# run 3: clean manifest — nothing to do, exit 0
printf 'path;url;status\nstacks/x/alpha;%s;unverified\n' "$T/remotes/alpha.git" \
  > "$T/work/stacks2.csv"
out="$(STACKS_ROOT="$T/work" STACKS_MANIFEST="$T/work/stacks2.csv" bash "$SCRIPT" 2>&1)"
grep -q "pushed=0 up-to-date=1 diverged=0 no-upstream=0 missing=0 failed=0" <<<"$out" \
  || fail "wrong summary counts for clean run: $out"

echo "OK: stack-push tests passed"
