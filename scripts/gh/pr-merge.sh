#!/usr/bin/env bash
set -euo pipefail

# pr-merge.sh <pr-number> [--issue <n>] [--repo owner/name]
#
# Squash-merges a PR, deletes the branch, optionally closes the linked issue.
# Fails if the PR is not mergeable (red CI, conflicts, reviews required).
#
# Merge gate (exit 3, gh merge not called, no override flag):
#   1. exactly one risk:* label
#   2. risk:low needs a filled "## Evidence" section (no <placeholder> tokens)
#   3. risk:medium/high need reviewDecision APPROVED
#   4. risk:high also needs the review:second-pass label
#   5. --head <sha> must equal the PR head (also passed as --match-head-commit)

USAGE="usage: pr-merge.sh <pr-number> [--issue <n>] [--repo owner/name] [--head <sha>]"
[[ $# -ge 1 ]] || { echo "$USAGE" >&2; exit 2; }

PR="$1"; shift
ISSUE="" HEAD="" REPO_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue) ISSUE="$2"; shift 2 ;;
    --head) HEAD="$2"; shift 2 ;;
    --repo) REPO_ARGS=(--repo "$2"); shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

refuse() { echo "pr-merge: refused: $1" >&2; exit 3; }
view() { gh pr view "$PR" --json "$1" --jq "$2" ${REPO_ARGS[@]+"${REPO_ARGS[@]}"}; }

LABELS="$(view labels '.labels[].name')"
RISK="" COUNT=0 SECOND=0
while IFS= read -r l; do
  case "$l" in
    risk:*) RISK="$l"; COUNT=$((COUNT + 1)) ;;
    review:second-pass) SECOND=1 ;;
  esac
done <<<"$LABELS"
[[ $COUNT -eq 1 ]] || refuse "expected exactly one risk:* label, found $COUNT"

case "$RISK" in
  risk:low)
    BODY="$(view body '.body')"
    IN=0 SECTION=""
    while IFS= read -r line; do
      line="${line%$'\r'}"
      if [[ $IN -eq 0 ]]; then
        [[ "$line" == "## Evidence"* ]] && IN=1
      elif [[ "$line" == "## "* ]]; then
        break
      else
        SECTION="$SECTION$line"$'\n'
      fi
    done <<<"$BODY"
    [[ $IN -eq 1 ]] || refuse "risk:low PR has no '## Evidence' section"
    [[ -n "${SECTION//[[:space:]]/}" ]] || refuse "'## Evidence' section is empty"
    if [[ "$SECTION" =~ \<[^\>]+\> ]]; then
      refuse "'## Evidence' contains an unfilled placeholder ${BASH_REMATCH[0]}"
    fi
    ;;
  risk:medium|risk:high)
    DECISION="$(view reviewDecision '.reviewDecision')"
    [[ "$DECISION" == "APPROVED" ]] || refuse "$RISK needs reviewDecision APPROVED (got '${DECISION}')"
    if [[ "$RISK" == "risk:high" && $SECOND -ne 1 ]]; then
      refuse "risk:high needs the review:second-pass label"
    fi
    ;;
  *) refuse "unknown risk label $RISK" ;;
esac

MATCH=()
if [[ -n "$HEAD" ]]; then
  CUR="$(view headRefOid '.headRefOid')"
  [[ "$CUR" == "$HEAD" ]] || refuse "stale head: expected $HEAD, PR is at $CUR"
  MATCH=(--match-head-commit "$HEAD")
fi

gh pr merge "$PR" --squash --delete-branch ${MATCH[@]+"${MATCH[@]}"} ${REPO_ARGS[@]+"${REPO_ARGS[@]}"}

if [[ -n "$ISSUE" ]]; then
  gh issue close "$ISSUE" --comment "Done in #$PR" ${REPO_ARGS[@]+"${REPO_ARGS[@]}"}
  echo "closed issue #$ISSUE"
fi
