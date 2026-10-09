#!/usr/bin/env bash
set -euo pipefail

# quiet.sh [-C <dir>] [--profile <name>] -- <cmd...>
# quiet.sh --detect <cmd...>
#
# Runs a build/test command with full output (ANSI-stripped) in a log file and
# prints only what an agent needs: on success a one-line verdict plus the
# summary lines; on failure the error/failing-test lines picked by a per-tool
# profile, then the last few lines and the log path. Keeps thousands of lines
# of compiler/driver noise out of agent context.
#
# Profiles (auto-detected from the command, override with --profile):
#   xcodebuild  gradle  jest  bun  maestro  fastlane  generic
#
# Env: QUIET_LOG_DIR (default $TMPDIR or /tmp)
#
# Examples:
#   quiet.sh -- xcodebuild test -project App.xcodeproj -scheme App -destination 'platform=macOS'
#   quiet.sh -C android -- ./gradlew testDebugUnitTest
#   quiet.sh -- pnpm jest src/cart
#   quiet.sh -C apps/pawlog -- bundle exec fastlane ios beta

usage() { echo "usage: quiet.sh [-C <dir>] [--profile <name>] -- <cmd...>  |  quiet.sh --detect <cmd...>" >&2; exit 2; }

detect() {
  local prev="" w base
  for w in "$@"; do
    base="${w##*/}"
    case "$base" in
      xcodebuild) echo xcodebuild; return ;;
      gradlew | gradle) echo gradle; return ;;
      jest) echo jest; return ;;
      fastlane) echo fastlane; return ;;
      maestro) echo maestro; return ;;
      test) [[ "$prev" == "bun" ]] && { echo bun; return; } ;;
    esac
    prev="$base"
  done
  echo generic
}

# Per profile: OK_PAT (summary lines on success), FAIL_PAT (lines worth showing
# on failure), FAIL_AFTER/FAIL_BEFORE (context lines around each failure match).
load_profile() {
  OK_PAT="" FAIL_PAT="" FAIL_AFTER=0 FAIL_BEFORE=0
  case "$1" in
    xcodebuild)
      OK_PAT='\*\* (BUILD|TEST|ARCHIVE) SUCCEEDED \*\*|Executed [0-9]+ tests?, with|Test run with [0-9]+ tests'
      FAIL_PAT='(error|fatal error): |Test Case .* failed|✘ |recorded an issue|Expectation failed|\*\* (BUILD|TEST|ARCHIVE) FAILED \*\*|Executed [0-9]+ tests?, with|Test run with [0-9]+ tests|Testing failed:' ;;
    gradle)
      OK_PAT='BUILD SUCCESSFUL|[0-9]+ tests? completed|actionable tasks?:'
      FAIL_PAT='^e: |error:|What went wrong|FAILED|[0-9]+ tests? completed|Caused by:'
      FAIL_AFTER=3 ;;
    jest)
      OK_PAT='^(Tests|Test Suites|Snapshots|Time):'
      FAIL_PAT='●|^ *FAIL |^(Tests|Test Suites):'
      FAIL_AFTER=12 ;;
    bun)
      OK_PAT='^ *[0-9]+ (pass|fail)|^Ran [0-9]+ tests'
      FAIL_PAT='\(fail\)|^ *[0-9]+ (pass|fail)|^Ran [0-9]+ tests'
      FAIL_BEFORE=8 ;;
    maestro)
      OK_PAT='Passed|✅|Flows? Passed'
      FAIL_PAT='FAILED|Failed|✗|❌|Assertion|is not visible|not found'
      FAIL_AFTER=2 ;;
    fastlane)
      OK_PAT='fastlane\.tools finished successfully|Successfully'
      FAIL_PAT='\[!\]|error:|ERROR|FAILED|Exit status'
      FAIL_AFTER=2 ;;
    generic) ;;
    *) echo "unknown profile: $1" >&2; exit 2 ;;
  esac
}

dir="" profile=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -C) dir="${2:?-C needs a directory}"; shift 2 ;;
    --profile) profile="${2:?--profile needs a name}"; shift 2 ;;
    --detect) shift; [[ $# -gt 0 ]] || usage; echo "profile=$(detect "$@")"; exit 0 ;;
    --) shift; break ;;
    -*) usage ;;
    *) break ;;
  esac
done
[[ $# -gt 0 ]] || usage
[[ -z "$dir" || -d "$dir" ]] || { echo "not a directory: $dir" >&2; exit 2; }

profile="${profile:-$(detect "$@")}"
load_profile "$profile"

log_dir="${QUIET_LOG_DIR:-${TMPDIR:-/tmp}}"
log=$(mktemp "${log_dir%/}/quiet-$profile.XXXXXX")

start=$SECONDS
set +e
( [[ -n "$dir" ]] && cd "$dir"; "$@" ) 2>&1 | perl -pe 's/\e\[[0-9;?]*[A-Za-z]//g' >"$log"
status=${PIPESTATUS[0]}
set -e
elapsed=$((SECONDS - start))
lines=$(wc -l <"$log" | tr -d ' ')
# The caller knows its own command; naming the tool is enough and keeps arguments out of context.
tool="${1##*/}"

# pick <pattern> <after> <before> <limit>: matching lines with context, deduplicated
pick() {
  [[ -n "$1" ]] || return 0
  grep -E -A "$2" -B "$3" -- "$1" "$log" | grep -v '^--$' | awk '!seen[$0]++' | head -"$4" || true
}

if [[ $status -eq 0 ]]; then
  echo "OK: $tool (${lines} log lines, ${elapsed}s, profile=$profile)"
  summary=$(pick "$OK_PAT" 0 0 200 | tail -8)
  if [[ -n "$summary" ]]; then echo "$summary"; else tail -5 "$log"; fi
else
  echo "FAILED: $tool (exit $status, ${lines} log lines, ${elapsed}s, profile=$profile)"
  found=$(pick "$FAIL_PAT" "$FAIL_AFTER" "$FAIL_BEFORE" 80)
  if [[ -n "$found" ]]; then
    echo "$found"
    echo "--- last 5 lines:"
    tail -5 "$log"
  else
    tail -60 "$log"
  fi
fi
echo "full log: $log"
exit "$status"
