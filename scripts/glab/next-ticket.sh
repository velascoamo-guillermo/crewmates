#!/usr/bin/env bash
set -euo pipefail

# next-ticket.sh [--repo group/project]
#
# GitLab twin of gh/next-ticket.sh. Picks the lowest-numbered open issue
# labeled 'ticket' whose "Depends on: #N" dependencies are all closed.
# Prints "IID<TAB>TITLE" and exits 0. Exits 1 if no eligible ticket.

REPO_ARGS=()
if [[ "${1:-}" == "--repo" ]]; then
  [[ -n "${2:-}" ]] || { echo "usage: next-ticket.sh [--repo group/project]" >&2; exit 2; }
  REPO_ARGS=(--repo "$2")
fi

issues=$(glab issue list ${REPO_ARGS[@]+"${REPO_ARGS[@]}"} --label ticket --per-page 100 --output json)

if [[ "$(jq length <<<"$issues")" -eq 0 ]]; then
  echo "no open issues with label 'ticket'" >&2
  exit 1
fi

while IFS= read -r row; do
  iid=$(jq -r '.iid' <<<"$row")
  body=$(jq -r '.description // ""' <<<"$row")

  deps=$(grep -iE '^ *depends on:' <<<"$body" | grep -oE '#[0-9]+' | tr -d '#' || true)

  eligible=true
  for dep in $deps; do
    state=$(glab issue view "$dep" ${REPO_ARGS[@]+"${REPO_ARGS[@]}"} --output json | jq -r '.state')
    if [[ "$state" != "closed" ]]; then
      eligible=false
      break
    fi
  done

  if $eligible; then
    title=$(jq -r '.title' <<<"$row")
    printf '%s\t%s\n' "$iid" "$title"
    exit 0
  fi
done < <(jq -c 'sort_by(.iid)[]' <<<"$issues")

echo "no eligible ticket (all blocked by open dependencies)" >&2
exit 1
