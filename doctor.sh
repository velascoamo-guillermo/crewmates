#!/usr/bin/env bash
set -uo pipefail

# doctor.sh — verify the crewmates toolkit is healthy on this machine.
#
# Checks: required tools, CREWMATES_HOME, skill symlinks, script permissions,
# and adapter staleness (source edited but `bun run generate` not re-run).
# Exit 0 = healthy (warnings allowed), 1 = at least one failure.

cd "$(cd "$(dirname "$0")" && pwd)" || exit 1

FAILURES=0 WARNINGS=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; WARNINGS=$((WARNINGS + 1)); }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAILURES=$((FAILURES + 1)); }

echo "tools"
for tool in gh jq git; do
  if command -v "$tool" >/dev/null 2>&1; then ok "$tool"; else fail "$tool missing"; fi
done
if command -v bun >/dev/null 2>&1; then ok "bun"; else fail "bun missing (generator needs it)"; fi
if command -v pnpm >/dev/null 2>&1; then ok "pnpm"; else warn "pnpm missing (default package manager)"; fi
if gh auth status >/dev/null 2>&1; then ok "gh authenticated"; else fail "gh not authenticated — run: gh auth login"; fi

echo "environment"
if [[ "${CREWMATES_HOME:-}" == "$(pwd)" ]]; then
  ok "CREWMATES_HOME set correctly"
elif [[ -n "${CREWMATES_HOME:-}" ]]; then
  warn "CREWMATES_HOME=$CREWMATES_HOME but repo is $(pwd)"
else
  warn "CREWMATES_HOME not set in this shell (setup.sh adds it to ~/.zshrc)"
fi

echo "scripts"
nonexec=$(find scripts -name '*.sh' ! -perm -u+x | wc -l | tr -d ' ')
if [[ "$nonexec" -eq 0 ]]; then ok "all scripts executable"; else fail "$nonexec script(s) not executable — run: chmod +x scripts/**/*.sh"; fi

echo "skills"
for skill in skills/*/; do
  name=$(basename "$skill")
  target="$HOME/.claude/skills/$name"
  if [[ -L "$target" && "$(readlink "$target")" == "$(pwd)/skills/$name" ]]; then
    ok "skill linked: $name"
  elif [[ -e "$target" ]]; then
    fail "skill $name: $target exists but is not a symlink to this repo — run ./setup.sh"
  else
    fail "skill not linked: $name — run ./setup.sh"
  fi
done

echo "adapters"
if command -v bun >/dev/null 2>&1; then
  tmp=$(mktemp -d)
  if bun scripts/generate-adapters.ts --claude-out "$tmp/claude" --opencode-out "$tmp/opencode" >/dev/null 2>&1; then
    stale=0
    for f in "$tmp"/claude/*.md; do
      name=$(basename "$f")
      installed="$HOME/.claude/agents/$name"
      if [[ ! -f "$installed" ]]; then
        fail "adapter not installed: $name — run: bun run generate"
        stale=1
      elif ! diff -q "$f" "$installed" >/dev/null 2>&1; then
        fail "adapter stale: $name (source changed since last generate) — run: bun run generate"
        stale=1
      fi
    done
    for f in "$tmp"/opencode/*.md; do
      name=$(basename "$f")
      installed="$HOME/.config/opencode/agent/$name"
      if [[ ! -f "$installed" ]]; then
        warn "opencode adapter not installed: $name"
      elif ! diff -q "$f" "$installed" >/dev/null 2>&1; then
        warn "opencode adapter stale: $name — run: bun run generate"
      fi
    done
    [[ "$stale" -eq 0 ]] && ok "claude-code adapters up to date"
  else
    fail "generator failed — run: bun run generate (see errors)"
  fi
  rm -rf "$tmp"
fi

echo
if [[ "$FAILURES" -gt 0 ]]; then
  echo "doctor: $FAILURES failure(s), $WARNINGS warning(s)"
  exit 1
fi
echo "doctor: healthy ($WARNINGS warning(s))"
