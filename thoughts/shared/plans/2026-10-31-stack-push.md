# stack-push.sh Implementation Plan (Mass push)

**Goal:** Add a manual `.githooks/stack-push.sh` that mass-pushes stack repos
that are strictly ahead of their upstream, with per-repo reporting and a final
summary, plus a sibling test suite and a README note.

**Architecture:** One new bash script in `.githooks/` iterating `stacks.csv`
(same parse loop and env-override pattern as `stack-sync.sh`), one new test
script modeled on `stack-sync.test.sh` (mktemp fixture, local bare remotes, no
network), one README section edit. No hooks change — `stack-push.sh` is
explicitly manual and never invoked by post-merge/post-checkout/pre-commit.

**Design:** thoughts/shared/designs/2026-10-26-submodules-to-manifest-design.md,
section "Mass push (`stack-push.sh`)".

---

## Key decisions (gap-fills, documented)

1. **Exit code convention:** exit `1` if any repo is **diverged** or any
   fetch/push **failed**; exit `0` otherwise (missing repos, no-upstream repos
   and `url = -` rows are warnings only). Rationale: diverged is the only state
   that blocks future pushes and needs manual resolution; a non-zero exit makes
   the script usable from cron/CI to flag it. Script misuse (manifest missing)
   also exits `1`.
2. **Push command:** explicit `git push --quiet origin "HEAD:$remote_branch"`
   (remote branch derived from `@{u}` = `origin/<branch>` via `${upstream#*/}`).
   This satisfies the design's "push to the existing upstream branch" and is
   robust against `push.default` configs and differently-named upstreams
   (plain `git push` fails under `push.default=simple` when names differ).
3. **Fetch:** `git fetch --quiet --prune origin` per repo. `--prune` handles
   the "upstream branch deleted remotely" case: the stale `origin/<branch>`
   tracking ref is removed, so `git rev-parse --verify --quiet --abbrev-ref @{u}`
   fails and the repo lands in the **no-upstream** bucket (nothing is pushed).
4. **Behind-only repos** (upstream moved, nothing local): counted as
   `up-to-date` (nothing to push). The design has no bucket for it; this keeps
   counts total without inventing a sixth user-facing state.
5. **Fetch/push failures** get their own `failed` counter and list in the
   summary (design lists 5 buckets; a fetch that fails must not be silently
   dropped, and it must not abort the run — `set -e` is guarded with `if !`).
6. **Manifest `url` field** is only used for the `-` check; the script never
   clones. Fetch/push always go through the repo's own `origin`.
7. **Uncommitted changes:** never touched — no `stash`, no `commit`, no
   `checkout`. Repos are pushed as-is (committed work only), per design.
8. **Nested submodules inside stack repos:** untouched — the script only runs
   `fetch` / `rev-parse` / `rev-list` / `push` at the top level of each repo.
9. **Performance:** serial loop, no parallelism (106 repos, fetch dominates;
   simplicity and readable output win).
10. **Commits:** two commits — (a) script + tests together, (b) README.
    Format per `.gitmessage` (header ≤50 chars verb-initial, blank-line
    separated what/why blocks, what=past tense, why=present tense, English).

---

## Dependency Graph

```
Batch 1 (parallel): 1.1 (.githooks/stack-push.sh), 1.2 (README.md)
Batch 2 (parallel): 2.1 (.githooks/stack-push.test.sh)  [depends: 1.1]
```

---

## Batch 1: Foundation (parallel — 2 implementers)

### Task 1.1: stack-push script
**File:** `.githooks/stack-push.sh` (new; executable, `chmod +x`)
**Test:** created in Task 2.1
**Depends:** none

