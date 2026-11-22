#!/usr/bin/env bash
# Offline tests for evidence-publish.sh. Run: ./scripts/gh/test-evidence-publish.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${EVIDENCE_PUBLISH_SCRIPT:-$HERE/evidence-publish.sh}"
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
snap() { echo "$(git rev-parse HEAD) $(git symbolic-ref HEAD) $(git status --porcelain=v1 | tr '\n' '|') $(git diff | md5 -q 2>/dev/null || git diff | md5sum)"; }
before="$(snap)"

out="$("$SCRIPT" 7 "$T/shot.png" "$T/clip.mp4" "$T/notes.txt" 2>"$T/err")"; rc=$?
eq "first publish exits 0" "$rc" "0"
eq "caller state unchanged" "$(snap)" "$before"
eq "markdown png" "$(sed -n 1p <<<"$out")" '![shot.png](https://github.com/acme/widgets/blob/evidence/pr-7/shot.png?raw=true)'
eq "markdown mp4" "$(sed -n 2p <<<"$out")" '[clip.mp4 (video)](https://github.com/acme/widgets/blob/evidence/pr-7/clip.mp4)'
eq "markdown other" "$(sed -n 3p <<<"$out")" '[notes.txt](https://github.com/acme/widgets/blob/evidence/pr-7/notes.txt)'

git fetch -q origin evidence:refs/remotes/origin/evidence
if git merge-base origin/evidence origin/main >/dev/null 2>&1; then fail "evidence is orphan"; else ok "evidence is orphan"; fi
eq "pr-7 files" "$(git ls-tree -r --name-only origin/evidence | tr '\n' ' ')" "pr-7/clip.mp4 pr-7/notes.txt pr-7/shot.png "
eq "main untouched" "$(git --git-dir="$T/remote.git" rev-parse main)" "$(git rev-parse HEAD)"

"$SCRIPT" 8 "$T/shot.png" >/dev/null 2>&1
git fetch -q origin evidence:refs/remotes/origin/evidence
eq "second PR appends" "$(git ls-tree -r --name-only origin/evidence | tr '\n' ' ')" "pr-7/clip.mp4 pr-7/notes.txt pr-7/shot.png pr-8/shot.png "
eq "history appended" "$(git rev-list --count origin/evidence)" "2"

printf 'new' >"$T/shot.png"
"$SCRIPT" 7 "$T/shot.png" >/dev/null 2>&1
git fetch -q origin evidence:refs/remotes/origin/evidence
eq "republish overwrites" "$(git show origin/evidence:pr-7/shot.png)" "new"
eq "other files kept" "$(git show origin/evidence:pr-7/notes.txt)" "txt"
eq "caller state still unchanged" "$(snap)" "$before"

"$SCRIPT" >/dev/null 2>&1; eq "usage: no args exits 2" "$?" "2"
"$SCRIPT" abc "$T/shot.png" >/dev/null 2>&1; eq "usage: non-numeric PR exits 2" "$?" "2"
"$SCRIPT" 7 "$T/missing.png" >/dev/null 2>&1; eq "usage: missing file exits 2" "$?" "2"
"$SCRIPT" 7 >/dev/null 2>&1; eq "usage: no files exits 2" "$?" "2"

# ssh-form remote
git remote add sshr git@github.com:acme/gadgets.git
git config "url.$T/remote.git.insteadOf" git@github.com:acme/gadgets.git 2>/dev/null
git config --add "url.$T/remote.git.insteadOf" https://github.com/acme/widgets.git
sout="$("$SCRIPT" --remote sshr 9 "$T/shot.png" 2>/dev/null)"
eq "ssh remote slug" "$sout" '![shot.png](https://github.com/acme/gadgets/blob/evidence/pr-9/shot.png?raw=true)'

if command -v ffmpeg >/dev/null 2>&1; then
  ffmpeg -v error -y -f lavfi -i testsrc=duration=1:size=160x120:rate=10 -pix_fmt yuv420p "$T/demo.mp4"
  gout="$("$SCRIPT" --gif 10 "$T/demo.mp4" 2>/dev/null)"
  git fetch -q origin evidence:refs/remotes/origin/evidence
  size="$(git cat-file -s origin/evidence:pr-10/demo.gif 2>/dev/null || echo 99999999999)"
  [[ "$size" -gt 0 && "$size" -le 10485760 ]] && ok "--gif publishes gif <= 10 MB" || fail "--gif publishes gif" "size $size"
  grep -q 'demo.gif?raw=true' <<<"$gout" && grep -q 'demo.mp4 (video)' <<<"$gout" && ok "--gif markdown has both" || fail "--gif markdown has both" "$gout"
else
  echo "ok   - skip - ffmpeg not installed"
fi

[[ $fails -eq 0 ]] || { echo "$fails failure(s)"; exit 1; }
echo "all passed"
