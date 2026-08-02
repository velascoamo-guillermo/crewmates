#!/usr/bin/env bash
set -euo pipefail

# pr-merge.sh <pr-number> [--issue <n>] [--repo owner/name]
#
# Squash-merges a PR, deletes the branch, optionally closes the linked issue.
# Fails if the PR is not mergeable (red CI, conflicts, reviews required).

[[ $# -ge 1 ]] || { echo "usage: pr-merge.sh <pr-number> [--issue <n>] [--repo owner/name]" >&2; exit 2; }

PR="$1"; shift
ISSUE="" REPO_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue) ISSUE="$2"; shift 2 ;;
    --repo) REPO_ARGS=(--repo "$2"); shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

gh pr merge "$PR" --squash --delete-branch ${REPO_ARGS[@]+"${REPO_ARGS[@]}"}

if [[ -n "$ISSUE" ]]; then
  gh issue close "$ISSUE" --comment "Done in #$PR" ${REPO_ARGS[@]+"${REPO_ARGS[@]}"}
  echo "closed issue #$ISSUE"
fi
