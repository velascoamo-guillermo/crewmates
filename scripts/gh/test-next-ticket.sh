#!/usr/bin/env bash
# Tests extract_deps from next-ticket.sh. Run: ./scripts/gh/test-next-ticket.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=next-ticket.sh
source "${NEXT_TICKET_SCRIPT:-$HERE/next-ticket.sh}"

fails=0
check() { # name, body, expected (space-joined numbers)
  local got
  got=$(extract_deps <<<"$2" | tr '\n' ' ' | sed 's/ $//')
  if [[ "$got" == "$3" ]]; then echo "ok   - $1"; else echo "FAIL - $1: expected [$3] got [$got]"; fails=$((fails + 1)); fi
}

check "line-start list"        "Depends on: #4, #5" "4 5"
check "mid-line after label"   "Label: \`ticket\`, \`manual\` · Depends on: #5, #9" "5 9"
check "ignores other refs"     "Spec: #1 · Depends on: #3" "3"
check "markdown bold + and"    "**Depends on:** #7 and #15" "7 15"
check "underscore emphasis"    "_Depends on:_ #2" "2"
check "case-insensitive"       "depends ON: #8" "8"
check "none"                   "Depends on: none" ""
check "no depends line"        "Just see #12 for context" ""
check "refs after dep stop"    "Depends on: #4 (see #99)" "4"
check "multiple lines"         $'Depends on: #1\nsome text #50\nDepends on: #2, #3' "1 2 3"

[[ $fails -eq 0 ]] || { echo "$fails failure(s)"; exit 1; }
echo "all passed"
