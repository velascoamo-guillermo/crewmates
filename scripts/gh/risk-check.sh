#!/usr/bin/env bash
# Decide from touched paths alone whether a change must be risk:high.
# Usage: risk-check.sh [--base <ref>] [--config <file>]
# Prints "risk:high" + one "  <path>  (<glob>)" line per match, or "no-escalation". Exit 2 on usage errors.
set -euo pipefail

DEFAULTS=(
  '*migrations/*' '*.sql' '.github/*' 'infra/*' 'k8s/*' 'terraform/*' '*.tf'
  '*auth/*' '*Auth*' '*secrets*' '*.env*' 'fastlane/*' '*Podfile.lock'
)

usage() { echo "usage: risk-check.sh [--base <ref>] [--config <file>]" >&2; exit 2; }

base="" config=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) [[ $# -ge 2 ]] || usage; base="$2"; shift 2 ;;
    --config) [[ $# -ge 2 ]] || usage; config="$2"; shift 2 ;;
    *) usage ;;
  esac
done

git rev-parse --git-dir >/dev/null 2>&1 || { echo "risk-check: not a git repo" >&2; exit 2; }
root="$(git rev-parse --show-toplevel)"

if [[ -z "$base" ]]; then
  if git rev-parse --verify -q "origin/main^{commit}" >/dev/null; then base="origin/main"; else base="main"; fi
fi
git rev-parse --verify -q "$base^{commit}" >/dev/null || { echo "risk-check: bad base ref: $base" >&2; exit 2; }

if [[ -z "$config" && -f "$root/.crewmates/risk-high-paths" ]]; then config="$root/.crewmates/risk-high-paths"; fi

globs=()
if [[ -n "$config" ]]; then
  [[ -f "$config" ]] || { echo "risk-check: config not found: $config" >&2; exit 2; }
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    globs+=("$line")
  done <"$config"
else
  globs=("${DEFAULTS[@]}")
fi

tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
git -c core.quotePath=false -c diff.relative=false -c diff.renames=false \
  diff --name-only -z --no-renames "$base...HEAD" >"$tmp" || { echo "risk-check: git diff failed" >&2; exit 2; }

matches=""
while IFS= read -r -d '' path; do
  [[ -z "$path" ]] && continue
  for g in ${globs[@]+"${globs[@]}"}; do
    # shellcheck disable=SC2053
    if [[ $path == $g ]]; then matches+="  $path  ($g)"$'\n'; break; fi
  done
done <"$tmp"

if [[ -n "$matches" ]]; then
  echo "risk:high"
  printf '%s' "$matches"
else
  echo "no-escalation"
fi
