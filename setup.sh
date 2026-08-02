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

echo "done: adapters in ~/.claude/agents and ~/.config/opencode/agent"
