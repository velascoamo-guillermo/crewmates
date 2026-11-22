#!/usr/bin/env bash
set -euo pipefail

# ensure-labels.sh [--repo owner/name]
#
# Idempotently creates the standard workflow labels used by the ticket loop.
# Run once per repo (safe to re-run).

REPO_ARGS=()
if [[ "${1:-}" == "--repo" ]]; then
  [[ -n "${2:-}" ]] || { echo "usage: ensure-labels.sh [--repo owner/name]" >&2; exit 2; }
  REPO_ARGS=(--repo "$2")
fi

# name|color|description
LABELS=(
  "ticket|1D76DB|Workable unit in the GitHub-first ticket loop"
  "blocked|D93F0B|Work blocked — needs Guille (access, decision, external dep)"
  "risk:low|2DA44E|Low risk (docs, copy, styling, tests, patch bumps): auto-merge after APPROVE + green CI"
  "risk:medium|FBCA04|Ordinary features and bugfixes: owner approves on GitHub before merge"
  "risk:high|D73A4A|High risk (auth, payments, schema, deletion, CI, infra, prod): owner approval after 2nd review"
  "review:second-pass|8250DF|Second independent review (/code-review high) completed for a risk:high PR"
  "spec|C5DEF5|Pinned spec issue (source of truth for a body of work)"
)

for entry in "${LABELS[@]}"; do
  IFS='|' read -r name color desc <<<"$entry"
  if gh label create "$name" --color "$color" --description "$desc" ${REPO_ARGS[@]+"${REPO_ARGS[@]}"} 2>/dev/null; then
    echo "created label: $name"
  else
    echo "exists: $name"
  fi
done
