#!/usr/bin/env bash
# Offline contract tests for the agent prompts and templates/pr-body.md.
# This is a contract tripwire, not a proof: it catches accidental edits to the
# prompt wording. The deny rules and pr-merge.sh are the actual enforcement.
# Run: ./scripts/test-prompts.sh   (needs jq, perl)
#
# Rules enforced:
#  - pr-body.md: only well-formed <<...>> placeholders (may span lines); any
#    other < or > in the file fails (<x>, <<x>, <x>>, multi-line <2-6 ...>).
#  - pr-body.md: ## Evidence has Check, Before/after, Flow (GIF + mp4), Tests,
#    Review and Risk items.
#  - No PROMPT.md may mention approve/approves/approved/approving/approval
#    unless the same sentence also says "owner" (the owner approves) or
#    "verdict" (the reviewer's APPROVE/REQUEST_CHANGES output). `gh pr review`
#    is always forbidden.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TPL="$ROOT/templates/pr-body.md"
P="$ROOT/crewmates"
MERGE="$ROOT/scripts/gh/pr-merge.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

fails=0
ok() { echo "ok   - $1"; }
fail() { echo "FAIL - $1${2:+: $2}"; fails=$((fails + 1)); }
has() { # name, file, fixed-string
  grep -qF -- "$3" "$2" 2>/dev/null && ok "$1" || fail "$1" "[$3] not in ${2#"$ROOT"/}"
}

# --- pr-body.md shape
first="$(grep -m1 -v '^[[:space:]]*$' "$TPL" 2>/dev/null || true)"
[[ "$first" == "## Evidence" ]] && ok "pr-body opens with ## Evidence" || fail "pr-body opens with ## Evidence" "got [$first]"
# only well-formed <<...>> allowed: strip them (across lines), nothing with < or > may remain
leftover="$(perl -0pe 's/<<[^<>]*>>//g' "$TPL" 2>/dev/null | grep -nE '[<>]' || true)"
[[ -z "$leftover" ]] && ok "pr-body has only <<...>> placeholders" || fail "pr-body has only <<...>> placeholders" "$leftover"
# Evidence items required by the spec
ev="$(perl -0ne 'print $1 if /^## Evidence\n(.*?)(?=^## |\z)/ms' "$TPL" 2>/dev/null)"
for item in '**Check**' '**Before / after:**' '**Flow:**' 'GIF' 'mp4' '**Tests:**' '**Review:**' '**Risk:**'; do
  grep -qF -- "$item" <<<"$ev" && ok "Evidence has $item" || fail "Evidence has $item" "missing in ## Evidence"
done
grep -qF '<<' "$TPL" 2>/dev/null && ok "pr-body uses <<...>> placeholders" || fail "pr-body uses <<...>> placeholders"

# --- no prompt tells an agent to approve/review a PR on GitHub
bad="$(grep -inE 'gh pr review' "$P"/*/PROMPT.md 2>/dev/null || true)"
for f in "$P"/*/PROMPT.md; do
  hits="$(perl -0e 'local $/; $_=<>; for my $s (split /(?<=[.!?])\s+|\n\s*\n/) { print "$s\n" if $s =~ /approv/i && $s !~ /owner|verdict/i }' "$f")"
  [[ -n "$hits" ]] && bad+="${bad:+$'\n'}${f#"$ROOT"/}: $hits"
done
[[ -z "$bad" ]] && ok "no prompt approves PRs or uses gh pr review" || fail "no prompt approves PRs or uses gh pr review" "$bad"
has "reviewer output has Tier line" "$P/task-reviewer/PROMPT.md" "Tier: risk:"
has "publisher applies reviewer tier" "$P/gh-publisher/PROMPT.md" "reviewer"
grep -qF "what changed and why (2-6 sentences)" "$P/gh-publisher/PROMPT.md" && fail "publisher conventions consistent with Evidence-first template" "old what/why-first bullet remains" || ok "publisher conventions consistent with Evidence-first template"
grep -qF "delete sections that genuinely don't apply" "$P/gh-publisher/PROMPT.md" && fail "publisher may not delete ## Evidence" "old delete-sections wording remains" || ok "publisher may not delete ## Evidence"

# --- forbidden patterns across all prompts (sentence level)
sent_check() { # name, perl-match-regex, perl-exempt-regex
  local out=""
  for f in "$P"/*/PROMPT.md; do
    h="$(perl -0e 'local $/; $_=<>; for my $s (split /(?<=[.!?])\s+|\n\s*\n/) { print "$s\n" if $s =~ /'"$2"'/i && $s !~ /'"$3"'/i }' "$f")"
    [[ -n "$h" ]] && out+="${out:+$'\n'}${f#"$ROOT"/}: $h"
  done
  [[ -z "$out" ]] && ok "$1" || fail "$1" "$out"
}
sent_check "no prompt runs gh pr merge outside a pr-merge.sh sentence" 'gh\s+pr\s+merge' 'pr-merge\.sh'
sent_check "no prompt uses --admin" '--admin' '(?!)'
sent_check "no prompt tells an agent to push to main" 'push(es|ing)?\s+(directly\s+)?(it\s+)?to\s+`?(main|master)' '\b(no|never|not|nor|don.t|without|blocked|deny)\b'
has "publisher never lowers the tier" "$P/gh-publisher/PROMPT.md" "Never lower"
has "publisher re-runs risk-check before merge" "$P/gh-publisher/PROMPT.md" "Before merging"
has "publisher swaps label upward only" "$P/gh-publisher/PROMPT.md" "never swap downward"
has "publisher updates Review line before merge" "$P/gh-publisher/PROMPT.md" "Review line"
has "publisher edits body after pr-create" "$P/gh-publisher/PROMPT.md" "after pr-create"
has "second-pass label means approved review" "$P/gh-publisher/PROMPT.md" "second-pass reviewer APPROVED"
has "reviewer does not request second-pass label" "$P/task-reviewer/PROMPT.md" "never ask for the"
has "publisher scopes pr-merge to GitHub, GitLab not merged by agents" "$P/gh-publisher/PROMPT.md" "not merged by agents"
has "planner defines low tier" "$P/planner/PROMPT.md" "internal tooling"
has "planner high includes payments" "$P/planner/PROMPT.md" "payments"
has "planner picks higher when unsure" "$P/planner/PROMPT.md" "pick the higher"
has "brief has Evidence dir field" "$ROOT/templates/brief.md" "Evidence dir:"
has "implementer references Evidence dir" "$P/implementer/PROMPT.md" "Evidence dir:"
has "ui-qa references Evidence dir" "$P/ui-qa/PROMPT.md" "Evidence dir:"
has "template says to drop Closes line" "$TPL" "delete the Closes line"
grep -qF "(what changed and why, test evidence" "$P/implementer/PROMPT.md" && fail "implementer PR draft matches Evidence-first template" "stale layout remains" || ok "implementer PR draft matches Evidence-first template"

