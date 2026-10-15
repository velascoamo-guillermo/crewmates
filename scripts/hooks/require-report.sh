#!/usr/bin/env bash
# SubagentStop hook: an implementer may not finish without a report on disk.
#
# Contract (crewmates/implementer/PROMPT.md): the final message carries a line
# `Report: <absolute path>` and that file is non-empty. Missing either → block
# the stop and tell the subagent what to fix. Catches agents that "park" or
# return a summary without writing the report the controller depends on.
#
# Fails open: unparseable input, other agent types, or a second stop attempt
# (stop_hook_active) are allowed, so a broken hook can never trap an agent.

input=$(cat)

agent=$(jq -r '.agent_type // empty' <<<"$input" 2>/dev/null) || exit 0
[[ "$agent" == "implementer" ]] || exit 0
[[ "$(jq -r '.stop_hook_active // false' <<<"$input")" == "true" ]] && exit 0

msg=$(jq -r '.last_assistant_message // empty' <<<"$input")
# Tolerate markdown models add anyway: CR, indent, bullets, backticks, bold,
# "Report file:". Last matching line wins.
path=$(printf '%s\n' "$msg" | tr -d '\r`' | sed -E 's/\*\*//g; s/^[[:space:]]*([-*][[:space:]]+)?//' \
  | sed -nE 's/^Report( file)?:[[:space:]]*(.*[^[:space:]])[[:space:]]*$/\2/p' | tail -1)
# shellcheck disable=SC2088 # literal "~/" from the message, expanded by hand
[[ "$path" == "~/"* ]] && path="$HOME/${path#\~/}"

block() {
  jq -nc --arg r "$1" '{decision: "block", reason: $r}'
  exit 0
}

[[ -n "$path" ]] || block "Your final message has no 'Report: <absolute path>' line (plain text, last line). Write the full report to the report path from your brief, then end with that line."
[[ "$path" == /* ]] || block "Report path '$path' is relative. End with 'Report: <absolute path>' (plain text, no markdown)."
[[ -s "$path" ]] || block "Report file '$path' is missing or empty. Write the full report there (RED/GREEN evidence, files, branch + SHA, deviations), then finish again."
exit 0
