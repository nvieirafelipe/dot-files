#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: ${0##*/} <out-dir> <pr>..." >&2
  echo "  <pr>: 123, owner/repo#123, or https://github.com/owner/repo/pull/123" >&2
  echo "  Run from a local clone to also fetch each head into review/pr-<n>." >&2
  exit 2
}

parse() {
  case $1 in
    https://github.com/*/pull/*)
      local path=${1#https://github.com/}
      repo=${path%%/pull/*}
      number=${path#*/pull/}
      number=${number%%[/?#]*}
      ;;
    */*#*)
      repo=${1%%#*}
      number=${1##*#}
      ;;
    *)
      repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
      number=$1
      ;;
  esac
  [[ $number =~ ^[0-9]+$ ]] || usage
}

local_remote() {
  git rev-parse --git-dir >/dev/null 2>&1 || return 0
  git remote -v | awk -v repo="$1" '
    $3 == "(fetch)" {
      url = tolower($2); sub(/\.git$/, "", url)
      if (url ~ ("[:/]" tolower(repo) "$")) { print $1; exit }
    }'
}

(($# >= 2)) || usage
out=$1
shift
mkdir -p "$out"

fields=number,title,url,body,author,state,isDraft,baseRefName,headRefName,headRefOid
fields+=,commits,reviews,comments,reviewDecision,closingIssuesReferences,statusCheckRollup

for pr in "$@"; do
  parse "$pr"
  dir="$out/${repo//\//-}-$number"
  mkdir -p "$dir"

  gh pr view "$number" -R "$repo" --json "$fields" >"$dir/pr.json"
  gh api --paginate "repos/$repo/pulls/$number/files" --jq '.[]' >"$dir/files.jsonl"
  gh api --paginate "repos/$repo/pulls/$number/comments" --jq '.[]' >"$dir/review-comments.jsonl"
  gh pr checks "$number" -R "$repo" >"$dir/checks.txt" 2>&1 || true

  base=$(jq -r .baseRefName "$dir/pr.json")
  head=$(jq -r .headRefOid "$dir/pr.json")
  ref=-
  remote=$(local_remote "$repo")
  if [[ -n $remote ]]; then
    ref=review/pr-$number
    git fetch --quiet "$remote" "+refs/pull/$number/head:refs/remotes/$ref"
    git fetch --quiet "$remote" "+refs/heads/$base:refs/remotes/$remote/$base" ||
      echo "$repo#$number: base branch $base not fetched" >&2
  fi

  if ! gh pr diff "$number" -R "$repo" >"$dir/pr.diff" 2>/dev/null; then
    [[ $ref != - ]] || { echo "$repo#$number: gh pr diff failed and no local clone" >&2; exit 1; }
    git diff "$remote/$base...$ref" >"$dir/pr.diff"
  fi

  printf '%s#%s\t%s\t%s\t%s\t%s\n' "$repo" "$number" "$base" "${head:0:12}" "$ref" \
    "$(jq -r .title "$dir/pr.json")" | tee -a "$out/index.tsv"
done
