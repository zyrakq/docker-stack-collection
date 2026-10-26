#!/usr/bin/env bash
# .githooks/stack-sync.sh — clone missing stack repos from stacks.csv and
# regenerate the managed section of .gitignore plus the stacks.md catalog page.
# Idempotent: safe to run any number of times.
# NEVER pulls/pushes/merges inside stack repos and never deletes anything.
#
# Env overrides (used by tests): STACKS_ROOT, STACKS_MANIFEST, STACKS_GITIGNORE,
# STACKS_MD
set -euo pipefail

ROOT="${STACKS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MANIFEST="${STACKS_MANIFEST:-$ROOT/stacks.csv}"
GITIGNORE="${STACKS_GITIGNORE:-$ROOT/.gitignore}"
MD="${STACKS_MD:-$ROOT/stacks.md}"
BEGIN_MARK="# BEGIN stack-sync (generated - do not edit)"
END_MARK="# END stack-sync"

cd "$ROOT"

if [[ ! -f "$MANIFEST" ]]; then
  echo "stack-sync: manifest not found: $MANIFEST" >&2
  exit 1
fi

# --- 1. clone missing repos ------------------------------------------------
while IFS=';' read -r path url status; do
  [[ -z "$path" || "$path" == \#* || "$path" == "path" ]] && continue
  if [[ -z "$url" || "$url" == "-" ]]; then
    echo "stack-sync: WARN no url for '$path', skipping" >&2
    continue
  fi
  if [[ -d "$path" ]]; then
    continue  # already present — nothing to do
  fi
  if [[ -e "$path" ]]; then
    echo "stack-sync: WARN '$path' exists and is not a directory, skipping" >&2
    continue
  fi
  mkdir -p "$(dirname "$path")"
  if ! git clone --quiet "$url" "$path" < /dev/null; then
    echo "stack-sync: WARN clone failed for '$path' ($url)" >&2
  fi
done < "$MANIFEST"

# --- 2. regenerate managed .gitignore section ------------------------------
block_file="$(mktemp)"
new_file="$(mktemp)"
md_file="$(mktemp)"
trap 'rm -f "$block_file" "$new_file" "$md_file"' EXIT
{
  printf '%s\n' "$BEGIN_MARK"
  awk -F';' '$1 != "" && $1 !~ /^#/ && $1 != "path" { print $1 "/" }' "$MANIFEST" | sort -u
  printf '%s\n' "$END_MARK"
} > "$block_file"

if [[ -f "$GITIGNORE" ]] && grep -qF "$BEGIN_MARK" "$GITIGNORE"; then
  awk -v block="$block_file" '
    BEGIN { n = 0; while ((getline l < block) > 0) B[n++] = l; close(block) }
    $0 == B[0] { for (i = 0; i < n; i++) print B[i]; inblk = 1; next }
    inblk && $0 == B[n-1] { inblk = 0; next }
    !inblk { print }
  ' "$GITIGNORE" > "$new_file"
elif [[ -f "$GITIGNORE" ]]; then
  { cat "$GITIGNORE"; echo ""; cat "$block_file"; } > "$new_file"
else
  cp "$block_file" "$new_file"
fi
mv "$new_file" "$GITIGNORE"

# --- 3. regenerate stacks.md catalog page -----------------------------------
{
  printf '# Stack Catalog\n\n'
  printf 'Generated from [`stacks.csv`](stacks.csv) by `.githooks/stack-sync.sh` — do not edit by hand.\n\n'
  printf '| path | url | status |\n'
  printf '|------|-----|--------|\n'
  awk -F';' '
    $1 == "" || $1 ~ /^#/ || $1 == "path" { next }
    {
      url_cell = "-"
      if ($2 != "" && $2 != "-") url_cell = "[repo](" $2 ")"
      status_cell = $3
      if ($3 == "unverified")  status_cell = "unverified ❓"
      if ($3 == "incomplete")  status_cell = "incomplete 🚧"
      if ($3 == "completed")   status_cell = "completed ✅"
      gsub(/\|/, "\\|", $1)
      print "| `" $1 "` | " url_cell " | " status_cell " |"
    }
  ' "$MANIFEST"
} > "$md_file"
if [[ ! -f "$MD" ]] || ! diff -q "$MD" "$md_file" >/dev/null; then
  mv "$md_file" "$MD"
fi
