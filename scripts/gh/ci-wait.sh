#!/usr/bin/env bash
set -euo pipefail

# ci-wait.sh [pr-number]
#
# Blocks until all PR checks finish. Exit 0 = all green, non-zero = failure.
# Without an argument, uses the PR of the current branch.

gh pr checks "${1:-}" --watch --fail-fast
