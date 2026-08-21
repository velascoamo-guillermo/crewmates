#!/usr/bin/env bash
set -euo pipefail

# maestro-quiet.sh <flow.yaml|flows-dir> [maestro-args...]
#
# Runs a Maestro flow with full output redirected to a log file, printing only
# a short tail. Same pattern as fastlane-quiet.sh: keeps driver noise out of
# agent context. On failure prints the last 60 lines and the log path.

[[ $# -ge 1 ]] || { echo "usage: maestro-quiet.sh <flow.yaml|flows-dir> [maestro-args...]" >&2; exit 2; }
[[ -e "$1" ]] || { echo "flow not found: $1" >&2; exit 2; }
command -v maestro >/dev/null 2>&1 || { echo "maestro not installed: https://maestro.mobile.dev" >&2; exit 1; }

log=$(mktemp -t maestro-quiet)

if maestro test "$@" >"$log" 2>&1; then
  echo "OK: maestro test $* ($(wc -l <"$log" | tr -d ' ') log lines)"
  tail -5 "$log"
  echo "full log: $log"
else
  status=$?
  echo "FAILED: maestro test $* (exit $status) — last 60 lines:"
  tail -60 "$log"
  echo "full log: $log"
  exit "$status"
fi
