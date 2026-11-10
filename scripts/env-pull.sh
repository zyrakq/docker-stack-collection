#!/usr/bin/env bash
# Decrypt profile <stack> from secrets/fnox.toml into <stack>/.env (mode 600).
# Usage: env-pull.sh <stack-name|path> [file=.env]
. "$(dirname "$0")/fnox-lib.sh"
need fnox
[ $# -ge 1 ] || { echo "usage: $0 <stack> [env-file]" >&2; exit 1; }
resolve_stack "$1"
FILE="${2:-.env}"; [ "${FILE#/}" = "$FILE" ] && FILE="$STACK_DIR/$FILE"
if [ -e "$FILE" ] && [ -z "${FORCE:-}" ]; then echo "$FILE exists; rerun with FORCE=1 to overwrite" >&2; exit 1; fi
cd "$SECRETS_DIR"
rm -f "$FILE"
(umask 077 && fnox export --all -P "$STACK" -o "$FILE")
echo "pulled profile $STACK -> $FILE"
