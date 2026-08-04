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

echo "done: adapters in ~/.claude/agents and ~/.config/opencode/agent; skills in ~/.claude/skills"
