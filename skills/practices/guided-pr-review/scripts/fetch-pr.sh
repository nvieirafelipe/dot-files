#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: ${0##*/} <out-dir> <pr>..." >&2
  echo "  <pr>: 123, owner/repo#123, https://github.com/owner/repo/pull/123, or a" >&2
  echo "        Forgejo or Gitea PR such as https://codeberg.org/owner/repo/pulls/123" >&2
  echo "  Run from a local clone to also fetch each head into review/pr-<n>." >&2
  exit 2
}

parse() {
  forge=github host=
  case $1 in
    https://github.com/*/pull/*)
      local path=${1#https://github.com/}
      repo=${path%%/pull/*}
      number=${path#*/pull/}
      ;;
    https://*/*/*/pulls/*)
      forge=forgejo
      local path=${1#https://}
      host=${path%%/*}
      path=${path#*/}
      repo=${path%%/pulls/*}
      number=${path#*/pulls/}
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
  number=${number%%[/?#]*}
  [[ $number =~ ^[0-9]+$ ]] || usage
}

local_remote() {
  git rev-parse --git-dir >/dev/null 2>&1 || return 0
  git remote -v | awk -v repo="$1" -v host="$2" '
    $3 == "(fetch)" {
      url = tolower($2); sub(/\.git$/, "", url)
      if (url ~ ("[:/]" tolower(repo) "$") && (host == "" || index(url, tolower(host)))) {
        print $1; exit
      }
    }'
}

fetch_github() {
  local fields=number,title,url,body,author,state,isDraft,baseRefName,headRefName,headRefOid
  fields+=,commits,reviews,comments,reviewDecision,closingIssuesReferences,statusCheckRollup

  gh pr view "$number" -R "$repo" --json "$fields" >"$dir/pr.json"
  gh api --paginate "repos/$repo/pulls/$number/files" --jq '.[]' >"$dir/files.jsonl"
  gh api --paginate "repos/$repo/pulls/$number/comments" --jq '.[]' >"$dir/review-comments.jsonl"
  gh pr checks "$number" -R "$repo" >"$dir/checks.txt" 2>&1 || true

  jq -r '.closingIssuesReferences[] | "\(.repository.owner.login)/\(.repository.name) \(.number)"' \
    "$dir/pr.json" | while read -r issue_repo issue_number; do
    mkdir -p "$dir/issues"
    gh issue view "$issue_number" -R "$issue_repo" \
      --json number,title,url,body,author,state,comments </dev/null \
      >"$dir/issues/${issue_repo//\//-}-$issue_number.json" ||
      echo "$repo#$number: issue $issue_repo#$issue_number not fetched" >&2
  done

  base=$(jq -r .baseRefName "$dir/pr.json")
  head=$(jq -r .headRefOid "$dir/pr.json")
}

# tea api exits 0 on an HTTP error, so read the status line that -i writes to stderr.
forgejo() {
  local headers status
  headers=$(mktemp)
  tea api -l "$login" -i "$1" </dev/null 2>"$headers" || true
  status=$(head -1 "$headers")
  rm -f "$headers"
  [[ $status == HTTP/*" 2"* ]] || { echo "$host/$1: ${status:-no response}" >&2; return 1; }
}

# tea api has no --paginate. Only for endpoints that take page and limit; the guard stops
# an endpoint that ignores them from looping forever.
forgejo_all() {
  local page=1 separator='?' body previous=
  [[ $1 == *\?* ]] && separator='&'
  while :; do
    body=$(forgejo "$1${separator}limit=50&page=$page") || return 1
    [[ $(jq length <<<"$body") -gt 0 && $body != "$previous" ]] || return 0
    jq -c '.[]' <<<"$body"
    previous=$body
    page=$((page + 1))
  done
}

closing_refs() {
  { jq -r '.body // ""' "$dir/pr.json"; jq -r '.commit.message' "$dir/commits.jsonl"; } |
    jq -Rr --arg repo "$repo" '
      scan("(?i)\\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?):?\\s+([\\w.-]+/[\\w.-]+)?#([0-9]+)")
      | "\(.[0] // $repo) \(.[1])"' | sort -u
}

fetch_forgejo() {
  local api=repos/$repo/pulls/$number issue comments
  login=$(tea logins list -o json | jq -r --arg url "https://$host" \
    '[.[] | select((.url | rtrimstr("/")) == $url)][0].name // empty')
  [[ -n $login ]] || { echo "$host: no tea login; run tea login add" >&2; exit 1; }

  forgejo "$api" >"$dir/pr.json"
  forgejo_all "$api/commits?verification=false&files=false" >"$dir/commits.jsonl"
  forgejo_all "$api/files" >"$dir/files.jsonl"
  forgejo "repos/$repo/issues/$number/comments" | jq -c '.[]' >"$dir/comments.jsonl"
  forgejo_all "$api/reviews" >"$dir/reviews.jsonl"
  jq -r 'select(.comments_count > 0) | .id' "$dir/reviews.jsonl" | while read -r id; do
    forgejo "$api/reviews/$id/comments" | jq -c '.[]'
  done >"$dir/review-comments.jsonl"
  forgejo "repos/$repo/commits/$(jq -r .head.sha "$dir/pr.json")/status" |
    jq -r '"state\t\(.state)", (.statuses[] | [.status, .context, .target_url] | @tsv)' \
      >"$dir/checks.txt" || true

  closing_refs | while read -r issue_repo issue_number; do
    mkdir -p "$dir/issues"
    if issue=$(forgejo "repos/$issue_repo/issues/$issue_number") &&
      comments=$(forgejo "repos/$issue_repo/issues/$issue_number/comments" | jq -c '.[]'); then
      jq -s '.[0] + {comments: .[1:]}' <<<"$issue"$'\n'"$comments" \
        >"$dir/issues/${issue_repo//\//-}-$issue_number.json"
    else
      echo "$repo#$number: issue $issue_repo#$issue_number not fetched" >&2
    fi
  done

  base=$(jq -r .base.ref "$dir/pr.json")
  head=$(jq -r .head.sha "$dir/pr.json")
}

fetch_diff() {
  case $forge in
    github) gh pr diff "$number" -R "$repo" 2>/dev/null ;;
    forgejo) forgejo "repos/$repo/pulls/$number.diff" 2>/dev/null ;;
  esac
}

(($# >= 2)) || usage
out=$1
shift
mkdir -p "$out"

for pr in "$@"; do
  parse "$pr"
  dir="$out/${repo//\//-}-$number"
  mkdir -p "$dir"

  "fetch_$forge"

  ref=-
  remote=$(local_remote "$repo" "$host")
  if [[ -n $remote ]]; then
    ref=review/pr-$number
    git fetch --quiet "$remote" "+refs/pull/$number/head:refs/remotes/$ref"
    git fetch --quiet "$remote" "+refs/heads/$base:refs/remotes/$remote/$base" ||
      echo "$repo#$number: base branch $base not fetched" >&2
  fi

  if ! fetch_diff >"$dir/pr.diff"; then
    [[ $ref != - ]] || { echo "$repo#$number: diff not fetched and no local clone" >&2; exit 1; }
    git diff "$remote/$base...$ref" >"$dir/pr.diff"
  fi

  printf '%s#%s\t%s\t%s\t%s\t%s\n' "$repo" "$number" "$base" "${head:0:12}" "$ref" \
    "$(jq -r .title "$dir/pr.json")" | tee -a "$out/index.tsv"
done
