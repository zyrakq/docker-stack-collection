#!/usr/bin/env bash
# Clone kit repos listed in kits.csv (path;url) that are missing. Idempotent.
root="$(git rev-parse --show-toplevel)" || exit 0
tail -n +2 "$root/kits.csv" | while IFS=';' read -r path url; do
  [[ -z "$path" || "$url" == "-" || -d "$root/$path/.git" ]] && continue
  git clone "$url" "$root/$path" && (cd "$root/$path" && command -v bun >/dev/null && bun install)
done
