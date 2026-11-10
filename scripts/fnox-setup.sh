#!/usr/bin/env bash
# One-time setup: age key + secrets/fnox.toml with age provider.
# Installs nothing: needs `fnox` and `age` (age-keygen) already on PATH.
. "$(dirname "$0")/fnox-lib.sh"
need fnox
KEYGEN="$(command -v age-keygen || command -v rage-keygen || true)"
[ -n "$KEYGEN" ] || { echo "missing: age-keygen or rage-keygen" >&2; exit 1; }

mkdir -p "$(dirname "$AGE_KEY")"
if [ -f "$AGE_KEY" ]; then
  echo "using existing key: $AGE_KEY"
else
  (umask 077 && "$KEYGEN" -o "$AGE_KEY")
  echo
  echo "!! BACK UP $AGE_KEY NOW (e.g. Vaultwarden Secure Note). Lost key = lost secrets."
fi
chmod 600 "$AGE_KEY"
PUB="$("$KEYGEN" -y "$AGE_KEY")"

mkdir -p "$SECRETS_DIR"
CFG="$SECRETS_DIR/fnox.toml"
if [ -f "$CFG" ] && grep -q '^\[providers.age\]' "$CFG"; then
  echo "$CFG already has age provider, leaving as is"
else
  cat >> "$CFG" <<TOML
[providers.age]
type = "age"
recipients = ["$PUB"]
TOML
  echo "wrote $CFG"
fi
echo "recipient: $PUB"
echo "next: scripts/env-push.sh <stack>"
