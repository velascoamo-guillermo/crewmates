#!/usr/bin/env bash
# SessionStart hook (matcher: compact): after compaction, re-inject the tail
# of the ticket-loop ledger so the controller resumes from recorded state
# instead of a lossy summary. Silent when the repo has no ledger.

input=$(cat)

[[ "$(jq -r '.source // empty' <<<"$input" 2>/dev/null)" == "compact" ]] || exit 0
cwd=$(jq -r '.cwd // empty' <<<"$input")
ledger="$cwd/.superpowers/sdd/progress.md"
[[ -s "$ledger" ]] || exit 0

lines=${CREWMATES_LEDGER_TAIL:-20}
echo "Ticket-loop ledger ($ledger), last $lines lines. The last line per ticket is where to resume; never redo work recorded as merged. Per-ticket checkpoints: $cwd/.superpowers/sdd/ticket-<N>.md"
echo '```'
tail -n "$lines" "$ledger"
echo '```'
