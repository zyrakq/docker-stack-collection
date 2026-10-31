#!/usr/bin/env bash
# .githooks/stack-push.sh — mass push of stack repos that are ahead of their
# upstream. Manual script, never invoked by hooks. Never stashes, commits,
# merges or rebases: repos are pushed as-is (committed work only).
#
# Per stacks.csv row (header, comments and url "-" rows are skipped):
#   missing locally          -> reported, skipped
#   fetch origin fails       -> reported as failed, skipped
#   no upstream              -> reported, skipped (also covers an upstream
#                               branch deleted remotely: fetch runs --prune)
#   up to date / behind only -> skipped (nothing to push)
#   ahead only               -> pushed to the existing upstream branch
#   diverged (ahead+behind)  -> NOT pushed, reported for manual resolution
#
# Exit code: 0 when nothing diverged and nothing failed (missing repos and
# missing upstreams are warnings only); 1 when any repo diverged or any
# fetch/push failed.
#
# Env overrides (used by tests): STACKS_ROOT, STACKS_MANIFEST
set -euo pipefail

ROOT="${STACKS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MANIFEST="${STACKS_MANIFEST:-$ROOT/stacks.csv}"

cd "$ROOT"

if [[ ! -f "$MANIFEST" ]]; then
  echo "stack-push: manifest not found: $MANIFEST" >&2
  exit 1
fi

pushed=0 up_to_date=0 diverged=0 no_upstream=0 missing=0 failed=0
diverged_list=() no_upstream_list=() failed_list=()

while IFS=';' read -r path url status; do
  [[ -z "$path" || "$path" == \#* || "$path" == "path" ]] && continue
  if [[ -z "$url" || "$url" == "-" ]]; then
    echo "stack-push: WARN no url for '$path', skipping" >&2
    continue
  fi
  if [[ ! -d "$path" ]] || ! git -C "$path" rev-parse --git-dir >/dev/null 2>&1; then
    echo "stack-push: WARN missing repo '$path', skipping" >&2
    missing=$((missing + 1)); missing_list+=("$path")
    continue
  fi
  if ! git -C "$path" fetch --quiet --prune origin < /dev/null; then
    echo "stack-push: WARN fetch failed for '$path', skipping" >&2
    failed=$((failed + 1)); failed_list+=("$path")
    continue
  fi
  if ! upstream="$(git -C "$path" rev-parse --verify --quiet --abbrev-ref '@{u}' 2>/dev/null)"; then
    echo "stack-push: WARN no upstream for '$path', skipping" >&2
    no_upstream=$((no_upstream + 1)); no_upstream_list+=("$path")
    continue
  fi
  ahead="$(git -C "$path" rev-list --count '@{u}..HEAD')"
  behind="$(git -C "$path" rev-list --count 'HEAD..@{u}')"
  if [[ "$ahead" -eq 0 ]]; then
    up_to_date=$((up_to_date + 1))  # up to date or behind only — nothing to push
  elif [[ "$behind" -gt 0 ]]; then
    echo "stack-push: WARN diverged from '$upstream' (ahead $ahead, behind $behind), not pushing: '$path'" >&2
    diverged=$((diverged + 1)); diverged_list+=("$path")
  else
    remote_branch="${upstream#*/}"
    if git -C "$path" push --quiet origin "HEAD:$remote_branch" < /dev/null; then
      pushed=$((pushed + 1))
    else
      echo "stack-push: WARN push failed for '$path'" >&2
      failed=$((failed + 1)); failed_list+=("$path")
    fi
  fi
done < "$MANIFEST"

echo "stack-push: summary: pushed=$pushed up-to-date=$up_to_date diverged=$diverged no-upstream=$no_upstream missing=$missing failed=$failed"
if [[ "$diverged" -gt 0 ]]; then
  echo "stack-push: diverged (not pushed, resolve manually):"
  for p in "${diverged_list[@]}"; do echo "stack-push:   $p"; done
fi
if [[ "$no_upstream" -gt 0 ]]; then
  echo "stack-push: no upstream configured:"
  for p in "${no_upstream_list[@]}"; do echo "stack-push:   $p"; done
fi
if [[ "$failed" -gt 0 ]]; then
  echo "stack-push: failed (fetch/push error):"
  for p in "${failed_list[@]}"; do echo "stack-push:   $p"; done
fi

[[ "$diverged" -eq 0 && "$failed" -eq 0 ]]
