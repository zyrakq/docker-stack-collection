#!/usr/bin/env bash
# tools/tests/stack-sync.test.sh — tests for tools/stack-sync.sh
# Run: bash tools/tests/stack-sync.test.sh
set -euo pipefail
SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/stack-sync.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

# fixtures: two local "remote" repos
mkdir -p "$T/remotes/a" "$T/remotes/b"
for r in a b; do
  git -C "$T/remotes/$r" init -q
  git -C "$T/remotes/$r" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
done

# fixture: manifest (tab-separated) with normal rows, no-url row, comment
mkdir -p "$T/work"
printf 'stacks/x/alpha\t%s\tdone\n' "$T/remotes/a" > "$T/work/stacks.txt"
printf 'stacks/y/beta\t%s\twip\n' "$T/remotes/b" >> "$T/work/stacks.txt"
printf 'stacks/z/gamma\t-\tdone\n' >> "$T/work/stacks.txt"
printf '# comment line\n\n' >> "$T/work/stacks.txt"

# run 1: clones happen, .gitignore generated
STACKS_ROOT="$T/work" bash "$SCRIPT"
[[ -d "$T/work/stacks/x/alpha/.git" ]] || fail "alpha not cloned"
[[ -d "$T/work/stacks/y/beta/.git" ]] || fail "beta not cloned"
[[ ! -e "$T/work/stacks/z/gamma" ]] || fail "no-url row must not be cloned"
grep -qF '# BEGIN stack-sync' "$T/work/.gitignore" || fail "gitignore missing BEGIN marker"
grep -qF '# END stack-sync' "$T/work/.gitignore" || fail "gitignore missing END marker"
grep -qx 'stacks/x/alpha/' "$T/work/.gitignore" || fail "gitignore missing alpha/"
grep -qx 'stacks/y/beta/' "$T/work/.gitignore" || fail "gitignore missing beta/"

# run 2: idempotent — no re-clone, .gitignore unchanged
echo marker > "$T/work/stacks/x/alpha/MARKER"
cp "$T/work/.gitignore" "$T/work/.gitignore.before"
STACKS_ROOT="$T/work" bash "$SCRIPT"
diff -q "$T/work/.gitignore" "$T/work/.gitignore.before" >/dev/null || fail ".gitignore changed on second run"
[[ -f "$T/work/stacks/x/alpha/MARKER" ]] || fail "second run touched existing clone"

# run 3: collision — manifest path exists as a non-directory file → warning, no crash
printf 'stacks/w/delta\t%s\twip\n' "$T/remotes/a" >> "$T/work/stacks.txt"
mkdir -p "$T/work/stacks/w"
echo notadir > "$T/work/stacks/w/delta"
out="$(STACKS_ROOT="$T/work" bash "$SCRIPT" 2>&1)"
echo "$out" | grep -q "not a directory" || fail "expected collision warning for delta"

echo "OK: stack-sync tests passed"
