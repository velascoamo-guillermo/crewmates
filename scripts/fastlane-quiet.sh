#!/usr/bin/env bash
set -euo pipefail

# fastlane-quiet.sh <dir> <lane...>
#
# Kept for existing callers; delegates to quiet.sh (fastlane profile).
#
# Examples:
#   fastlane-quiet.sh ios beta
#   fastlane-quiet.sh apps/pawlog ios beta

[[ $# -ge 2 ]] || { echo "usage: fastlane-quiet.sh <dir> <lane...>" >&2; exit 2; }

DIR="$1"; shift
exec "$(dirname "$0")/quiet.sh" -C "$DIR" --profile fastlane -- bundle exec fastlane "$@"
