#!/usr/bin/env bash
set -euo pipefail

# next-ticket.sh [--repo owner/name]
#
# Picks the next workable ticket: lowest-numbered open issue labeled 'ticket'
# whose "Depends on: #N" dependencies (in the issue body) are all closed.
# Prints "NUMBER<TAB>TITLE" and exits 0. Exits 1 if no eligible ticket.

REPO_ARGS=()
if [[ "${1:-}" == "--repo" ]]; then
  [[ -n "${2:-}" ]] || { echo "usage: next-ticket.sh [--repo owner/name]" >&2; exit 2; }
  REPO_ARGS=(--repo "$2")
fi

issues=$(gh issue list ${REPO_ARGS[@]+"${REPO_ARGS[@]}"} --label ticket --state open --limit 100 --json number,title,body)

if [[ "$(jq length <<<"$issues")" -eq 0 ]]; then
  echo "no open issues with label 'ticket'" >&2
  exit 1
fi

while IFS= read -r row; do
  number=$(jq -r '.number' <<<"$row")
  body=$(jq -r '.body // ""' <<<"$row")

  # Dependencies: any "#N" on lines matching "Depends on:"
  deps=$(grep -iE '^ *depends on:' <<<"$body" | grep -oE '#[0-9]+' | tr -d '#' || true)

  eligible=true
  for dep in $deps; do
    state=$(gh issue view "$dep" ${REPO_ARGS[@]+"${REPO_ARGS[@]}"} --json state -q .state)
    if [[ "$state" != "CLOSED" ]]; then
      eligible=false
      break
    fi
  done

  if $eligible; then
    title=$(jq -r '.title' <<<"$row")
    printf '%s\t%s\n' "$number" "$title"
    exit 0
  fi
done < <(jq -c 'sort_by(.number)[]' <<<"$issues")

echo "no eligible ticket (all blocked by open dependencies)" >&2
exit 1
