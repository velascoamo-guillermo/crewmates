#!/usr/bin/env bash
set -euo pipefail

# fastlane-quiet.sh <dir> <lane...>
#
# Runs a fastlane lane with full output redirected to a log file, printing only
# a short tail — keeps thousands of lines of gym/pod/codesign noise out of
# agent context. On failure prints the last 60 lines and the log path.
#
# Examples:
#   fastlane-quiet.sh ios beta
#   fastlane-quiet.sh apps/pawlog ios beta

[[ $# -ge 2 ]] || { echo "usage: fastlane-quiet.sh <dir> <lane...>" >&2; exit 2; }

DIR="$1"; shift
[[ -d "$DIR" ]] || { echo "not a directory: $DIR" >&2; exit 2; }

log=$(mktemp -t fastlane-quiet)

if (cd "$DIR" && bundle exec fastlane "$@") >"$log" 2>&1; then
  echo "OK: fastlane $* ($(wc -l <"$log" | tr -d ' ') log lines)"
  tail -5 "$log"
  echo "full log: $log"
else
  status=$?
  echo "FAILED: fastlane $* (exit $status) — last 60 lines:"
  tail -60 "$log"
  echo "full log: $log"
  exit "$status"
fi
