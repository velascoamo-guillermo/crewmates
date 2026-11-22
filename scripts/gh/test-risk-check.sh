#!/usr/bin/env bash
# Offline tests for risk-check.sh. Run: ./scripts/gh/test-risk-check.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${RISK_CHECK_SCRIPT:-$HERE/risk-check.sh}"
run_script() { if [[ -n "${TEST_BASH:-}" ]]; then "$TEST_BASH" "$SCRIPT" "$@"; else "$SCRIPT" "$@"; fi; }
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

fails=0
ok() { echo "ok   - $1"; }
fail() { echo "FAIL - $1${2:+: $2}"; fails=$((fails + 1)); }
eq() { [[ "$2" == "$3" ]] && ok "$1" || fail "$1" "expected [$3] got [$2]"; }

git init -q -b main "$T/work"
cd "$T/work" || exit 1
git config user.name t; git config user.email t@t
echo hi >README.md; git add README.md; git commit -q -m init

reset_branch() { git checkout -q main; git branch -q -D feat 2>/dev/null; git checkout -q -b feat; }
touch_files() { # paths...
  local p
  for p in "$@"; do mkdir -p "$(dirname "$p")"; echo x >"$p"; git add -- "$p"; done
  git commit -q -m change
}

# no match
reset_branch; touch_files src/app.ts docs/readme.txt
out=$(run_script --base main); rc=$?
eq "no match output" "$out" "no-escalation"; eq "no match exit" "$rc" "0"

# migration
reset_branch; touch_files db/migrations/001_init.ts
out=$(run_script --base main); rc=$?
eq "migration" "$out" $'risk:high\n  db/migrations/001_init.ts  (*migrations/*)'; eq "migration exit" "$rc" "0"

# workflow
reset_branch; touch_files .github/workflows/ci.yml
out=$(run_script --base main)
eq "github workflow" "$out" $'risk:high\n  .github/workflows/ci.yml  (.github/*)'

# terraform
reset_branch; touch_files main.tf
out=$(run_script --base main)
eq "tf file" "$out" $'risk:high\n  main.tf  (*.tf)'

# path with spaces
reset_branch; touch_files "docs/my notes/auth/x y.ts"
out=$(run_script --base main)
eq "spaces" "$out" $'risk:high\n  docs/my notes/auth/x y.ts  (*auth/*)'

# default base resolves (falls back to main, no origin)
out=$(run_script)
eq "default base falls back to main" "$out" $'risk:high\n  docs/my notes/auth/x y.ts  (*auth/*)'

# repo config overrides defaults
reset_branch; touch_files main.tf src/special/thing.ts
mkdir -p .crewmates
printf '# comment\n\nsrc/special/*\n' >.crewmates/risk-high-paths
out=$(run_script --base main)
eq "repo config overrides defaults" "$out" $'risk:high\n  src/special/thing.ts  (src/special/*)'

# --config overrides repo config; comments and blanks ignored
printf '\n# only tf\n\n   \n*.tf\n' >"$T/custom"
out=$(run_script --base main --config "$T/custom")
eq "--config overrides repo config" "$out" $'risk:high\n  main.tf  (*.tf)'
rm -rf .crewmates

# config with only comments matches nothing
printf '# nothing\n\n' >"$T/empty"
out=$(run_script --base main --config "$T/empty")
eq "comment-only config" "$out" "no-escalation"

# default globs: one matching path each, dropping any default must fail
while IFS='|' read -r glob path; do
  reset_branch; touch_files "$path"
  out=$(run_script --base main)
  eq "default glob $glob" "$out" "risk:high"$'\n'"  $path  ($glob)"
done <<'TABLE'
*migrations/*|db/migrations/1.ts
*.sql|db/schema.sql
.github/*|.github/CODEOWNERS
infra/*|infra/a.yaml
k8s/*|k8s/a.yaml
terraform/*|terraform/a.hcl
*.tf|main.tf
*auth/*|src/auth/a.ts
*Auth*|src/LoginAuth.ts
*secrets*|config/secrets.json
*.env*|app/.env.local
fastlane/*|fastlane/Fastfile
*Podfile.lock|ios/Podfile.lock
TABLE

# unusual paths must not be quoted away by git
for p in ".github/workflows/café.yml" "terraform/ñ.hcl" 'fastlane/a"b'; do
  reset_branch; touch_files "$p"
  out=$(run_script --base main)
  [[ "$out" == risk:high$'\n'*"  $p  ("* ]] && ok "unusual path $p" || fail "unusual path $p" "got [$out]"
done

# rename out of a risky dir still flags the source
git checkout -q main; git branch -q -D rbase 2>/dev/null; git checkout -q -b rbase
touch_files .github/workflows/ci.yml
git checkout -q -B feat
mkdir -p old; git mv .github/workflows/ci.yml old/ci.yml; git commit -q -m rename
out=$(run_script --base rbase)
eq "rename hides source" "$out" $'risk:high\n  .github/workflows/ci.yml  (.github/*)'
git checkout -q main

# a comment line that would match as a glob must be skipped
reset_branch; touch_files '#notes.md'
printf '#*\n' >"$T/hash"
out=$(run_script --base main --config "$T/hash")
eq "comment line not treated as glob" "$out" "no-escalation"

# newline / backslash in a matched path must stay on one output line (escaped)
reset_branch; touch_files $'.github/a\nb.yml' '.github/c\d.yml'
out=$(run_script --base main)
eq "newline and backslash escaped" "$out" $'risk:high\n  .github/a\\nb.yml  (.github/*)\n  .github/c\\\\d.yml  (.github/*)'

# submodule pointer bumps under a risky dir (also with ignore=all in .gitmodules)
git init -q -b main "$T/subsrc"; ( cd "$T/subsrc" && git config user.name t && git config user.email t@t && echo 1 >f && git add f && git commit -q -m s1 )
git init -q -b main "$T/swork"; cd "$T/swork" || exit 1
git config user.name t; git config user.email t@t
echo hi >README.md; git add README.md; git commit -q -m init
git -c protocol.file.allow=always submodule add -q "$T/subsrc" infra/sub >/dev/null 2>&1; git commit -q -m addsub
bump() { ( cd infra/sub && git -c user.name=t -c user.email=t@t commit -q --allow-empty -m "$1" ); git add --force infra/sub; git commit -q -m bump; }
git checkout -q -b feat; bump b1
out=$(run_script --base main)
eq "plain submodule bump" "$out" $'risk:high\n  infra/sub  (infra/*)'
git checkout -q main; git branch -q -D feat; git checkout -q -b feat
git config -f .gitmodules submodule.infra/sub.ignore all; git add .gitmodules; git commit -q -m ign
bump b2
out=$(run_script --base main)
eq "submodule bump hidden by ignore=all" "$out" $'risk:high\n  infra/sub  (infra/*)'
cd "$T/work" || exit 1

# bad base
run_script --base nope >/dev/null 2>&1; eq "bad base exit" "$?" "2"
# usage error
run_script --bogus >/dev/null 2>&1; eq "bad flag exit" "$?" "2"
run_script --base main --config "$T/missing" >/dev/null 2>&1; eq "missing config exit" "$?" "2"

[[ $fails -eq 0 ]] || { echo "$fails failure(s)"; exit 1; }
echo "all passed"
