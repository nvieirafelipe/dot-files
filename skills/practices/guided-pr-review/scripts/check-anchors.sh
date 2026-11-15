#!/usr/bin/env bash
set -euo pipefail

(($# == 1)) || { echo "usage: ${0##*/} <review.md>" >&2; exit 2; }

python3 -I - "$1" <<'PY'
import re
import sys
import unicodedata

ids, seen, links, fenced = set(), {}, [], False
for number, line in enumerate(open(sys.argv[1], encoding="utf-8"), 1):
    if re.match(r"\s*(```|~~~)", line):
        fenced = not fenced
        continue
    if fenced:
        continue
    heading = re.match(r"(#{2,4})\s+(.*?)\s*$", line)
    if heading:
        text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", heading.group(2)).strip().lower()
        base = "".join(c for c in text if unicodedata.category(c)[0] in "LMN" or c in "_-"
                       or c.isspace())
        base = re.sub(r"\s", "-", base) or "section"
        ids.add(f"{base}-{seen[base] + 1}" if base in seen else base)
        seen[base] = seen[base] + 1 if base in seen else 0
    links += [(number, anchor) for anchor in re.findall(r"\]\(#([^)\s]+)\)", line)]

broken = [(number, anchor) for number, anchor in links if anchor not in ids]
for number, anchor in broken:
    print(f"{sys.argv[1]}:{number}: #{anchor} matches no heading")
sys.exit(1 if broken else 0)
PY
