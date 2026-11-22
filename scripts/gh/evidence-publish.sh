#!/usr/bin/env bash
# Publish PR evidence files to an orphan `evidence` branch under pr-<N>/ and
# print ready-to-paste markdown. Never touches the caller's worktree/index/branch.
# Usage: evidence-publish.sh [--remote <name>] [--gif] <pr-number> <file>...
set -euo pipefail

usage() {
  echo "usage: evidence-publish.sh [--remote <name>] [--gif] <pr-number> <file>..." >&2
  exit 2
}

remote=origin
gif=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote) [[ $# -ge 2 ]] || usage; remote="$2"; shift 2 ;;
    --gif) gif=1; shift ;;
    -h | --help) usage ;;
    --) shift; break ;;
    -*) echo "unknown option: $1" >&2; usage ;;
    *) break ;;
  esac
done
[[ $# -ge 2 ]] || usage
pr="$1"; shift
[[ "$pr" =~ ^[0-9]+$ ]] || { echo "PR number must be numeric: $pr" >&2; usage; }
for f in "$@"; do
  [[ -f "$f" ]] || { echo "file not found: $f" >&2; usage; }
done

tmp="$(mktemp -d "${TMPDIR:-/tmp}/evidence-publish.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

# owner/repo from the configured (un-rewritten) remote URL; https and ssh forms
raw="$(git config --get "remote.$remote.url")" || { echo "no such remote: $remote" >&2; exit 1; }
slug="$(sed -E 's#^(https?://([^/@]+@)?|ssh://([^/@]+@)?|[^/@]+@)[^/:]+[:/]##; s#\.git/?$##; s#/$##' <<<"$raw")"
[[ "$slug" =~ ^[^/]+/[^/]+$ ]] || { echo "cannot derive owner/repo from $raw" >&2; exit 1; }

files=("$@")
if [[ $gif -eq 1 ]]; then
  command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg is required for --gif but is not installed" >&2; exit 1; }
  mkdir -p "$tmp/gif"
  for f in "$@"; do
    [[ "$(tr '[:upper:]' '[:lower:]' <<<"${f##*.}")" == "mp4" ]] || continue
    base="$(basename "${f%.*}")"
    out="$tmp/gif/$base.gif"
    for cfg in "12 480" "8 400" "6 320" "5 240"; do
      read -r fps width <<<"$cfg"
      ffmpeg -v error -y -i "$f" \
        -vf "fps=$fps,scale=$width:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse" \
        "$out" >&2
      size="$(wc -c <"$out")"
      [[ "$size" -le 10485760 ]] && break
    done
    [[ "$size" -le 10485760 ]] || { echo "could not shrink $base.gif under 10 MB" >&2; exit 1; }
    files+=("$out")
  done
fi

fetch_url="$(git remote get-url "$remote")"
push_url="$(git remote get-url --push "$remote")"

repo="$tmp/repo"
git init -q "$repo"
g() { git -C "$repo" -c user.name="evidence-publish" -c user.email="evidence-publish@users.noreply.github.com" -c commit.gpgsign=false "$@"; }

if git ls-remote --exit-code --heads "$fetch_url" evidence >/dev/null 2>&1; then
  g fetch -q "$fetch_url" evidence
  g checkout -q -B evidence FETCH_HEAD
else
  g checkout -q --orphan evidence
fi

mkdir -p "$repo/pr-$pr"
for f in "${files[@]}"; do cp "$f" "$repo/pr-$pr/$(basename "$f")"; done
g add -A "pr-$pr"
if g diff --cached --quiet 2>/dev/null && g rev-parse -q --verify HEAD >/dev/null; then
  echo "evidence unchanged; nothing to push" >&2
else
  g commit -q -m "chore: evidence for PR #$pr"
  g push -q "$push_url" refs/heads/evidence:refs/heads/evidence >&2
fi

urlencode() {
  local LC_ALL=C s="$1" i c out=""
  for ((i = 0; i < ${#s}; i++)); do
    c="${s:i:1}"
    case "$c" in
      [a-zA-Z0-9._~-]) out+="$c" ;;
      *) out+="$(printf '%%%02X' "'$c")" ;;
    esac
  done
  printf '%s' "$out"
}

for f in "${files[@]}"; do
  name="$(basename "$f")"
  url="https://github.com/$slug/blob/evidence/pr-$pr/$(urlencode "$name")"
  ext="$(tr '[:upper:]' '[:lower:]' <<<"${name##*.}")"
  case "$ext" in
    png | jpg | jpeg | gif | webp) echo "![$name]($url?raw=true)" ;;
    mp4) echo "[$name (video)]($url)" ;;
    *) echo "[$name]($url)" ;;
  esac
done
