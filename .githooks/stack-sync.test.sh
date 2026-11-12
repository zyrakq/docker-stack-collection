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

# fixture: work repo with tracked .gitignore/stacks.md; manifest with header, no-url row, comment
mkdir -p "$T/work"
git -C "$T/work" init -q
echo ".env" > "$T/work/.gitignore"
echo "catalog" > "$T/work/stacks.md"
{
  printf 'path;url;status\n'
  printf 'stacks/x/alpha;%s;unverified\n' "$T/remotes/a"
  printf 'stacks/y/beta;%s;incomplete\n' "$T/remotes/b"
  printf 'stacks/z/gamma;-;unverified\n'
  printf '# comment line\n\n'
} > "$T/work/stacks.csv"
EXC="$T/work/.git/info/exclude"

# run 1: clones, exclude block written, tracked files untouched
STACKS_ROOT="$T/work" bash "$SCRIPT"
[[ -d "$T/work/stacks/x/alpha/.git" ]] || fail "alpha not cloned"
[[ -d "$T/work/stacks/y/beta/.git" ]] || fail "beta not cloned"
[[ ! -e "$T/work/stacks/z/gamma" ]] || fail "no-url row must not be cloned"
[[ ! -e "$T/work/path" ]] || fail "header row was treated as a path"
grep -qF '# BEGIN stack-sync' "$EXC" || fail "exclude missing BEGIN marker"
grep -qF '# END stack-sync' "$EXC" || fail "exclude missing END marker"
grep -qx 'stacks/x/alpha/' "$EXC" || fail "exclude missing alpha/"
grep -qx 'stacks/y/beta/' "$EXC" || fail "exclude missing beta/"
[[ "$(cat "$T/work/.gitignore")" == ".env" ]] || fail ".gitignore modified"
[[ "$(cat "$T/work/stacks.md")" == "catalog" ]] || fail "stacks.md modified"
git -C "$T/work" add -A
[[ "$(git -C "$T/work" ls-files | grep -c '^stacks/' || true)" == "0" ]] || fail "stack dirs not ignored"

# run 2: idempotent — no re-clone, exclude unchanged, one block only
echo marker > "$T/work/stacks/x/alpha/MARKER"
cp "$EXC" "$EXC.before"
STACKS_ROOT="$T/work" bash "$SCRIPT"
diff -q "$EXC" "$EXC.before" >/dev/null || fail "exclude changed on second run"
[[ "$(grep -c 'BEGIN stack-sync' "$EXC")" == "1" ]] || fail "duplicate block"
[[ -f "$T/work/stacks/x/alpha/MARKER" ]] || fail "second run touched existing clone"

# run 3: new row appears after a "pull" → cloned, exclude updated
printf 'stacks/n/new;%s;incomplete\n' "$T/remotes/b" >> "$T/work/stacks.csv"
STACKS_ROOT="$T/work" bash "$SCRIPT"
[[ -d "$T/work/stacks/n/new/.git" ]] || fail "new stack not cloned"
grep -qx 'stacks/n/new/' "$EXC" || fail "exclude missing new/"

# run 4: collision — path is a file → warning
printf 'stacks/w/delta;%s;incomplete\n' "$T/remotes/a" >> "$T/work/stacks.csv"
mkdir -p "$T/work/stacks/w"
echo notadir > "$T/work/stacks/w/delta"
out="$(STACKS_ROOT="$T/work" bash "$SCRIPT" 2>&1)"
echo "$out" | grep -q "not a directory" || fail "expected collision warning for delta"

# run 5: empty existing dir → cloned into; non-empty dir without .git → warn, skipped
printf 'stacks/e/empty;%s;incomplete\n' "$T/remotes/a" >> "$T/work/stacks.csv"
printf 'stacks/f/full;%s;incomplete\n' "$T/remotes/a" >> "$T/work/stacks.csv"
mkdir -p "$T/work/stacks/e/empty" "$T/work/stacks/f/full"
touch "$T/work/stacks/f/full/.gitkeep"
out="$(STACKS_ROOT="$T/work" bash "$SCRIPT" 2>&1)"
[[ -d "$T/work/stacks/e/empty/.git" ]] || fail "empty dir not cloned into"
[[ ! -e "$T/work/stacks/f/full/.git" ]] || fail "non-empty dir must not be cloned into"
echo "$out" | grep -q "non-empty directory" || fail "expected non-empty warning"

echo "OK: stack-sync tests passed"
