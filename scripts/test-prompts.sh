#!/usr/bin/env bash
# Offline contract tests for the agent prompts and templates/pr-body.md.
# Run: ./scripts/test-prompts.sh   (needs jq)
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
# every <...> outside code must be a <<...>> placeholder; no <word> style
single="$(grep -E '(^|[^<])<[A-Za-z0-9][^<>]*>($|[^>])' "$TPL" 2>/dev/null || true)"
[[ -z "$single" ]] && ok "pr-body has no <word> placeholders" || fail "pr-body has no <word> placeholders" "$single"
grep -qF '<<' "$TPL" 2>/dev/null && ok "pr-body uses <<...>> placeholders" || fail "pr-body uses <<...>> placeholders"

# --- no prompt tells an agent to approve/review a PR on GitHub
bad="$(grep -inE 'gh pr review|approve (the|this|a|that|each|every|any)? ?(PR|pull request)|approve it on github' "$P"/*/PROMPT.md 2>/dev/null || true)"
[[ -z "$bad" ]] && ok "no prompt approves PRs or uses gh pr review" || fail "no prompt approves PRs or uses gh pr review" "$bad"

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
[[ $rc -eq 3 && ! -e "$GH_MERGE_LOG" ]] && ok "unfilled template refused by pr-merge.sh" || fail "unfilled template refused by pr-merge.sh" "rc=$rc"

# fill every <<...>> (also multi-line) with text
FX_BODY_FILE="$T/filled.md"; export FX_BODY_FILE
perl -0pe 's/<<.*?>>/filled/gs' "$TPL" >"$FX_BODY_FILE"
"$MERGE" 5 >/dev/null 2>"$T/err"; rc=$?
[[ $rc -eq 0 && -s "$GH_MERGE_LOG" ]] && ok "filled template passes pr-merge.sh" || fail "filled template passes pr-merge.sh" "rc=$rc $(cat "$T/err")"

[[ $fails -eq 0 ]] && { echo "all passed"; exit 0; } || { echo "$fails failed"; exit 1; }
