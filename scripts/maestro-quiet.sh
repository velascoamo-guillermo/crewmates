#!/usr/bin/env bash
set -euo pipefail

# maestro-quiet.sh <flow.yaml|flows-dir> [maestro-args...]
#
# Kept for existing callers; delegates to quiet.sh (maestro profile).

[[ $# -ge 1 ]] || { echo "usage: maestro-quiet.sh <flow.yaml|flows-dir> [maestro-args...]" >&2; exit 2; }
[[ -e "$1" ]] || { echo "flow not found: $1" >&2; exit 2; }
command -v maestro >/dev/null 2>&1 || { echo "maestro not installed: https://maestro.mobile.dev" >&2; exit 1; }

exec "$(dirname "$0")/quiet.sh" --profile maestro -- maestro test "$@"
