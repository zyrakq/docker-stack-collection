#!/usr/bin/env bash
# Usage: check-stack.sh <stack-dir>   Prints only violations; exit 1 if any.
set -u
d=$(cd "${1:?stack dir}" && pwd)
bad=0
v() { echo "VIOLATION: $*"; bad=1; }
[[ $(basename "$d") == *-stack ]] && v "folder name has -stack suffix"
[[ -f $d/.vscode/settings.json ]] || v ".vscode/settings.json missing"

while IFS= read -r dir; do
  rel=${dir#"$d"/}; [[ $dir == "$d" ]] && rel=.
  nfiles=$(find "$dir" -maxdepth 1 -type f ! -name .gitkeep | wc -l)
  nsubs=$(find "$dir" -maxdepth 1 -mindepth 1 -type d ! -name .git -exec test ! -e {}/.git \; -print | wc -l)
  need=0; [[ $nsubs -eq 1 && $nfiles -eq 0 ]] && need=1
  if [[ -f $dir/.gitkeep ]]; then
    if [[ $nfiles -gt 0 ]]; then v ".gitkeep in dir with files: $rel"
    elif [[ $need -eq 0 ]]; then v ".gitkeep in dir with $nsubs subdirs (not exactly one): $rel"
    fi
  elif [[ $need -eq 1 && $rel != . ]]; then
    v ".gitkeep missing (exactly one subdir): $rel"
  fi
done < <(find "$d" -mindepth 0 \( -name .git -o -name .stackbuilder -o -name build -o -name node_modules -o -name .vscode -o \( -type d -exec test -e {}/.git \; ! -path "$d" \) \) -prune -o -type d -print)

if [[ -f $d/.gitmodules ]]; then
  while read -r _ sp; do
    [[ -e $d/$sp/.gitkeep ]] && v ".gitkeep inside submodule: $sp"
  done < <(git -C "$d" config -f .gitmodules --get-regexp '\.path$')
fi

while IFS= read -r t; do
  rel=${t#"$d"/}
  awk '/^\[/{s=($0=="[build.combos]")} s&&/^[A-Za-z0-9_"-]+[ ]*=/{gsub(/[ "=].*/,"",$1);print $1}' "$t" |
    while read -r c; do [[ $c == entire || $c == entire-trust ]] || echo "VIOLATION: combo '$c' in $rel"; done
  grep -Eq '^[[:space:]]*yaml_merger[[:space:]]*=' "$t" && v "yaml_merger set in $rel"
  grep -Eq '^[[:space:]]*#' "$t" && v "comments in $rel"
done < <(find "$d" \( -name .git -o -name build -o -name node_modules -o \( -type d -exec test -e {}/.git \; ! -path "$d" \) \) -prune -o -name stackbuilder.toml -print)

while IFS= read -r c; do
  rel=${c#"$d"/}
  grep -Eq '^[[:space:]]*#' "$c" && v "comments in $rel"
  [[ $rel == */components/base/* ]] && grep -Eq '^[[:space:]]*ports:' "$c" && v "ports in base: $rel"
done < <(find "$d" \( -name .git -o -name build -o -name node_modules -o \( -type d -exec test -e {}/.git \; ! -path "$d" \) \) -prune -o -type f \( -name 'docker-compose*.yml' -o -name 'docker-compose*.yaml' \) -path '*/components/*' -print)

while IFS= read -r e; do
  v ".env under components: ${e#"$d"/}"
done < <(find "$d" \( -name .git -o -name build -o -name node_modules \) -prune -o -type f -name '.env' -path '*/components/*' -print)

while IFS= read -r e; do
  [[ -f $e/.env.example ]] || v ".env.example missing: ${e#"$d"/}"
done < <(find "$d" \( -name .git -o -name build -o -name node_modules \) -prune -o -type d -print | grep -E '/components/environments/[^/]+$')

while IFS= read -r s; do
  v ".stackbuilder present (delete): ${s#"$d"/}"
done < <(find "$d" -name .git -prune -o -name node_modules -prune -o -type d -name .stackbuilder -print)

[[ -f $d/.gitignore ]] && grep -Eq '^/?(app/)?build/?[[:space:]]*$' "$d/.gitignore" && v "build ignored in .gitignore"
[[ $bad == 1 ]] && exit 1
exit 0
