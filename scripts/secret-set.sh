#!/usr/bin/env bash
# Store one secret (value read from stdin, never argv). Usage: printf %s "$v" | secret-set.sh <profile> <KEY>
. "$(dirname "$0")/fnox-lib.sh"
need fnox
[ $# -eq 2 ] || { echo "usage: $0 <profile> <KEY>  (value on stdin)" >&2; exit 1; }
VALUE="$(cat)"; [ -n "$VALUE" ] || { echo "empty value on stdin" >&2; exit 1; }
cd "$SECRETS_DIR"
fnox set "$2" "$VALUE" -p age -P "$1"
echo "stored $2 in profile $1; commit secrets/fnox.toml"