```bash
#!/usr/bin/env bash
# .githooks/stack-push.sh — mass push of stack repos that are ahead of their
# upstream. Manual script, never invoked by hooks. Never stashes, commits,
# merges or rebases: repos are pushed as-is (committed work only).
#
# Per stacks.csv row (header, comments and url "-" rows are skipped):
#   missing locally          -> reported, skipped
#   fetch origin fails       -> reported as failed, skipped
#   no upstream              -> reported, skipped (also covers an upstream
#                               branch deleted remotely: fetch runs --prune)
#   up to date / behind only -> skipped (nothing to push)
#   ahead only               -> pushed to the existing upstream branch
#   diverged (ahead+behind)  -> NOT pushed, reported for manual resolution
#
# Exit code: 0 when nothing diverged and nothing failed (missing repos and
# missing upstreams are warnings only); 1 when any repo diverged or any
# fetch/push failed.
#
# Env overrides (used by tests): STACKS_ROOT, STACKS_MANIFEST
set -euo pipefail

ROOT="${STACKS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MANIFEST="${STACKS_MANIFEST:-$ROOT/stacks.csv}"

cd "$ROOT"

if [[ ! -f "$MANIFEST" ]]; then
  echo "stack-push: manifest not found: $MANIFEST" >&2
  exit 1
fi

pushed=0 up_to_date=0 diverged=0 no_upstream=0 missing=0 failed=0
diverged_list=() no_upstream_list=() failed_list=()

while IFS=';' read -r path url status; do
  [[ -z "$path" || "$path" == \#* || "$path" == "path" ]] && continue
  if [[ -z "$url" || "$url" == "-" ]]; then
    echo "stack-push: WARN no url for '$path', skipping" >&2
    continue
  fi
  if [[ ! -d "$path" ]] || ! git -C "$path" rev-parse --git-dir >/dev/null 2>&1; then
    echo "stack-push: WARN missing repo '$path', skipping" >&2
    missing=$((missing + 1)); missing_list+=("$path")
    continue
  fi
  if ! git -C "$path" fetch --quiet --prune origin < /dev/null; then
    echo "stack-push: WARN fetch failed for '$path', skipping" >&2
    failed=$((failed + 1)); failed_list+=("$path")
    continue
  fi
  if ! upstream="$(git -C "$path" rev-parse --verify --quiet --abbrev-ref '@{u}' 2>/dev/null)"; then
    echo "stack-push: WARN no upstream for '$path', skipping" >&2
    no_upstream=$((no_upstream + 1)); no_upstream_list+=("$path")
    continue
  fi
  ahead="$(git -C "$path" rev-list --count '@{u}..HEAD')"
  behind="$(git -C "$path" rev-list --count 'HEAD..@{u}')"
  if [[ "$ahead" -eq 0 ]]; then
    up_to_date=$((up_to_date + 1))  # up to date or behind only — nothing to push
  elif [[ "$behind" -gt 0 ]]; then
    echo "stack-push: WARN diverged from '$upstream' (ahead $ahead, behind $behind), not pushing: '$path'" >&2
    diverged=$((diverged + 1)); diverged_list+=("$path")
  else
    remote_branch="${upstream#*/}"
    if git -C "$path" push --quiet origin "HEAD:$remote_branch" < /dev/null; then
      pushed=$((pushed + 1))
    else
      echo "stack-push: WARN push failed for '$path'" >&2
      failed=$((failed + 1)); failed_list+=("$path")
    fi
  fi
done < "$MANIFEST"

echo "stack-push: summary: pushed=$pushed up-to-date=$up_to_date diverged=$diverged no-upstream=$no_upstream missing=$missing failed=$failed"
if [[ "$diverged" -gt 0 ]]; then
  echo "stack-push: diverged (not pushed, resolve manually):"
  for p in "${diverged_list[@]}"; do echo "stack-push:   $p"; done
fi
if [[ "$no_upstream" -gt 0 ]]; then
  echo "stack-push: no upstream configured:"
  for p in "${no_upstream_list[@]}"; do echo "stack-push:   $p"; done
fi
if [[ "$failed" -gt 0 ]]; then
  echo "stack-push: failed (fetch/push error):"
  for p in "${failed_list[@]}"; do echo "stack-push:   $p"; done
fi

[[ "$diverged" -eq 0 && "$failed" -eq 0 ]]
```

Implementation notes for the implementer:
- The final `[[ ... ]]` line is the exit status (0 unless diverged/failed).
- `< /dev/null` on fetch/push prevents credential-prompt hangs, matching
  `stack-sync.sh`'s clone pattern.
- Counters survive the loop because the manifest is redirected (`done <`),
  not piped — same as `stack-sync.sh`.
- `status` is read but unused, mirroring `stack-sync.sh` line 24.
- Do NOT add this script to any hook file. It stays manual.

**Verify (no test yet):**
```bash
chmod +x .githooks/stack-push.sh
bash -n .githooks/stack-push.sh                       # syntax check, no output
: > /tmp/opencode/empty.csv
STACKS_MANIFEST=/tmp/opencode/empty.csv bash .githooks/stack-push.sh; echo "exit=$?"
# expected output:
# stack-push: summary: pushed=0 up-to-date=0 diverged=0 no-upstream=0 missing=0 failed=0
# exit=0
```
**Commit:** none yet — committed together with the test in Task 2.1.

---

### Task 1.2: README section
**File:** `README.md` (edit the "🔧 Working on a stack" section only)
**Depends:** none (references the script by name only)

Replace the current section body (lines 31–41) with:

