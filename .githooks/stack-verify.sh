#!/usr/bin/env bash
# .githooks/stack-verify.sh — verify every stack repo under stacks/ that has a
# configured remote is listed in stacks.csv (and that URLs match).
# Read-only: never modifies anything. Exit 1 if any problem is found.
# Env overrides (tests): STACKS_ROOT, STACKS_MANIFEST
set -euo pipefail

ROOT="${STACKS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MANIFEST="${STACKS_MANIFEST:-$ROOT/stacks.csv}"
cd "$ROOT"
[[ -f "$MANIFEST" ]] || { echo "stack-verify: manifest not found: $MANIFEST" >&2; exit 1; }

declare -A listed
while IFS=';' read -r path url status; do
  path="${path%$'\r'}"; url="${url%$'\r'}"
  [[ -z "$path" || "$path" == \#* || "$path" == "path" ]] && continue
  listed["$path"]="$url"
done < "$MANIFEST"

norm() { # ssh -> https form so git@host:o/r.git == https://host/o/r.git
  local u="${1%/}"
  [[ "$u" =~ ^git@([^:]+):(.+)$ ]] && u="https://${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  [[ "$u" =~ ^ssh://git@([^/]+)/(.+)$ ]] && u="https://${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  echo "${u%.git}"
}

bad=0
repos=()
while IFS= read -r g; do repos+=("${g%/}"); done \
  < <(find stacks -name .git -prune 2>/dev/null | sed 's,\.git$,,' | LC_ALL=C sort)

prev=""
for dir in "${repos[@]}"; do
  # nested repos (submodules like src/ssl-automation/*) belong to their stack
  [[ -n "$prev" && "$dir" == "$prev"/* ]] && continue
  prev="$dir"
  remote="$(git -C "$dir" remote get-url origin 2>/dev/null || true)"
  [[ -z "$remote" ]] && continue
  if [[ -z "${listed[$dir]+x}" ]]; then
    echo "MISSING in manifest: $dir ($remote)"; bad=1
  elif [[ "${listed[$dir]}" == "-" || -z "${listed[$dir]}" ]]; then
    echo "NO URL in manifest: $dir (origin=$remote)"; bad=1
  elif [[ "$(norm "${listed[$dir]}")" != "$(norm "$remote")" ]]; then
    echo "URL MISMATCH: $dir manifest=${listed[$dir]} origin=$remote"; bad=1
  fi
done

for p in "${!listed[@]}"; do
  [[ -e "$p/.git" ]] || echo "NOTE: listed but not cloned: $p" >&2
done
((bad)) && exit 1
echo "stack-verify: OK"
