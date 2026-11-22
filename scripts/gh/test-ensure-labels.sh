#!/usr/bin/env bash
# Tests ensure-labels.sh with a fake gh on PATH. Run: ./scripts/gh/test-ensure-labels.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${ENSURE_LABELS_SCRIPT:-$HERE/ensure-labels.sh}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
cat >"$TMP/bin/gh" <<'FAKE'
#!/usr/bin/env bash
# fake gh: records args; fails (already exists) for $FAKE_GH_EXISTING
echo "$*" >>"$FAKE_GH_LOG"
[[ "$1 $2" == "label create" ]] || exit 0
[[ "$3" == "${FAKE_GH_EXISTING:-}" ]] && exit 1
exit 0
FAKE
chmod +x "$TMP/bin/gh"
export FAKE_GH_LOG="$TMP/calls.log"
export FAKE_GH_EXISTING="risk:medium"
: >"$FAKE_GH_LOG"

out=$(PATH="$TMP/bin:$PATH" bash "$SCRIPT" --repo owner/name 2>&1)
rc=$?

fails=0
ok() { echo "ok   - $1"; }
bad() { echo "FAIL - $1"; fails=$((fails + 1)); }

[[ $rc -eq 0 ]] && ok "exits 0 despite existing label" || bad "exit code $rc"

for l in ticket blocked risk:low risk:medium risk:high review:second-pass spec; do
  line=$(grep -F "label create $l " "$FAKE_GH_LOG" || true)
  if [[ -n "$line" && "$line" == *"--color "* && "$line" == *"--description "* ]]; then
    ok "requests $l with color+description"
  else
    bad "label $l not requested with --color and --description"
  fi
  if [[ "$line" == *"--repo owner/name"* ]]; then ok "forwards --repo for $l"; else bad "--repo not forwarded for $l"; fi
done

grep -qx "exists: risk:medium" <<<"$out" && ok "existing label prints exists:" || bad "no 'exists: risk:medium'"
grep -qx "created label: risk:high" <<<"$out" && ok "run continues after existing label" || bad "run aborted after existing label"

[[ $fails -eq 0 ]] || { echo "$fails failure(s)"; exit 1; }
echo "all passed"
