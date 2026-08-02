#!/usr/bin/env bash
set -euo pipefail

# board-move.sh --owner <login> --project <number> --issue <number> --status "<Status name>"
#
# Moves an issue's card on a GitHub Projects v2 board to the given Status column.
# Example: board-move.sh --owner velascoamo-guillermo --project 4 --issue 12 --status "In Progress"

OWNER="" PROJECT="" ISSUE="" STATUS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner) OWNER="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --issue) ISSUE="$2"; shift 2 ;;
    --status) STATUS="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$OWNER" && -n "$PROJECT" && -n "$ISSUE" && -n "$STATUS" ]] || {
  echo "usage: board-move.sh --owner <login> --project <number> --issue <number> --status \"<Status>\"" >&2
  exit 2
}

item_id=$(gh project item-list "$PROJECT" --owner "$OWNER" --format json --limit 500 \
  | jq -r --argjson n "$ISSUE" '.items[] | select(.content.number == $n) | .id')
[[ -n "$item_id" ]] || { echo "issue #$ISSUE not found on project $PROJECT" >&2; exit 1; }

fields=$(gh project field-list "$PROJECT" --owner "$OWNER" --format json)
field_id=$(jq -r '.fields[] | select(.name == "Status") | .id' <<<"$fields")
option_id=$(jq -r --arg s "$STATUS" \
  '.fields[] | select(.name == "Status") | .options[] | select(.name == $s) | .id' <<<"$fields")

[[ -n "$field_id" ]] || { echo "project has no Status field" >&2; exit 1; }
[[ -n "$option_id" ]] || {
  echo "status \"$STATUS\" not found. Available:" >&2
  jq -r '.fields[] | select(.name == "Status") | .options[].name' <<<"$fields" >&2
  exit 1
}

project_id=$(gh project view "$PROJECT" --owner "$OWNER" --format json | jq -r '.id')

gh project item-edit \
  --id "$item_id" \
  --project-id "$project_id" \
  --field-id "$field_id" \
  --single-select-option-id "$option_id"

echo "issue #$ISSUE -> $STATUS"
