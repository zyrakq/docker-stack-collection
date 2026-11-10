#!/usr/bin/env bash
# Encrypt <stack>/.env into secrets/fnox.toml under profile <stack>.
# Usage: env-push.sh <stack-name|path> [file=.env]
. "$(dirname "$0")/fnox-lib.sh"
need fnox
[ $# -ge 1 ] || { echo "usage: $0 <stack> [env-file]" >&2; exit 1; }
resolve_stack "$1"
FILE="${2:-.env}"; [ "${FILE#/}" = "$FILE" ] && FILE="$STACK_DIR/$FILE"
[ -f "$FILE" ] || { echo "no such file: $FILE" >&2; exit 1; }
cd "$SECRETS_DIR"
fnox import -i "$FILE" -p age -P "$STACK" --force
echo "pushed $FILE -> secrets/fnox.toml [profile $STACK]; commit secrets/fnox.toml"
