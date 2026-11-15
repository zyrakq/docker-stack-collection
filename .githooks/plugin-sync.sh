#!/usr/bin/env bash
# Clone plugin repos listed in plugins.csv (path;url) that are missing. Idempotent.
root="$(git rev-parse --show-toplevel)" || exit 0
tail -n +2 "$root/plugins.csv" | while IFS=';' read -r path url; do
  [[ -z "$path" || "$url" == "-" || -d "$root/$path/.git" ]] && continue
  git clone "$url" "$root/$path" && (cd "$root/$path" && command -v bun >/dev/null && bun install)
done
