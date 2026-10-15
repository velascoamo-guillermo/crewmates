#!/usr/bin/env bash
set -euo pipefail

# wire.sh <settings.json> <crewmates-root>
#
# Merge the ticket-loop hooks into a Claude Code settings file. Safe by
# construction: refuses invalid JSON, writes to a temp file and validates it
# before an atomic mv, backs up the original (timestamped) only when it is
# about to change. Entries are keyed by script name, so a moved/re-cloned
# repo replaces its old entry instead of duplicating it.

[[ $# -eq 2 ]] || { echo "usage: wire.sh <settings.json> <crewmates-root>" >&2; exit 2; }
SETTINGS="$1" ROOT="$2"

[[ -e "$SETTINGS" ]] || { mkdir -p "$(dirname "$SETTINGS")"; echo '{}' > "$SETTINGS"; }
# Dotfile setups symlink settings.json: operate on the real file so the link
# survives the atomic mv.
while [[ -L "$SETTINGS" ]]; do
  link=$(readlink "$SETTINGS")
  [[ "$link" == /* ]] && SETTINGS="$link" || SETTINGS="$(dirname "$SETTINGS")/$link"
done
jq -e 'type == "object"' "$SETTINGS" >/dev/null 2>&1 \
  || { echo "wire: $SETTINGS is not valid JSON — fix it first, nothing changed" >&2; exit 1; }

tmp=$(mktemp "$SETTINGS.tmp.XXXXXX")
trap 'rm -f "$tmp"' EXIT
cp -p "$SETTINGS" "$tmp" # carry permissions over to the replacement

jq --arg root "$ROOT" '
  def wire($event; $matcher; $script):
    ("bash \"" + $root + "/scripts/hooks/" + $script + "\"") as $cmd
    | .hooks[$event] = (
        [ (.hooks[$event] // [])[]
          | .hooks = [ .hooks[]? | select((.command // "") | endswith("/scripts/hooks/" + $script + "\"") | not) ]
          | select((.hooks | length) > 0) ]
        + [ { matcher: $matcher, hooks: [ { type: "command", command: $cmd, timeout: 10 } ] } ] );
  .hooks = (.hooks // {})
  | wire("SubagentStop"; "implementer"; "require-report.sh")
  | wire("SessionStart"; "compact"; "ledger-reanchor.sh")
' "$SETTINGS" > "$tmp"

jq -e 'type == "object" and (.hooks | type == "object")' "$tmp" >/dev/null \
  || { echo "wire: merge produced invalid output, nothing changed" >&2; exit 1; }

if jq -S . "$SETTINGS" | cmp -s - <(jq -S . "$tmp"); then
  echo "hooks already wired in $SETTINGS"
  exit 0
fi

base="$SETTINGS.bak.$(date +%Y%m%d%H%M%S)" n=0
bak="$base"
while [[ -e "$bak" ]]; do n=$((n + 1)); bak="$base-$n"; done # never overwrite a backup
cp -p "$SETTINGS" "$bak"
mv "$tmp" "$SETTINGS"
echo "wired hooks in $SETTINGS (backup: $bak)"
