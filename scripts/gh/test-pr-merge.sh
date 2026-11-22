#!/usr/bin/env bash
# Offline tests for pr-merge.sh. Run: ./scripts/gh/test-pr-merge.sh
#
# Design: pr-merge.sh calls `gh pr view <pr> --json <field> --jq .<field>`
# (or `.labels[].name`) once per field (labels, reviewDecision, body,
# headRefOid). The fake gh on PATH keys on the --json field and prints the
# canned fixture value (FX_LABELS newline-separated, FX_DECISION, FX_BODY,
# FX_HEAD) as the --jq result would. `pr merge` and `issue close` are recorded
# to files. gh is never run against GitHub.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${PR_MERGE_SCRIPT:-$HERE/pr-merge.sh}"
run_script() { if [[ -n "${TEST_BASH:-}" ]]; then "$TEST_BASH" "$SCRIPT" "$@"; else "$SCRIPT" "$@"; fi; }
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir "$T/bin"
cat >"$T/bin/gh" <<'FAKE'
#!/usr/bin/env bash
if [[ "$1 $2" == "pr view" ]]; then
  field=""
  while [[ $# -gt 0 ]]; do [[ "$1" == "--json" ]] && field="$2"; shift; done
  case "$field" in
    labels) printf '%s' "$FX_LABELS" ;;
    reviewDecision) printf '%s' "$FX_DECISION" ;;
    body) printf '%s' "$FX_BODY" ;;
    headRefOid) printf '%s' "$FX_HEAD" ;;
  esac
  echo
  exit 0
fi
if [[ "$1 $2" == "pr merge" ]]; then echo "$*" >>"$GH_MERGE_LOG"; exit 0; fi
if [[ "$1 $2" == "issue close" ]]; then echo "$*" >>"$GH_CLOSE_LOG"; exit 0; fi
exit 1
FAKE
chmod +x "$T/bin/gh"
export PATH="$T/bin:$PATH" GH_MERGE_LOG="$T/merge.log" GH_CLOSE_LOG="$T/close.log"

fails=0
ok() { echo "ok   - $1"; }
fail() { echo "FAIL - $1${2:+: $2}"; fails=$((fails + 1)); }
eq() { [[ "$2" == "$3" ]] && ok "$1" || fail "$1" "expected [$3] got [$2]"; }

GOOD_BODY=$'Closes #1\n\n## Evidence\nRun the app, tap the button, see the toast.\n\n## Notes\nnone'
reset() {
  rm -f "$GH_MERGE_LOG" "$GH_CLOSE_LOG"
  FX_LABELS="risk:low"; FX_DECISION=""; FX_BODY="$GOOD_BODY"; FX_HEAD="abc123"
  export FX_LABELS FX_DECISION FX_BODY FX_HEAD
}
merged() { [[ -s "$GH_MERGE_LOG" ]] && echo yes || echo no; }
refuses() { # name, args...
  local name="$1"; shift
  run_script 5 "$@" >/dev/null 2>"$T/err"; local rc=$?
  eq "$name exits 3" "$rc" "3"
  eq "$name not merged" "$(merged)" "no"
  [[ -s "$T/err" ]] && ok "$name has reason" || fail "$name has reason"
}
passes() { # name, args...
  local name="$1"; shift
  run_script 5 "$@" >/dev/null 2>"$T/err"; local rc=$?
  eq "$name exits 0" "$rc" "0"
  eq "$name merged" "$(merged)" "yes"
}

reset; FX_LABELS=""; refuses "no risk label"
reset; FX_LABELS=$'risk:low\nrisk:high'; refuses "two risk labels"
reset; FX_LABELS=$'bug\nenhancement'; refuses "unrelated labels only"
reset; FX_BODY=$'Closes #1\n\n## Notes\nx'; refuses "low without Evidence"
reset; FX_BODY=$'## Evidence\n<3-line what to verify>\n\n## Notes\nx'; refuses "low with placeholder"
reset; FX_BODY=$'## Evidence\nsee <link> here'; refuses "low with inline placeholder"
reset; FX_BODY=$'## Evidence\n\n## Notes\nx'; refuses "low with empty Evidence"
reset; FX_BODY=$'## Evidence\n   \n'; refuses "low with blank Evidence"
reset; FX_LABELS="risk:medium"; FX_DECISION="REVIEW_REQUIRED"; refuses "medium not approved"
reset; FX_LABELS="risk:medium"; FX_DECISION=""; refuses "medium no decision"
reset; FX_LABELS="risk:high"; FX_DECISION="CHANGES_REQUESTED"; refuses "high not approved"
reset; FX_LABELS="risk:high"; FX_DECISION="APPROVED"; refuses "high approved no second-pass"
reset; FX_HEAD="def456"; refuses "stale head" --head abc123

reset; passes "low good evidence"
reset; FX_LABELS="risk:medium"; FX_DECISION="APPROVED"; FX_BODY="no evidence needed"; passes "medium approved"
reset; FX_LABELS=$'risk:high\nreview:second-pass'; FX_DECISION="APPROVED"; passes "high approved second-pass"

reset; passes "issue close" --issue 9
eq "issue closed" "$(grep -c 'issue close 9' "$GH_CLOSE_LOG" 2>/dev/null)" "1"
eq "merge flags" "$(cat "$GH_MERGE_LOG")" "pr merge 5 --squash --delete-branch"

reset; passes "head match" --head abc123
grep -q -- '--match-head-commit abc123' "$GH_MERGE_LOG" && ok "match-head-commit passed" || fail "match-head-commit passed" "$(cat "$GH_MERGE_LOG")"

reset; run_script >/dev/null 2>&1; eq "no args exits 2" "$?" "2"
reset; run_script 5 --bogus >/dev/null 2>&1; eq "unknown arg exits 2" "$?" "2"
eq "usage error not merged" "$(merged)" "no"

[[ $fails -eq 0 ]] && { echo "all passed"; exit 0; } || { echo "$fails failed"; exit 1; }
