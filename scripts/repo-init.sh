#!/usr/bin/env bash
set -euo pipefail

# repo-init.sh --name <repo> [--owner <login>] [--public] [--board] [--check <ctx>]... [--dry-run]
#
# Bootstraps the GitHub-first ticket-loop pattern for the CURRENT directory:
#   1. git init (branch main) if not a repo yet
#   2. gh repo create (private by default), current dir as source, push
#   3. Standard workflow labels (ticket, blocked)
#   4. --board: Projects v2 board titled like the repo, linked to it
#   5. Branch protection on main: force pushes and deletions blocked;
#      --check <context> (repeatable) adds required status checks
#
# --dry-run prints the mutating commands instead of executing them.

NAME="" OWNER="" VISIBILITY="--private" BOARD=false DRY=false CHECKS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --owner) OWNER="$2"; shift 2 ;;
    --public) VISIBILITY="--public"; shift ;;
    --board) BOARD=true; shift ;;
    --check) CHECKS+=("$2"); shift 2 ;;
    --dry-run) DRY=true; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$NAME" ]] || { echo "usage: repo-init.sh --name <repo> [--owner <login>] [--public] [--board] [--check <ctx>]... [--dry-run]" >&2; exit 2; }
[[ -n "$OWNER" ]] || OWNER=$(gh api user --jq .login)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

run() {
  if $DRY; then echo "+ $*"; else "$@"; fi
}

# 1. local git
if [[ ! -d .git ]]; then
  run git init -b main
fi

if ! git rev-parse HEAD >/dev/null 2>&1 && ! $DRY; then
  echo "no commits yet — make an initial commit first, then re-run" >&2
  exit 1
fi

# 2. remote repo + push
run gh repo create "$OWNER/$NAME" "$VISIBILITY" --source . --remote origin --push

# 3. labels
run "$SCRIPT_DIR/gh/ensure-labels.sh" --repo "$OWNER/$NAME"

# 4. board
if $BOARD; then
  if $DRY; then
    echo "+ gh project create --owner $OWNER --title $NAME"
    echo "+ gh project link <number> --owner $OWNER --repo $OWNER/$NAME"
  else
    number=$(gh project create --owner "$OWNER" --title "$NAME" --format json --jq '.number')
    gh project link "$number" --owner "$OWNER" --repo "$OWNER/$NAME"
    echo "board #$number linked"
  fi
fi

# 5. branch protection on main
contexts_json=$(printf '%s\n' ${CHECKS[@]+"${CHECKS[@]}"} | jq -R . | jq -s 'map(select(length > 0))')
protection=$(jq -n --argjson contexts "$contexts_json" '{
  required_status_checks: (if ($contexts | length) > 0 then {strict: true, contexts: $contexts} else null end),
  enforce_admins: false,
  required_pull_request_reviews: null,
  restrictions: null,
  allow_force_pushes: false,
  allow_deletions: false
}')

if $DRY; then
  echo "+ gh api -X PUT repos/$OWNER/$NAME/branches/main/protection <<< $protection"
else
  echo "$protection" | gh api -X PUT "repos/$OWNER/$NAME/branches/main/protection" --input - >/dev/null
  echo "branch protection set on main"
fi

echo "done: https://github.com/$OWNER/$NAME"
