#!/usr/bin/env bash
# Clone plugin repos listed in plugins.csv (path;url) that are missing. Idempotent.
root="$(git rev-parse --show-toplevel)" || exit 0
[[ -f "$root/plugins.csv" ]] || exit 0
# Rows under .opencode/global-plugins/ go to ~/.config/opencode/plugins via this symlink.
[[ -e "$root/.opencode/global-plugins" ]] || ln -s "$HOME/.config/opencode/plugins" "$root/.opencode/global-plugins" 2>/dev/null
tail -n +2 "$root/plugins.csv" | while IFS=';' read -r path url; do
  [[ -z "$path" || "$url" == "-" || -d "$root/$path/.git" ]] && continue
  mkdir -p "$(dirname "$root/$path")"
  git clone "$url" "$root/$path" && (cd "$root/$path" && command -v bun >/dev/null && bun install)
done
