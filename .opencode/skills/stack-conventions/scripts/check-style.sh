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

while IFS= read -r c; do
  grep -Eq '\$\{[A-Za-z_][A-Za-z0-9_]*:\?[^}]' "$c" && v "text after :? in ${c#"$d"/}"
done < <(find "$d" "${prune[@]}" -type f \( -name 'docker-compose*.yml' -o -name 'docker-compose*.yaml' \) -path '*/components/*' -print)

while IFS= read -r e; do
  rel=${e#"$d"/}
  prev=""
  n=0
  while IFS= read -r line || [[ -n $line ]]; do
    n=$((n+1))
    if [[ $line =~ ^[[:space:]]*# ]]; then
      :
    elif [[ $line =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      k=${BASH_REMATCH[1]}; val=${BASH_REMATCH[2]}
      if [[ $k =~ (PASSWORD|SECRET|TOKEN|KEY|SALT) ]]; then
        [[ -z $val ]] && v "empty secret $k in $rel:$n"
        [[ -n $val && ! $prev =~ ^[[:space:]]*#[[:space:]]*[a-z] ]] && v "secret $k lacks generator comment above in $rel:$n"
      fi
    fi
    if [[ $line =~ ^[[:space:]]*# ]]; then
      cmd=${line#\#}; cmd=${cmd# }
      [[ $cmd =~ ^(openssl|head|tr|pwgen|uuidgen|python3?|base64|dd|date|cat|node|xxd|gen) ]] || v "non-generator comment in $rel:$n"
    fi
    prev=$line
  done < "$e"
done < <(find "$d" "${prune[@]}" -type f -name .env.example -path '*/components/*' -print)

exit $bad
