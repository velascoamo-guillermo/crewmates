#!/usr/bin/env bash
set -euo pipefail

# ci-wait.sh [branch] [--timeout <seconds>]
#
# GitLab twin of gh/ci-wait.sh. Polls the latest pipeline for the branch
# (default: current) until it finishes. Exit 0 = success, 1 = failed/canceled,
# 2 = timeout. Uses the REST API via `glab api` for stable output.

BRANCH="" TIMEOUT=1800

while [[ $# -gt 0 ]]; do
  case "$1" in
    --timeout) TIMEOUT="$2"; shift 2 ;;
    *) BRANCH="$1"; shift ;;
  esac
done

[[ -n "$BRANCH" ]] || BRANCH=$(git rev-parse --abbrev-ref HEAD)

elapsed=0
interval=15

while :; do
  status=$(glab api "projects/:id/pipelines?ref=$BRANCH&per_page=1" | jq -r '.[0].status // "none"')
  case "$status" in
    success)
      echo "pipeline succeeded ($BRANCH)"
      exit 0
      ;;
    failed | canceled)
      echo "pipeline $status ($BRANCH)" >&2
      exit 1
      ;;
    none)
      echo "no pipeline found for $BRANCH yet (waiting)"
      ;;
    *)
      echo "pipeline $status ($BRANCH, ${elapsed}s)"
      ;;
  esac
  if (( elapsed >= TIMEOUT )); then
    echo "timeout after ${TIMEOUT}s" >&2
    exit 2
  fi
  sleep "$interval"
  elapsed=$((elapsed + interval))
done
