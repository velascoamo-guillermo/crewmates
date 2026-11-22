#!/usr/bin/env bash
set -euo pipefail

# pr-merge.sh <pr-number> [--issue <n>] [--repo owner/name]
#
# Squash-merges a PR, deletes the branch, optionally closes the linked issue.
# Fails if the PR is not mergeable (red CI, conflicts, reviews required).
#
# Merge gate (exit 3, gh merge not called, no override flag). All checks run
# against ONE `gh pr view` snapshot, and `gh pr merge` is always pinned to that
# snapshot's headRefOid via --match-head-commit (no TOCTOU window):
#   1. exactly one risk:* label, and it is risk:low|medium|high
#   2. risk:low needs a filled "## Evidence" section (exact heading, outside
#      code fences, at least one non-heading line). Template placeholders are
#      written <<like this>>; a <<...>> in Evidence (outside code fences/spans)
#      refuses. Plain HTML, autolinks, Promise<void>, <200ms are fine.
#   3. risk:medium/high need reviewDecision APPROVED
#   4. risk:high also needs the review:second-pass label
#   5. --head <sha>, if given, must equal the snapshot head (stale -> refuse)
# Unreadable PR -> exit 3. Bad/missing option values -> exit 2.

USAGE="usage: pr-merge.sh <pr-number> [--issue <n>] [--repo owner/name] [--head <sha>]"
[[ $# -ge 1 ]] || { echo "$USAGE" >&2; exit 2; }

PR="$1"; shift
ISSUE="" HEAD="" REPO_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue|--head|--repo)
      [[ $# -ge 2 && -n "$2" ]] || { echo "pr-merge: $1 needs a value" >&2; echo "$USAGE" >&2; exit 2; }
      case "$1" in
        --issue) ISSUE="$2" ;;
        --head) HEAD="$2" ;;
        --repo) REPO_ARGS=(--repo "$2") ;;
      esac
      shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

refuse() { echo "pr-merge: refused: $1" >&2; exit 3; }

# One snapshot. Output lines: headRefOid, reviewDecision, label count, one line
# per label name, then the body base64-encoded (single line).
JQ='.headRefOid, (.reviewDecision // ""), (.labels | length | tostring), (.labels[].name), ((.body // "") | @base64)'
SNAP="$(gh pr view "$PR" --json labels,reviewDecision,body,headRefOid --jq "$JQ" ${REPO_ARGS[@]+"${REPO_ARGS[@]}"})" \
  || refuse "cannot read PR #$PR"
{
  IFS= read -r OID && IFS= read -r DECISION && IFS= read -r NLABELS
} <<<"$SNAP" || refuse "cannot read PR #$PR (malformed snapshot)"
[[ -n "$OID" && "$NLABELS" =~ ^[0-9]+$ ]] || refuse "cannot read PR #$PR (malformed snapshot)"
LABELS="$(sed -n "4,$((3 + NLABELS))p" <<<"$SNAP")"
BODY="$(sed -n "$((4 + NLABELS))p" <<<"$SNAP" | base64 --decode)" || refuse "cannot read PR #$PR (bad body)"

if [[ -n "$HEAD" && "$HEAD" != "$OID" ]]; then
  refuse "stale head: expected $HEAD, PR is at $OID"
fi

RISK="" COUNT=0 SECOND=0
while IFS= read -r l; do
  case "$l" in
    risk:*) RISK="$l"; COUNT=$((COUNT + 1)) ;;
    review:second-pass) SECOND=1 ;;
  esac
done <<<"$LABELS"
[[ $COUNT -ge 1 ]] || refuse "expected exactly one risk:* label, found 0"
[[ $COUNT -eq 1 ]] || refuse "more than one risk:* label (found $COUNT)"

case "$RISK" in
  risk:low)
    IN=0 FENCE=0 CONTENT=0 CHECK=""
    while IFS= read -r line; do
      line="${line%$'\r'}"
      if [[ $IN -eq 0 ]]; then
        if [[ "$line" =~ ^\ {0,3}(\`\`\`|~~~) ]]; then FENCE=$((1 - FENCE))
        elif [[ $FENCE -eq 0 && "$line" =~ ^##\ Evidence[[:space:]]*$ ]]; then IN=1
        fi
        continue
      fi
      if [[ "$line" =~ ^\ {0,3}(\`\`\`|~~~) ]]; then FENCE=$((1 - FENCE)); continue; fi
      if [[ $FENCE -eq 1 ]]; then
        [[ -n "${line//[[:space:]]/}" ]] && CONTENT=1
        continue
      fi
      [[ "$line" == "## "* ]] && break
      if [[ ! "$line" =~ ^\ {0,3}\#{1,6}([[:space:]]|$) && -n "${line//[[:space:]]/}" ]]; then CONTENT=1; fi
      while [[ "$line" =~ ^([^\`]*)\`[^\`]*\`(.*)$ ]]; do line="${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"; done
      CHECK="$CHECK$line"$'\n'
    done <<<"$BODY"
    [[ $IN -eq 1 ]] || refuse "risk:low PR has no '## Evidence' section"
    [[ $CONTENT -eq 1 ]] || refuse "'## Evidence' section is empty"
    if [[ "$CHECK" =~ \<\<[^\>]*\>\> ]]; then
      refuse "'## Evidence' contains an unfilled placeholder ${BASH_REMATCH[0]}"
    fi
    ;;
  risk:medium|risk:high)
    [[ "$DECISION" == "APPROVED" ]] || refuse "$RISK needs reviewDecision APPROVED (got '${DECISION}')"
    if [[ "$RISK" == "risk:high" && $SECOND -ne 1 ]]; then
      refuse "risk:high needs the review:second-pass label"
    fi
    ;;
  *) refuse "unknown risk label $RISK" ;;
esac

gh pr merge "$PR" --squash --delete-branch --match-head-commit "$OID" ${REPO_ARGS[@]+"${REPO_ARGS[@]}"}

if [[ -n "$ISSUE" ]]; then
  gh issue close "$ISSUE" --comment "Done in #$PR" ${REPO_ARGS[@]+"${REPO_ARGS[@]}"}
  echo "closed issue #$ISSUE"
fi
