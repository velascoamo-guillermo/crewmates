#!/usr/bin/env bash
# Offline tests for evidence-publish.sh. Run: ./scripts/gh/test-evidence-publish.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${EVIDENCE_PUBLISH_SCRIPT:-$HERE/evidence-publish.sh}"
run_script() { if [[ -n "${TEST_BASH:-}" ]]; then "$TEST_BASH" "$SCRIPT" "$@"; else "$SCRIPT" "$@"; fi; }
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

fails=0
ok() { echo "ok   - $1"; }
fail() { echo "FAIL - $1${2:+: $2}"; fails=$((fails + 1)); }
eq() { [[ "$2" == "$3" ]] && ok "$1" || fail "$1" "expected [$3] got [$2]"; }

git init -q --bare "$T/remote.git"
git init -q -b main "$T/work"
cd "$T/work" || exit 1
git config user.name t; git config user.email t@t
echo hi >a.txt; git add a.txt; git commit -q -m init
git remote add origin https://github.com/acme/widgets.git
git config "url.$T/remote.git.insteadOf" https://github.com/acme/widgets.git
git push -q origin main

printf 'png' >"$T/shot.png"; printf 'vid' >"$T/clip.mp4"; printf 'txt' >"$T/notes.txt"

# working tree dirt must survive
echo dirty >>a.txt; echo staged >b.txt; git add b.txt; echo untracked >c.txt
hsh() { if command -v md5sum >/dev/null 2>&1; then md5sum; else md5 -q; fi; }
snap() {
  echo "$(git rev-parse HEAD) $(git symbolic-ref HEAD) $(git status --porcelain=v1 | tr '\n' '|')" \
    "$(git diff | hsh) $(git write-tree) $(git diff --cached | hsh)" \
    "$(git ls-files -o --exclude-standard -z | xargs -0 cat | hsh)"
}
before="$(snap)"

out="$(run_script 7 "$T/shot.png" "$T/clip.mp4" "$T/notes.txt" 2>"$T/err")"; rc=$?
eq "first publish exits 0" "$rc" "0"
eq "caller state unchanged" "$(snap)" "$before"
eq "markdown png" "$(sed -n 1p <<<"$out")" '![shot.png](https://github.com/acme/widgets/blob/evidence/pr-7/shot.png?raw=true)'
eq "markdown mp4" "$(sed -n 2p <<<"$out")" '[clip.mp4 (video)](https://github.com/acme/widgets/blob/evidence/pr-7/clip.mp4)'
eq "markdown other" "$(sed -n 3p <<<"$out")" '[notes.txt](https://github.com/acme/widgets/blob/evidence/pr-7/notes.txt)'

git fetch -q origin evidence:refs/remotes/origin/evidence
if git merge-base origin/evidence origin/main >/dev/null 2>&1; then fail "evidence is orphan"; else ok "evidence is orphan"; fi
eq "pr-7 files" "$(git ls-tree -r --name-only origin/evidence | tr '\n' ' ')" "pr-7/clip.mp4 pr-7/notes.txt pr-7/shot.png "
eq "main untouched" "$(git --git-dir="$T/remote.git" rev-parse main)" "$(git rev-parse HEAD)"

run_script 8 "$T/shot.png" >/dev/null 2>&1
git fetch -q origin evidence:refs/remotes/origin/evidence
eq "second PR appends" "$(git ls-tree -r --name-only origin/evidence | tr '\n' ' ')" "pr-7/clip.mp4 pr-7/notes.txt pr-7/shot.png pr-8/shot.png "
eq "history appended" "$(git rev-list --count origin/evidence)" "2"

printf 'new' >"$T/shot.png"
run_script 7 "$T/shot.png" >/dev/null 2>&1
git fetch -q origin evidence:refs/remotes/origin/evidence
eq "republish overwrites" "$(git show origin/evidence:pr-7/shot.png)" "new"
eq "other files kept" "$(git show origin/evidence:pr-7/notes.txt)" "txt"
eq "caller state still unchanged" "$(snap)" "$before"

usage_case() {
  local label="$1"; shift
  local o e rc
  o="$(run_script "$@" 2>"$T/uerr")"; rc=$?
  e="$(cat "$T/uerr")"
  eq "usage: $label exits 2" "$rc" "2"
  eq "usage: $label stdout empty" "$o" ""
  [[ "$e" == *usage:* ]] && ok "usage: $label usage on stderr" || fail "usage: $label usage on stderr" "$e"
}
usage_case "no args"
usage_case "non-numeric PR" abc "$T/shot.png"
usage_case "missing file" 7 "$T/missing.png"
usage_case "no files" 7

