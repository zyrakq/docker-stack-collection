#!/usr/bin/env bash
# .githooks/stack-sync.test.sh — tests for .githooks/stack-sync.sh
# Run: bash .githooks/stack-sync.test.sh
set -euo pipefail
SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/stack-sync.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

# fixtures: two local "remote" repos
mkdir -p "$T/remotes/a" "$T/remotes/b"
for r in a b; do
  git -C "$T/remotes/$r" init -q
  git -C "$T/remotes/$r" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
done

# fixture: manifest (semicolon-separated CSV, with header) — normal rows, no-url row, comment
mkdir -p "$T/work"
{
  printf 'path;url;status\n'
  printf 'stacks/x/alpha;%s;unverified\n' "$T/remotes/a"
  printf 'stacks/y/beta;%s;incomplete\n' "$T/remotes/b"
  printf 'stacks/z/gamma;-;unverified\n'
  printf '# comment line\n\n'
} > "$T/work/stacks.csv"

# run 1: clones happen, .gitignore + stacks.md generated, header not treated as a path
STACKS_ROOT="$T/work" bash "$SCRIPT"
[[ -d "$T/work/stacks/x/alpha/.git" ]] || fail "alpha not cloned"
[[ -d "$T/work/stacks/y/beta/.git" ]] || fail "beta not cloned"
[[ ! -e "$T/work/stacks/z/gamma" ]] || fail "no-url row must not be cloned"
[[ ! -e "$T/work/path" && ! -e "$T/work/path/" ]] || fail "header row was treated as a path"
grep -qF '# BEGIN stack-sync' "$T/work/.gitignore" || fail "gitignore missing BEGIN marker"
grep -qF '# END stack-sync' "$T/work/.gitignore" || fail "gitignore missing END marker"
grep -qx 'stacks/x/alpha/' "$T/work/.gitignore" || fail "gitignore missing alpha/"
grep -qx 'stacks/y/beta/' "$T/work/.gitignore" || fail "gitignore missing beta/"
grep -qF '| `stacks/x/alpha` | [repo](' "$T/work/stacks.md" || fail "stacks.md missing alpha row"
grep -qF 'unverified ❓' "$T/work/stacks.md" || fail "stacks.md missing status emoji"
grep -qF '| `stacks/z/gamma` | - |' "$T/work/stacks.md" || fail "stacks.md missing no-url row"

# run 2: idempotent — no re-clone, .gitignore and stacks.md unchanged
echo marker > "$T/work/stacks/x/alpha/MARKER"
cp "$T/work/.gitignore" "$T/work/.gitignore.before"
cp "$T/work/stacks.md" "$T/work/stacks.md.before"
STACKS_ROOT="$T/work" bash "$SCRIPT"
diff -q "$T/work/.gitignore" "$T/work/.gitignore.before" >/dev/null || fail ".gitignore changed on second run"
diff -q "$T/work/stacks.md" "$T/work/stacks.md.before" >/dev/null || fail "stacks.md changed on second run"
[[ -f "$T/work/stacks/x/alpha/MARKER" ]] || fail "second run touched existing clone"

# run 3: collision — manifest path exists as a non-directory file → warning, no crash
printf 'stacks/w/delta;%s;incomplete\n' "$T/remotes/a" >> "$T/work/stacks.csv"
mkdir -p "$T/work/stacks/w"
echo notadir > "$T/work/stacks/w/delta"
out="$(STACKS_ROOT="$T/work" bash "$SCRIPT" 2>&1)"
echo "$out" | grep -q "not a directory" || fail "expected collision warning for delta"
grep -qF 'stacks/w/delta' "$T/work/stacks.md" || fail "stacks.md not updated after manifest change"

echo "OK: stack-sync tests passed"
