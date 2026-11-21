#!/usr/bin/env bash
# Rewrite url to the transport (ssh/https) of the host repo's origin.
norm_url() {
  local u="$1" o
  o="$(git -C "${root:-.}" remote get-url origin 2>/dev/null)" || { printf '%s' "$u"; return 0; }
  if [[ "$o" == git@* || "$o" == ssh://* ]] && [[ "$u" =~ ^https?://([^/]+)/(.+)$ ]]; then
    printf 'git@%s:%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
  elif [[ "$o" == http://* || "$o" == https://* ]] && [[ "$u" =~ ^git@([^:]+):(.+)$ ]]; then
    printf 'https://%s/%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
  else
    printf '%s' "$u"
  fi
}
# Clone plugin repos listed in plugins.csv (path;url) that are missing. Idempotent.
root="$(git rev-parse --show-toplevel)" || exit 0
[[ -f "$root/plugins.csv" ]] || exit 0
# Rows under .opencode/global-plugins/ go to ~/.config/opencode/plugins via this symlink.
gdir="$HOME/.config/opencode/plugins"
if grep -q '^\.opencode/global-plugins/' "$root/plugins.csv"; then
  mkdir -p "$gdir" "$root/.opencode"
  # -L catches dangling symlinks; never mkdir over an existing link.
  [[ -L "$root/.opencode/global-plugins" || -e "$root/.opencode/global-plugins" ]] || ln -s "$gdir" "$root/.opencode/global-plugins"
fi
tail -n +2 "$root/plugins.csv" | while IFS=';' read -r path url; do
  [[ -z "$path" || "$url" == "-" || -d "$root/$path/.git" ]] && continue
  mkdir -p "$(dirname "$root/$path")"
  git clone "$(norm_url "$url")" "$root/$path" && (cd "$root/$path" && command -v bun >/dev/null && bun install)
done