# --- role contracts
has "publisher runs risk-check.sh" "$P/gh-publisher/PROMPT.md" "risk-check.sh"
has "publisher runs evidence-publish.sh" "$P/gh-publisher/PROMPT.md" "evidence-publish.sh"
has "publisher merges via pr-merge.sh" "$P/gh-publisher/PROMPT.md" "pr-merge.sh"
has "reviewer has never-lower rule" "$P/task-reviewer/PROMPT.md" "never lower"
has "reviewer requests second pass for high" "$P/task-reviewer/PROMPT.md" "review:second-pass"
has "planner assigns risk tiers" "$P/planner/PROMPT.md" "risk:"
has "implementer saves evidence files" "$P/implementer/PROMPT.md" "evidence files"
has "ui-qa saves evidence files" "$P/ui-qa/PROMPT.md" "evidence files"

# --- real template through pr-merge.sh's evidence check (fake gh, real --jq)
mkdir "$T/bin"
cat >"$T/bin/gh" <<'FAKE'
#!/usr/bin/env bash
if [[ "$1 $2" == "pr view" ]]; then
  expr=""
  while [[ $# -gt 0 ]]; do [[ "$1" == "--jq" ]] && expr="$2"; shift; done
  json="$(jq -n --rawfile b "$FX_BODY_FILE" '{labels: [{name: "risk:low"}], reviewDecision: "", body: $b, headRefOid: "abc"}')"
  jq -r "$expr" <<<"$json"; exit 0
fi
if [[ "$1 $2" == "pr merge" ]]; then echo merged >>"$GH_MERGE_LOG"; exit 0; fi
exit 1
FAKE
chmod +x "$T/bin/gh"
export PATH="$T/bin:$PATH" GH_MERGE_LOG="$T/merge.log"

FX_BODY_FILE="$TPL"; export FX_BODY_FILE
rm -f "$GH_MERGE_LOG"
"$MERGE" 5 >/dev/null 2>"$T/err"; rc=$?
[[ $rc -eq 3 && ! -e "$GH_MERGE_LOG" ]] && grep -qi "unfilled placeholder" "$T/err" && ok "unfilled template refused by pr-merge.sh (placeholder reason)" || fail "unfilled template refused by pr-merge.sh (placeholder reason)" "rc=$rc $(cat "$T/err")"

# fill every <<...>> (also multi-line) with text
FX_BODY_FILE="$T/filled.md"; export FX_BODY_FILE
perl -0pe 's/<<.*?>>/filled/gs' "$TPL" >"$FX_BODY_FILE"
"$MERGE" 5 >/dev/null 2>"$T/err"; rc=$?
[[ $rc -eq 0 && -s "$GH_MERGE_LOG" ]] && ok "filled template passes pr-merge.sh" || fail "filled template passes pr-merge.sh" "rc=$rc $(cat "$T/err")"

[[ $fails -eq 0 ]] && { echo "all passed"; exit 0; } || { echo "$fails failed"; exit 1; }
