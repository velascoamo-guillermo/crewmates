#!/usr/bin/env bash
set -uo pipefail

# test-quiet.sh — behaviour tests for scripts/quiet.sh using fake tool output.
# Each case runs a fake command through quiet.sh and checks what reaches stdout.

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
QUIET="$ROOT/scripts/quiet.sh"
fail=0

# noise <n>: n lines of filler, standing in for compiler/driver chatter
noise() { for ((i = 0; i < $1; i++)); do echo "noise line $i"; done; }
export -f noise

check() { # check <name> <expected-exit> <cmd...> ; reads expectations from globals
  local name="$1" want_exit="$2"; shift 2
  local out code
  out=$("$@" 2>&1); code=$?
  local ok=1
  [[ "$code" == "$want_exit" ]] || { echo "FAIL $name: exit $code, want $want_exit"; ok=0; }
  local p
  for p in "${MUST[@]}"; do
    grep -qF -- "$p" <<<"$out" || { echo "FAIL $name: missing '$p'"; ok=0; }
  done
  for p in "${MUST_NOT[@]}"; do
    grep -qF -- "$p" <<<"$out" && { echo "FAIL $name: should not contain '$p'"; ok=0; }
  done
  local lines; lines=$(wc -l <<<"$out" | tr -d ' ')
  [[ "$lines" -le "${MAX_LINES:-40}" ]] || { echo "FAIL $name: $lines lines > ${MAX_LINES:-40}"; ok=0; }
  if [[ $ok == 1 ]]; then echo "ok   $name"; else echo "---- output:"; echo "$out"; echo "----"; fail=1; fi
}

# --- xcodebuild: early compile error must survive 500 lines of later noise
MUST=("FAILED" "Foo.swift:12:5: error: cannot find 'Bar' in scope" "** BUILD FAILED **" "full log:")
MUST_NOT=("noise line 250")
MAX_LINES=40
check "xcodebuild compile error" 65 "$QUIET" --profile xcodebuild -- bash -c '
  echo "/src/Foo.swift:12:5: error: cannot find '"'"'Bar'"'"' in scope"; noise 500; echo "** BUILD FAILED **"; exit 65'

# --- xcodebuild: scattered XCTest + Swift Testing failures, success counts
MUST=("Test Case '-[MacSmokeTests testReturn]' failed" "✘ Test \"a due task\" failed" "** TEST FAILED **")
MUST_NOT=("noise line 10")
check "xcodebuild test failures" 65 "$QUIET" --profile xcodebuild -- bash -c '
  noise 200; echo "Test Case '"'"'-[MacSmokeTests testReturn]'"'"' failed (3.2 seconds)."
  noise 200; echo "✘ Test \"a due task\" failed after 0.1 seconds."; noise 50; echo "** TEST FAILED **"; exit 65'

MUST=("OK" "Executed 12 tests, with 0 failures" "** TEST SUCCEEDED **")
MUST_NOT=("noise line 3")
MAX_LINES=10
check "xcodebuild success is short" 0 "$QUIET" --profile xcodebuild -- bash -c '
  noise 800; echo "Executed 12 tests, with 0 failures (0 unexpected) in 4.1 seconds"; echo "** TEST SUCCEEDED **"'

# --- gradle: "What went wrong" block keeps its following lines
MUST=("What went wrong:" "Execution failed for task ':app:compileDebugKotlin'." "e: file:///A.kt:3:1 Unresolved reference: foo" "BUILD FAILED")
MUST_NOT=("noise line 100")
MAX_LINES=40
check "gradle failure" 1 "$QUIET" --profile gradle -- bash -c '
  noise 300; echo "e: file:///A.kt:3:1 Unresolved reference: foo"; noise 100
  echo "* What went wrong:"; echo "Execution failed for task '"'"':app:compileDebugKotlin'"'"'."; echo "BUILD FAILED in 9s"; exit 1'

# --- jest: ANSI colour stripped, failing test block + summary kept
MUST=("● Cart › adds item" "Expected: 2" "Tests:       1 failed, 9 passed, 10 total")
MUST_NOT=($'\e[31m' "noise line 50")
check "jest failure" 1 "$QUIET" --profile jest -- bash -c '
  noise 100; printf "\e[31m● Cart › adds item\e[0m\n"; echo "    Expected: 2"; echo "    Received: 1"
  noise 100; echo "Tests:       1 failed, 9 passed, 10 total"; exit 1'

# --- auto-detect: --detect prints the profile a command would get, runs nothing
MUST_NOT=()
MAX_LINES=5
MUST=("profile=jest")
check "detect npx jest" 0 "$QUIET" --detect npx jest --ci
MUST=("profile=gradle")
check "detect gradlew" 0 "$QUIET" --detect ./gradlew test
MUST=("profile=xcodebuild")
check "detect xcodebuild" 0 "$QUIET" --detect xcodebuild test -scheme X
MUST=("profile=jest")
check "detect pnpm jest" 0 "$QUIET" --detect pnpm jest --ci
MUST=("profile=bun")
check "detect bun test" 0 "$QUIET" --detect bun test
MUST=("profile=fastlane")
check "detect bundle exec fastlane" 0 "$QUIET" --detect bundle exec fastlane ios beta
MUST=("profile=maestro")
check "detect maestro" 0 "$QUIET" --detect maestro test flow.yaml
MUST=("profile=generic")
check "detect unknown" 0 "$QUIET" --detect make all

# --- generic: unknown failure falls back to tail
MUST=("last line before exit" "FAILED")
MUST_NOT=("noise line 5")
MAX_LINES=70
check "generic failure tail" 3 "$QUIET" -- bash -c 'noise 300; echo "last line before exit"; exit 3'

# --- -C runs in a directory; missing command after -- is a usage error
MUST=("OK")
MUST_NOT=()
MAX_LINES=10
check "-C dir" 0 "$QUIET" -C "$ROOT/scripts" -- test -f quiet.sh
MUST=("usage:")
check "usage error" 2 "$QUIET" --

exit $fail