```markdown
## 🔧 Working on a stack

Each stack is a normal independent git repo with `docker-compose.yml`,
`.env.example`, and its own `README.md`. The catalog only clones what is
missing — updates are manual, per repo:

```bash
cd stacks/<category>/<...>/<stack>
git pull && git push
cp .env.example .env && docker compose up -d
```

To push committed work in **all** stacks at once, run the manual mass-push
script (never fires automatically; never stashes or commits anything):

```bash
.githooks/stack-push.sh
```

It fetches every repo and pushes only the ones strictly ahead of their
upstream. Diverged repos, repos without an upstream, and missing repos are
reported and left for manual follow-up.
```

Everything above and below the section stays byte-identical (README is ~47
lines; net growth ≈ 10 lines).

**Verify:**
```bash
grep -c 'stack-push.sh' README.md        # expected: 2
grep -q '## 🔧 Working on a stack' README.md && echo section-ok   # section-ok
```
**Commit:** none yet — committed in the second commit after Task 2.1.

---

## Batch 2: Test suite (1 implementer)

### Task 2.1: test suite
**File:** `.githooks/stack-push.test.sh` (new; sibling of `stack-sync.test.sh`)
**Depends:** 1.1 (runs the script)

Fixture layout (all local, no network):
- `$T/remotes/<name>.git` — bare remotes seeded with one `init` commit on `main`
- `$T/work/stacks.csv` — manifest with header, comment, `url -` row
- `$T/work/stacks/...` — five clones in four states:
  - `alpha` up-to-date
  - `beta` ahead 1 (+ an uncommitted `DIRTY` file that must survive)
  - `epsilon` diverged (local commit + a second clone pushing a remote commit)
  - `zeta` upstream unset locally (`git branch --unset-upstream`)
  - `eta` upstream branch deleted remotely (push, then `push --delete`)
- `delta` row with no local clone → missing

```bash
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
[[ "$(git -C "$T/remotes/epsilon.git" log -1 --format=%s main)" == "init" ]] \
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
```

Coverage checklist (all required cases from the task):
- up-to-date skip (alpha, runs 1–3) ✓
- ahead-only push (beta, remote tip asserted) ✓
- diverged report-no-push (epsilon, remote tip asserted unchanged) ✓
- `url -` skip (gamma) ✓
- missing repo report (delta) ✓
- no-upstream report — both unset (zeta) and deleted-remotely (eta, via
  `fetch --prune`) ✓
- summary counts (runs 1, 2, 3) ✓
- exit codes: 1 with diverged, 0 clean ✓
- uncommitted changes untouched (DIRTY file + porcelain status) ✓
- header/comment rows ignored (no `path` dir created, no crash) ✓

**Verify:**
```bash
bash .githooks/stack-push.test.sh
# expected output: OK: stack-push tests passed
bash .githooks/stack-sync.test.sh
# expected output: OK: stack-sync tests passed   (regression — sync untouched)
```

**Commits (run after this task passes, from repo root):**

Commit 1 — script + tests:
```bash
git add .githooks/stack-push.sh .githooks/stack-push.test.sh
git commit -m "$(cat <<'MSG'
Add stack-push.sh for mass pushing stack repos

Added .githooks/stack-push.sh to push stack repos that are ahead of
their upstream and added stack-push.test.sh covering push, diverged,
no-upstream, missing and summary cases

Provides a manual mass push across ~100 independent repos without
touching diverged or unconfigured repos and keeps hooks push-free
MSG
)"
```

Commit 2 — README:
```bash
git add README.md
git commit -m "$(cat <<'MSG'
Document mass push in the README

Added the stack-push.sh command to the "Working on a stack" section

Enables pushing committed work in all stacks with one manual command
MSG
)"
```

Both headers ≤50 chars, verb-initial; what-block past tense, why-block present
tense, blank-line separated — per `.gitmessage`. The pre-commit hook regenerates
`stacks.md` only when `stacks.csv` changes — neither commit touches it, so it is
a no-op.

---

## Final verification (after both commits)

```bash
bash .githooks/stack-push.test.sh     # OK: stack-push tests passed
bash .githooks/stack-sync.test.sh     # OK: stack-sync tests passed
rtk git status                        # clean except untracked stacks/ (ignored)
rtk git log --oneline -2              # the two commits above
```

**Do NOT run `.githooks/stack-push.sh` bare against the real tree during
verification** — it would push up to ~100 real repos to GitHub. The real-tree
smoke check is the `STACKS_MANIFEST=/tmp/opencode/empty.csv` run in Task 1.1.
Running it for real is a deliberate, separate operator action.