# temp dir cleanup (success and failed push)
mkdir "$T/tmpd"
TMPDIR="$T/tmpd" run_script 11 "$T/shot.png" >/dev/null 2>&1
eq "tmp cleaned after success" "$(ls -A "$T/tmpd" | wc -l | tr -d ' ')" "0"
git init -q --bare "$T/rej.git"
printf '#!/bin/sh\nexit 1\n' >"$T/rej.git/hooks/pre-receive"; chmod +x "$T/rej.git/hooks/pre-receive"
git remote add rej https://github.com/acme/rejecting.git
git config "url.$T/rej.git.insteadOf" https://github.com/acme/rejecting.git
TMPDIR="$T/tmpd" run_script --remote rej 11 "$T/shot.png" >/dev/null 2>&1; rc=$?
[[ $rc -ne 0 ]] && ok "rejected push exits non-zero" || fail "rejected push exits non-zero"
eq "tmp cleaned after failed push" "$(ls -A "$T/tmpd" | wc -l | tr -d ' ')" "0"

# filenames with spaces are URL-encoded
cp "$T/shot.png" "$T/Screenshot 2026-11-22 at 10.00.00.png"
sp="$(run_script 12 "$T/Screenshot 2026-11-22 at 10.00.00.png" 2>/dev/null)"
eq "markdown encodes spaces" "$sp" '![Screenshot 2026-11-22 at 10.00.00.png](https://github.com/acme/widgets/blob/evidence/pr-12/Screenshot%202026-11-22%20at%2010.00.00.png?raw=true)'

# non-ASCII and special characters are encoded byte-exact (bash 3.2 and 5)
enc_case() {
  local label="$1" name="$2" want_alt="$3" want_url="$4" o
  cp "$T/shot.png" "$T/$name"
  o="$(run_script 14 "$T/$name" 2>/dev/null)"
  eq "markdown encodes $label" "$o" "![$want_alt](https://github.com/acme/widgets/blob/evidence/pr-14/$want_url?raw=true)"
}
enc_case "accents" 'café.png' 'café.png' 'caf%C3%A9.png'
enc_case "U+202F" $'Screenshot 10.00.00\xe2\x80\xafAM.png' $'Screenshot 10.00.00\xe2\x80\xafAM.png' 'Screenshot%2010.00.00%E2%80%AFAM.png'
enc_case "parens hash percent" 'a(1)#50%.png' 'a(1)#50%.png' 'a%281%29%2350%25.png'
enc_case "brackets" 'a[1].png' 'a\[1\].png' 'a%5B1%5D.png'

# ssh-form remote
git remote add sshr git@github.com:acme/gadgets.git
git config "url.$T/remote.git.insteadOf" git@github.com:acme/gadgets.git 2>/dev/null
git config --add "url.$T/remote.git.insteadOf" https://github.com/acme/widgets.git
sout="$(run_script --remote sshr 9 "$T/shot.png" 2>/dev/null)"
eq "ssh remote slug" "$sout" '![shot.png](https://github.com/acme/gadgets/blob/evidence/pr-9/shot.png?raw=true)'

if command -v ffmpeg >/dev/null 2>&1; then
  ffmpeg -v error -y -f lavfi -i testsrc=duration=1:size=160x120:rate=10 -pix_fmt yuv420p "$T/demo.mp4"
  gout="$(run_script --gif 10 "$T/demo.mp4" 2>/dev/null)"
  git fetch -q origin evidence:refs/remotes/origin/evidence
  size="$(git cat-file -s origin/evidence:pr-10/demo.gif 2>/dev/null || echo 99999999999)"
  [[ "$size" -gt 0 && "$size" -le 10485760 ]] && ok "--gif publishes gif <= 10 MB" || fail "--gif publishes gif" "size $size"
  grep -q 'demo.gif?raw=true' <<<"$gout" && grep -q 'demo.mp4 (video)' <<<"$gout" && ok "--gif markdown has both" || fail "--gif markdown has both" "$gout"
  cp "$T/demo.mp4" "$T/UP.MP4"
  run_script --gif 13 "$T/UP.MP4" >/dev/null 2>&1
  git fetch -q origin evidence:refs/remotes/origin/evidence
  git cat-file -e origin/evidence:pr-13/UP.gif 2>/dev/null && ok "--gif handles .MP4" || fail "--gif handles .MP4"
else
  echo "ok   - skip - ffmpeg not installed"
fi

[[ $fails -eq 0 ]] || { echo "$fails failure(s)"; exit 1; }
echo "all passed"
