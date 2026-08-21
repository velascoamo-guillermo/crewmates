#!/usr/bin/env bash
set -euo pipefail

# board-move.sh --issue <iid> --scope <scope> --value "<Value>"
#
# GitLab twin of gh/board-move.sh. GitLab issue boards are label-driven:
# moving a card = swapping the scoped label. This sets "<scope>::<Value>" and
# removes any other label in the same scope.
#
# Example: board-move.sh --issue 42 --scope workflow --value "In Progress"
#   -> adds "workflow::In Progress", removes other "workflow::*" labels

ISSUE="" SCOPE="" VALUE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue) ISSUE="$2"; shift 2 ;;
    --scope) SCOPE="$2"; shift 2 ;;
    --value) VALUE="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$ISSUE" && -n "$SCOPE" && -n "$VALUE" ]] || {
  echo "usage: board-move.sh --issue <iid> --scope <scope> --value \"<Value>\"" >&2
  exit 2
}

new_label="${SCOPE}::${VALUE}"

remove=$(glab api "projects/:id/issues/$ISSUE" \
  | jq -r --arg scope "${SCOPE}::" --arg new "$new_label" \
      '[.labels[] | select(startswith($scope)) | select(. != $new)] | join(",")')

glab api -X PUT "projects/:id/issues/$ISSUE" \
  -f "add_labels=$new_label" \
  -f "remove_labels=$remove" >/dev/null

echo "issue #$ISSUE -> $new_label"
