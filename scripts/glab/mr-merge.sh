#!/usr/bin/env bash
set -euo pipefail

# mr-merge.sh <mr-iid> [--issue <iid>] [--repo group/project]
#
# GitLab twin of gh/pr-merge.sh. Squash-merges an MR, removes the source
# branch, optionally closes the linked issue.

[[ $# -ge 1 ]] || { echo "usage: mr-merge.sh <mr-iid> [--issue <iid>] [--repo group/project]" >&2; exit 2; }

MR="$1"; shift
ISSUE="" REPO_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue) ISSUE="$2"; shift 2 ;;
    --repo) REPO_ARGS=(--repo "$2"); shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

glab mr merge "$MR" --squash --remove-source-branch --yes ${REPO_ARGS[@]+"${REPO_ARGS[@]}"}

if [[ -n "$ISSUE" ]]; then
  glab issue close "$ISSUE" ${REPO_ARGS[@]+"${REPO_ARGS[@]}"}
  echo "closed issue #$ISSUE"
fi
