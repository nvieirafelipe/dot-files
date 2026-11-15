#!/usr/bin/env bash
set -eu
src="$(cd "$(dirname "$0")" && pwd)/files"
author=(-c user.name=Dana -c user.email=dana@example.com -c commit.gpgsign=false)
cp -R "$src/base/." .
git init -q -b main
git add -A
git "${author[@]}" commit -q -m "Deliver webhook events"
git checkout -q -b retry-deliveries
cp -R "$src/branch/." .
git add -A
git "${author[@]}" commit -q -F "$src/commit-message.txt"
if [ -d "$src/notes" ]; then
  cp -R "$src/notes" notes
fi
