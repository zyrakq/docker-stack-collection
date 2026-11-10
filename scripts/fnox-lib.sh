#!/usr/bin/env bash
# Shared helpers for fnox scripts. Source, do not run.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS_DIR="$ROOT/secrets"        # fnox.toml lives here (encrypted, committed)
export FNOX_CONFIG_DIR="${FNOX_CONFIG_DIR:-$HOME/.config/fnox}"
AGE_KEY="${FNOX_AGE_KEY_FILE:-$FNOX_CONFIG_DIR/age.txt}"

need() { command -v "$1" >/dev/null || { echo "missing: $1 (install it yourself, e.g. 'mise use -g $1')" >&2; exit 1; }; }

# resolve_stack <path-or-name> -> absolute dir; sets STACK (profile name)
resolve_stack() {
  local arg="$1" dir
  if [ -d "$arg" ]; then dir="$(cd "$arg" && pwd)"
  elif [ -d "$ROOT/$arg" ]; then dir="$ROOT/$arg"
  else dir="$(find "$ROOT/stacks" -type d -name "$arg" -not -path '*/.git/*' | head -n1)"; fi
  [ -n "${dir:-}" ] && [ -d "$dir" ] || { echo "stack not found: $arg" >&2; exit 1; }
  STACK="$(basename "$dir")"; STACK_DIR="$dir"
}
