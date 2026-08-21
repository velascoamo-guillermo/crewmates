#!/usr/bin/env bash
set -euo pipefail

# ensure-labels.sh [--repo group/project]
#
# GitLab twin of gh/ensure-labels.sh. Idempotently creates the standard
# workflow labels. Safe to re-run (create fails silently if label exists).

REPO_ARGS=()
if [[ "${1:-}" == "--repo" ]]; then
  [[ -n "${2:-}" ]] || { echo "usage: ensure-labels.sh [--repo group/project]" >&2; exit 2; }
  REPO_ARGS=(--repo "$2")
fi

# name|color|description
LABELS=(
  "ticket|#1D76DB|Workable unit in the ticket loop"
  "blocked|#D93F0B|Work blocked — needs Guille (access, decision, external dep)"
)

for entry in "${LABELS[@]}"; do
  IFS='|' read -r name color desc <<<"$entry"
  if glab label create --name "$name" --color "$color" --description "$desc" ${REPO_ARGS[@]+"${REPO_ARGS[@]}"} 2>/dev/null; then
    echo "created label: $name"
  else
    echo "exists: $name"
  fi
done
