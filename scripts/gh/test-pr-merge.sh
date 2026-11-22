#!/usr/bin/env bash
# Offline tests for pr-merge.sh. Run: ./scripts/gh/test-pr-merge.sh
#
# Design: pr-merge.sh makes ONE `gh pr view <pr> --json ... --jq <expr>` call.
# The fake gh on PATH holds fixture JSON (built from FX_LABELS newline-separated,
# FX_DECISION, FX_BODY, FX_HEAD) and applies the REAL --jq expression with jq, so
# a wrong expression fails the tests. `pr merge` and `issue close` are recorded
# to files. gh is never run against GitHub. Needs jq.
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
  echo x >>"$GH_VIEW_LOG"
  [[ -n "${FX_FAIL:-}" ]] && { echo "gh: boom" >&2; exit 1; }
  expr=""
  while [[ $# -gt 0 ]]; do [[ "$1" == "--jq" ]] && expr="$2"; shift; done
  json="$(jq -n --arg l "$FX_LABELS" --arg d "$FX_DECISION" --arg b "$FX_BODY" --arg h "$FX_HEAD" \
    '{labels: ($l | split("\n") | map(select(. != "") | {name: .})), reviewDecision: $d, body: $b, headRefOid: $h}')"
  if [[ -n "$expr" ]]; then jq -r "$expr" <<<"$json"; else echo "$json"; fi
  exit 0
fi
if [[ "$1 $2" == "pr merge" ]]; then echo "$*" >>"$GH_MERGE_LOG"; exit 0; fi
if [[ "$1 $2" == "issue close" ]]; then echo "$*" >>"$GH_CLOSE_LOG"; exit 0; fi
exit 1
FAKE
chmod +x "$T/bin/gh"
export PATH="$T/bin:$PATH" GH_MERGE_LOG="$T/merge.log" GH_CLOSE_LOG="$T/close.log" GH_VIEW_LOG="$T/view.log"

fails=0
ok() { echo "ok   - $1"; }
fail() { echo "FAIL - $1${2:+: $2}"; fails=$((fails + 1)); }
eq() { [[ "$2" == "$3" ]] && ok "$1" || fail "$1" "expected [$3] got [$2]"; }

GOOD_BODY=$'Closes #1\n\n## Evidence\nRun the app, tap the button, see the toast.\n\n## Notes\nnone'
reset() {
  rm -f "$GH_MERGE_LOG" "$GH_CLOSE_LOG" "$GH_VIEW_LOG"
  unset FX_FAIL
  FX_LABELS="risk:low"; FX_DECISION=""; FX_BODY="$GOOD_BODY"; FX_HEAD="abc123"
  export FX_LABELS FX_DECISION FX_BODY FX_HEAD
}
merged() { [[ -s "$GH_MERGE_LOG" ]] && echo yes || echo no; }
refuses() { # name, reason-substring, args...
  local name="$1" reason="$2"; shift 2
  run_script 5 "$@" >/dev/null 2>"$T/err"; local rc=$?
  eq "$name exits 3" "$rc" "3"
  eq "$name not merged" "$(merged)" "no"
  grep -qF -- "$reason" "$T/err" && ok "$name reason" || fail "$name reason" "want [$reason] got [$(cat "$T/err")]"
}
passes() { # name, args...
  local name="$1"; shift
  run_script 5 "$@" >/dev/null 2>"$T/err"; local rc=$?
  eq "$name exits 0" "$rc" "0"
  eq "$name merged" "$(merged)" "yes"
}
usage_err() { # name, args...
  local name="$1"; shift
  run_script 5 "$@" >/dev/null 2>&1; eq "$name exits 2" "$?" "2"
  eq "$name not merged" "$(merged)" "no"
}

reset; FX_LABELS=""; refuses "no risk label" "found 0"
reset; FX_LABELS=$'risk:low\nrisk:high'; refuses "two risk labels" "more than one" 
reset; FX_LABELS=$'risk:high\nrisk:low'; refuses "two risk labels, high first" "more than one"
reset; FX_LABELS=$'bug\nenhancement'; refuses "unrelated labels only" "found 0"
reset; FX_LABELS="risk:lowish"; refuses "risk:lowish" "unknown"
reset; FX_BODY=$'Closes #1\n\n## Notes\nx'; refuses "low without Evidence" "no '## Evidence' section"
reset; FX_BODY=$'## Evidenceless\nstuff'; refuses "Evidenceless heading" "no '## Evidence' section"
reset; FX_BODY=$'### Evidence\nstuff'; refuses "h3 Evidence" "no '## Evidence' section"
reset; FX_BODY=$'## Notes\n```\n## Evidence\nfake\n```\n'; refuses "Evidence heading inside fence" "no '## Evidence' section"
reset; FX_BODY=$'## Evidence\n<<3-line what to verify>>\n\n## Notes\nx'; refuses "low with placeholder" "placeholder"
reset; FX_BODY=$'## Evidence\nsee <<link>> here'; refuses "low with inline placeholder" "placeholder"
reset; FX_BODY=$'## Evidence\n<<multi\nline>>'; refuses "multiline placeholder" "placeholder"
reset; FX_BODY=$'## Evidence\n\n## Notes\nx'; refuses "low with empty Evidence" "empty"
reset; FX_BODY=$'## Evidence\n   \n'; refuses "low with blank Evidence" "empty"
reset; FX_BODY=$'## Evidence\n### Steps\n\n## Notes\nx'; refuses "subheading only Evidence" "empty"
reset; FX_BODY=$'## Evidence\r\n\r\n## Notes\r\nx\r\n'; refuses "CRLF empty Evidence" "empty"
reset; FX_BODY=$'## Evidence\r\n<<fill me>>\r\n'; refuses "CRLF placeholder" "placeholder"
reset; FX_LABELS="risk:medium"; FX_DECISION="REVIEW_REQUIRED"; refuses "medium not approved" "APPROVED"
reset; FX_LABELS="risk:medium"; FX_DECISION=""; refuses "medium no decision" "APPROVED"
reset; FX_LABELS="risk:high"; FX_DECISION="CHANGES_REQUESTED"; refuses "high not approved" "APPROVED"
reset; FX_LABELS="risk:high"; FX_DECISION="APPROVED"; refuses "high approved no second-pass" "second-pass"
reset; FX_HEAD="def456"; refuses "stale head" "stale" --head abc123
reset; export FX_FAIL=1; refuses "gh view fails" "cannot read PR"

reset; passes "low good evidence"
reset; FX_BODY=$'## Evidence  \nok fine\n## Notes\n<<x>>'; passes "heading trailing spaces, later placeholder"
reset; FX_BODY=$'## Evidence\r\nok fine\r\n## Notes\r\n<<x>>\r\n'; passes "CRLF good body"
reset; FX_BODY=$'## Evidence\n### Steps\nrun it\n## Notes'; passes "subheading plus content"
reset; FX_BODY=$'## Evidence\n```\n## not a heading\n<<in fence>>\n```\nok\n## Notes'; passes "fence hides ## and placeholder"
reset; FX_BODY=$'## Evidence\nuse `<<name>>` syntax'; passes "placeholder in code span"
reset; FX_BODY=$'## Evidence\n<details><summary>log</summary>\nok\n</details><br>\n<img src="x.gif" width=300>'; passes "plain HTML"
reset; FX_BODY=$'## Evidence\nsee <https://x.y/z>, Promise<void> ok, latency <200ms, a < b'; passes "autolink generics lt"
reset; FX_LABELS="risk:medium"; FX_DECISION="APPROVED"; FX_BODY="no evidence needed"; passes "medium approved"
reset; FX_LABELS=$'risk:high\nreview:second-pass'; FX_DECISION="APPROVED"; passes "high approved second-pass"

reset; passes "issue close" --issue 9
eq "issue closed" "$(grep -c 'issue close 9' "$GH_CLOSE_LOG" 2>/dev/null)" "1"
eq "single gh view call" "$(wc -l <"$GH_VIEW_LOG" | tr -d ' ')" "1"
eq "merge flags" "$(cat "$GH_MERGE_LOG")" "pr merge 5 --squash --delete-branch --match-head-commit abc123"

reset; passes "head match" --head abc123
grep -q -- '--match-head-commit abc123' "$GH_MERGE_LOG" && ok "match-head-commit passed" || fail "match-head-commit passed" "$(cat "$GH_MERGE_LOG")"
reset; FX_BODY=$'## Evidence\n$(touch '"$T"$'/pwn) `touch '"$T"$'/pwn2` ${x:?boom}'; passes "shell metachars in body"
[[ ! -e "$T/pwn" && ! -e "$T/pwn2" ]] && ok "body not executed" || fail "body not executed"

reset; run_script >/dev/null 2>&1; eq "no args exits 2" "$?" "2"
reset; run_script 5 --bogus >/dev/null 2>&1; eq "unknown arg exits 2" "$?" "2"
eq "usage error not merged" "$(merged)" "no"
reset; usage_err "--head no value" --head
reset; usage_err "--head empty" --head ""
reset; usage_err "--issue no value" --issue
reset; usage_err "--issue empty" --issue ""
reset; usage_err "--repo no value" --repo
reset; usage_err "--repo empty" --repo ""

[[ $fails -eq 0 ]] && { echo "all passed"; exit 0; } || { echo "$fails failed"; exit 1; }
