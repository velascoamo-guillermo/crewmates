#!/usr/bin/env bash
set -euo pipefail

# issue-create.sh --title "..." --body-file <path> [--label ticket] [--assignee @me] [--repo owner/name]
#
# Creates a GitHub issue from a body file. Prints the issue URL.

TITLE="" BODY_FILE="" LABELS=() ASSIGNEE_ARGS=() REPO_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title) TITLE="$2"; shift 2 ;;
    --body-file) BODY_FILE="$2"; shift 2 ;;
    --label) LABELS+=(--label "$2"); shift 2 ;;
    --assignee) ASSIGNEE_ARGS=(--assignee "$2"); shift 2 ;;
    --repo) REPO_ARGS=(--repo "$2"); shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$TITLE" && -n "$BODY_FILE" ]] || {
  echo "usage: issue-create.sh --title \"...\" --body-file <path> [--label X]... [--assignee @me] [--repo owner/name]" >&2
  exit 2
}
[[ -f "$BODY_FILE" ]] || { echo "body file not found: $BODY_FILE" >&2; exit 2; }

gh issue create \
  --title "$TITLE" \
  --body-file "$BODY_FILE" \
  ${LABELS[@]+"${LABELS[@]}"} \
  ${ASSIGNEE_ARGS[@]+"${ASSIGNEE_ARGS[@]}"} \
  ${REPO_ARGS[@]+"${REPO_ARGS[@]}"}
