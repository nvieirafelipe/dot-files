#!/usr/bin/env bash
set -euo pipefail

(($# >= 1)) || { echo "usage: ${0##*/} <review.md> [review.html]" >&2; exit 2; }
src=$1
dst=${2:-${src%.md}.html}
template="$(dirname "${BASH_SOURCE[0]}")/../assets/report-viewer.html"

html=$(<"$template")
b64=$(base64 <"$src" | tr -d '\n')
printf '%s\n' "${html/@@REPORT_BASE64@@/$b64}" >"$dst"
echo "$dst"
