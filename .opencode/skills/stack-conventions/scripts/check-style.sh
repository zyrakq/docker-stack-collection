#!/usr/bin/env bash
# Usage: check-style.sh <stack-dir>   yaml_merger / comments violations; exit 1 if any.
set -u
d=$(cd "${1:?stack dir}" && pwd)
bad=0
v() { echo "VIOLATION: $*"; bad=1; }
prune=( \( -name .git -o -name build -o -name node_modules -o -name modules \) -prune -o )

while IFS= read -r t; do
  rel=${t#"$d"/}
  grep -Eq '^[[:space:]]*yaml_merger[[:space:]]*=[[:space:]]*"(python|[^r"][^"]*)"' "$t" && v "yaml_merger set in $rel"
  grep -Eq '^[[:space:]]*#' "$t" && v "comments in $rel"
done < <(find "$d" "${prune[@]}" -type f -name stackbuilder.toml -print)

while IFS= read -r c; do
  grep -Eq '^[[:space:]]*#' "$c" && v "comments in ${c#"$d"/}"
done < <(find "$d" "${prune[@]}" -type f \( -name 'docker-compose*.yml' -o -name 'docker-compose*.yaml' \) -path '*/components/*' -print)

exit $bad
