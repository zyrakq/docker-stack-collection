#!/usr/bin/env bash
# Print one secret value. Usage: secret-get.sh <profile> <KEY>
. "$(dirname "$0")/fnox-lib.sh"
need fnox
[ $# -eq 2 ] || { echo "usage: $0 <profile> <KEY>" >&2; exit 1; }
cd "$SECRETS_DIR"
fnox get "$2" -P "$1"
