#!/usr/bin/env bash
set -euo pipefail

# Bootstrap crewmates on a machine: generate adapters + set CREWMATES_HOME.
# Usage: ./setup.sh   (run from anywhere; idempotent)

cd "$(cd "$(dirname "$0")" && pwd)"

command -v bun >/dev/null 2>&1 || {
  echo "bun is required. Install: curl -fsSL https://bun.sh/install | bash" >&2
  exit 1
}

bun run generate

ZSHRC="$HOME/.zshrc"
if ! grep -q 'CREWMATES_HOME' "$ZSHRC" 2>/dev/null; then
  printf '\nexport CREWMATES_HOME="%s"\n' "$(pwd)" >> "$ZSHRC"
  echo "added CREWMATES_HOME to $ZSHRC — restart your shell"
else
  echo "CREWMATES_HOME already in $ZSHRC"
fi

# Symlink skills into ~/.claude/skills (loaded on demand by description match)
SKILLS_DIR="$HOME/.claude/skills"
if [[ -d skills ]]; then
  mkdir -p "$SKILLS_DIR"
  for skill in skills/*/; do
    name=$(basename "$skill")
    target="$SKILLS_DIR/$name"
    if [[ -L "$target" || ! -e "$target" ]]; then
      ln -sfn "$(pwd)/skills/$name" "$target"
      echo "linked skill: $name"
    else
      echo "skip skill $name: $target exists and is not a symlink" >&2
    fi
  done
fi

# Wire ticket-loop hooks into ~/.claude/settings.json (idempotent, backup first).
# SubagentStop(implementer) enforces the report; SessionStart(compact) re-injects
# the ledger after compaction. Skips any hook whose command is already present.
SETTINGS="$HOME/.claude/settings.json"
if command -v jq >/dev/null 2>&1; then
  [[ -f "$SETTINGS" ]] || echo '{}' > "$SETTINGS"
  add_hook() { # add_hook <event> <matcher> <script>
    local cmd="bash \"$(pwd)/scripts/hooks/$3\""
    if jq -e --arg c "$cmd" '[.. | .command? // empty] | index($c)' "$SETTINGS" >/dev/null; then
      echo "hook $3 already wired"; return
    fi
    cp "$SETTINGS" "$SETTINGS.bak"
    jq --arg e "$1" --arg m "$2" --arg c "$cmd" \
      '.hooks[$e] = ((.hooks[$e] // []) + [{matcher: $m, hooks: [{type: "command", command: $c, timeout: 10}]}])' \
      "$SETTINGS.bak" > "$SETTINGS"
    echo "wired hook $3 ($1/$2)"
  }
  add_hook SubagentStop implementer require-report.sh
  add_hook SessionStart compact ledger-reanchor.sh
else
  echo "skip hooks: jq not installed" >&2
fi

echo "done: adapters in ~/.claude/agents and ~/.config/opencode/agent; skills in ~/.claude/skills; hooks in $SETTINGS"
