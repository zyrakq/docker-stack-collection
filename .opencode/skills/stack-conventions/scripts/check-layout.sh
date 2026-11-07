#!/usr/bin/env bash
# Usage: check-layout.sh <stack-dir>   Layout/artifact violations; exit 1 if any.
set -u
d=$(cd "${1:?stack dir}" && pwd)
bad=0
v() { echo "VIOLATION: $*"; bad=1; }
prune=( \( -name .git -o -name build -o -name node_modules -o -name modules \) -prune -o )

while IFS= read -r f; do
  v "ports in base compose: ${f#"$d"/}"
done < <(find "$d" "${prune[@]}" -type f -path '*/components/base/docker-compose*.y*ml' -print |
  while IFS= read -r f; do grep -Eq '^[[:space:]]*ports:' "$f" && echo "$f"; done)

while IFS= read -r f; do
  v ".env inside components (never create/run there): ${f#"$d"/}"
done < <(find "$d" "${prune[@]}" -type f -name .env -path '*/components/*' -print)

while IFS= read -r f; do
  v ".env outside build/<env>/<combo>: ${f#"$d"/}"
done < <(find "$d" "${prune[@]}" -type f -name .env -not -path '*/components/*' -print)

while IFS= read -r e; do
  [[ -f $e/.env.example ]] || v ".env.example missing: ${e#"$d"/}"
done < <(find "$d" "${prune[@]}" -type d -path '*/components/environments/*' -print | grep -E '/components/environments/[^/]+$')

while IFS= read -r s; do
  v ".stackbuilder present (must not be left or committed): ${s#"$d"/}"
done < <(find "$d" \( -name .git -o -name node_modules \) -prune -o -type d -name .stackbuilder -print)

while IFS= read -r x; do
  b=${x##*/}
  [[ $b == step-ca-trust || $b =~ ^[^-]+(-[^-]+)?$ ]] || v "extension name too long (max 2 words): ${x#"$d"/}"
done < <(find "$d" "${prune[@]}" -type d -path '*/components/extensions/*' -print | grep -E '/components/extensions/[^/]+$')

if find "$d" "${prune[@]}" -type d \( -path '*/components/environments/letsencrypt' -o -path '*/components/environments/step-ca' \) -print | grep -q .; then
  for m in letsencrypt-manager step-ca-manager; do
    git -C "$d" config -f .gitmodules --get "submodule.modules/ssl-automation/$m.path" >/dev/null 2>&1 \
      || v "SSL environment present but submodule not in .gitmodules: modules/ssl-automation/$m"
    [[ -e $d/modules/ssl-automation/$m/.git ]] \
      || v "SSL submodule not initialized/present: modules/ssl-automation/$m"
  done
fi

exit $bad
