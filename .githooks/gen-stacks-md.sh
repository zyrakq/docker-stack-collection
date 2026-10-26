#!/usr/bin/env bash
# .githooks/gen-stacks-md.sh — regenerate stacks.md (markdown catalog table)
# from stacks.csv. Idempotent: rewrites the file only when content changes.
#
# Env overrides (used by tests): STACKS_ROOT, STACKS_MANIFEST, STACKS_MD
set -euo pipefail

ROOT="${STACKS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MANIFEST="${STACKS_MANIFEST:-$ROOT/stacks.csv}"
MD="${STACKS_MD:-$ROOT/stacks.md}"

if [[ ! -f "$MANIFEST" ]]; then
  echo "gen-stacks-md: manifest not found: $MANIFEST" >&2
  exit 1
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
{
  printf '# Stack Catalog\n\n'
  printf 'Generated from [`stacks.csv`](stacks.csv) by `.githooks/gen-stacks-md.sh` — do not edit by hand.\n\n'
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
} > "$tmp"
if [[ ! -f "$MD" ]] || ! diff -q "$MD" "$tmp" >/dev/null; then
  mv "$tmp" "$MD"
fi
