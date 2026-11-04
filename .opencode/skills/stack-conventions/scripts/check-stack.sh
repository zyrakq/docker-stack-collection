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
  files=$(find "$dir" -maxdepth 1 -type f ! -name .gitkeep | head -1)
  subs=$(find "$dir" -maxdepth 1 -mindepth 1 -type d ! -name .git -exec test ! -e {}/.git \; -print | head -1)
  if [[ -f $dir/.gitkeep ]]; then
    [[ -n $files ]] && v ".gitkeep in dir with files: $rel"
  elif [[ -z $files && -n $subs && $rel != . ]]; then
    v ".gitkeep missing (dir has only subdirs): $rel"
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
  grep -Eq '^[[:space:]]*yaml_merger[[:space:]]*=[[:space:]]*"rust"' "$t" && v "yaml_merger rust in $rel"
done < <(find "$d" \( -name .git -o -name build -o -name node_modules -o \( -type d -exec test -e {}/.git \; ! -path "$d" \) \) -prune -o -name stackbuilder.toml -print)

[[ -f $d/.gitignore ]] && grep -Eq '^/?(app/)?build/?[[:space:]]*$' "$d/.gitignore" && v "build ignored in .gitignore"
[[ $bad == 1 ]] && exit 1
exit 0
