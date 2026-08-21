#!/usr/bin/env bash
set -euo pipefail

# mr-create.sh --title "..." --body-file <path> [--target main] [--draft]
#
# GitLab twin of gh/pr-create.sh. Pushes the current branch (no force) and
# opens a merge request. Refuses to run from main/master.

TITLE="" BODY_FILE="" TARGET="" DRAFT=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title) TITLE="$2"; shift 2 ;;
    --body-file) BODY_FILE="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --draft) DRAFT=(--draft); shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$TITLE" && -n "$BODY_FILE" ]] || {
  echo "usage: mr-create.sh --title \"...\" --body-file <path> [--target main] [--draft]" >&2
  exit 2
}
[[ -f "$BODY_FILE" ]] || { echo "body file not found: $BODY_FILE" >&2; exit 2; }

branch=$(git rev-parse --abbrev-ref HEAD)
if [[ "$branch" == "main" || "$branch" == "master" ]]; then
  echo "refusing to open an MR from $branch — create a feature branch first" >&2
  exit 1
fi

git push -u origin "$branch"

TARGET_ARGS=()
[[ -n "$TARGET" ]] && TARGET_ARGS=(--target-branch "$TARGET")

glab mr create \
  --title "$TITLE" \
  --description "$(cat "$BODY_FILE")" \
  --source-branch "$branch" \
  ${TARGET_ARGS[@]+"${TARGET_ARGS[@]}"} \
  ${DRAFT[@]+"${DRAFT[@]}"} \
  --yes
