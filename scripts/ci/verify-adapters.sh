#!/usr/bin/env bash
set -euo pipefail

# verify-adapters.sh <claude-out-dir> <opencode-out-dir>
#
# Structural checks on generated adapters: one file per crewmate per harness,
# valid frontmatter delimiters, description present, non-empty body.

[[ $# -eq 2 ]] || { echo "usage: verify-adapters.sh <claude-out> <opencode-out>" >&2; exit 2; }

CLAUDE_OUT="$1" OPENCODE_OUT="$2"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
fail=0

for dir in "$ROOT"/crewmates/*/; do
  name=$(basename "$dir")
  for out in "$CLAUDE_OUT/$name.md" "$OPENCODE_OUT/$name.md"; do
    if [[ ! -s "$out" ]]; then
      echo "FAIL missing or empty: $out"
      fail=1
      continue
    fi
    [[ "$(head -1 "$out")" == "---" ]] || { echo "FAIL no frontmatter open: $out"; fail=1; }
    grep -q '^description:' "$out" || { echo "FAIL no description: $out"; fail=1; }
    # body = content after the second '---'
    body_lines=$(awk 'c==2{n++} /^---$/{c++} END{print n+0}' "$out")
    [[ "$body_lines" -gt 0 ]] || { echo "FAIL empty body: $out"; fail=1; }
    [[ $fail -eq 0 ]] && echo "OK $out"
  done
done

exit "$fail"
