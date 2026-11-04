#!/usr/bin/env bash
# Usage: check-gitkeep.sh [--fix] [dir]   (default: cwd)
# Rule: a dir needs .gitkeep ONLY when it contains exactly ONE subdirectory and
# nothing else (IDEs collapse such single-child chains). Any other layout
# (multiple subdirs, any files) must NOT have .gitkeep. Skips .git, git
# submodules (dirs with .git), gitignored dirs, node_modules, .stackbuilder.
# --fix applies ADD/REMOVE (never in submodules).
# Exit 1 if findings remain (without --fix).
set -u
fix=0; [[ ${1:-} == --fix ]] && { fix=1; shift; }
root=$(cd "${1:-.}" && pwd); bad=0
ign() { git -C "$root" check-ignore -q "$1" 2>/dev/null; }
while IFS= read -r dir; do
  [[ $dir != "$root" ]] && ign "$dir" && continue
  files=0; nsub=0
  while IFS= read -r e; do
    if [[ -d $e ]]; then ign "$e" || nsub=$((nsub+1))
    elif [[ $(basename "$e") != .gitkeep ]]; then ign "$e" || files=1; fi
  done < <(find "$dir" -mindepth 1 -maxdepth 1 ! -name .git)
  [[ $dir == "$root" ]] && continue
  rel=${dir#"$root"/}
  need=0; (( 1 == nsub )) && (( 0 == files )) && need=1
  if [[ -e $dir/.gitkeep ]]; then
    if (( ! need )); then
      if (( files )); then echo "REMOVE $rel/.gitkeep (dir has files)"
      else echo "REMOVE $rel/.gitkeep (not exactly one subdir, found $nsub)"; fi
      (( fix )) && rm "$dir/.gitkeep" || bad=1
    fi
  elif (( need )); then
    echo "ADD    $rel/.gitkeep (exactly one subdir)"
    (( fix )) && : > "$dir/.gitkeep" || bad=1
  fi
done < <(find "$root" \( -name .git -o -name node_modules -o -name .stackbuilder \) -prune -o \
  -type d \( -path "$root" -o -exec test ! -e {}/.git \; \) -print -o -type d -prune)
exit $bad
