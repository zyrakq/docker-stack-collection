#!/usr/bin/env bash
# Usage: check-gitkeep.sh [--fix] [dir]   (default: cwd)
# Reports dirs that need / must drop .gitkeep. Skips .git, git submodules
# (dirs with .git), gitignored dirs. --fix applies ADD/REMOVE (never in submodules).
# Exit 1 if findings remain (without --fix).
set -u
fix=0; [[ ${1:-} == --fix ]] && { fix=1; shift; }
root=$(cd "${1:-.}" && pwd); bad=0
ign() { git -C "$root" check-ignore -q "$1" 2>/dev/null; }
while IFS= read -r dir; do
  [[ $dir != "$root" ]] && ign "$dir" && continue
  files=0; subs=0
  while IFS= read -r e; do
    if [[ -d $e ]]; then ign "$e" || subs=1
    elif [[ $(basename "$e") != .gitkeep ]]; then ign "$e" || files=1; fi
  done < <(find "$dir" -mindepth 1 -maxdepth 1 ! -name .git)
  [[ $dir == "$root" ]] && continue
  rel=${dir#"$root"/}
  if [[ -e $dir/.gitkeep ]]; then
    if (( files )); then
      echo "REMOVE $rel/.gitkeep (dir has files)"
      (( fix )) && rm "$dir/.gitkeep" || bad=1
    fi
  elif (( ! files && subs )); then
    echo "ADD    $rel/.gitkeep (only subdirs)"
    (( fix )) && : > "$dir/.gitkeep" || bad=1
  fi
done < <(find "$root" \( -name .git -o -name node_modules -o -name .stackbuilder \) -prune -o \
  -type d \( -path "$root" -o -exec test ! -e {}/.git \; \) -print -o -type d -prune)
exit $bad
