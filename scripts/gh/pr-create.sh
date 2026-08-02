#!/usr/bin/env bash
set -euo pipefail

# pr-create.sh --title "..." --body-file <path> [--base main] [--draft]
#
# Pushes the current branch (no force) and opens a PR. Prints the PR URL.
# Refuses to run from main/master.

TITLE="" BODY_FILE="" BASE="" DRAFT=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title) TITLE="$2"; shift 2 ;;
    --body-file) BODY_FILE="$2"; shift 2 ;;
    --base) BASE="$2"; shift 2 ;;
    --draft) DRAFT=(--draft); shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$TITLE" && -n "$BODY_FILE" ]] || {
  echo "usage: pr-create.sh --title \"...\" --body-file <path> [--base main] [--draft]" >&2
  exit 2
}
[[ -f "$BODY_FILE" ]] || { echo "body file not found: $BODY_FILE" >&2; exit 2; }

branch=$(git rev-parse --abbrev-ref HEAD)
if [[ "$branch" == "main" || "$branch" == "master" ]]; then
  echo "refusing to open a PR from $branch — create a feature branch first" >&2
  exit 1
fi

git push -u origin "$branch"

BASE_ARGS=()
[[ -n "$BASE" ]] && BASE_ARGS=(--base "$BASE")

gh pr create \
  --title "$TITLE" \
  --body-file "$BODY_FILE" \
  ${BASE_ARGS[@]+"${BASE_ARGS[@]}"} \
  ${DRAFT[@]+"${DRAFT[@]}"}
