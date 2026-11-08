#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: ${0##*/} <out-dir> <base> [<head>]" >&2
  echo "  <head> defaults to HEAD. For HEAD, uncommitted and untracked changes are" >&2
  echo "  snapshotted into review/local-<branch>-wip, leaving the work tree and index" >&2
  echo "  untouched." >&2
  exit 2
}

(($# == 2 || $# == 3)) || usage
out=$1
base=$2
head=${3:-HEAD}

die() { echo "$1" >&2; exit 1; }

base_sha=$(git rev-parse --verify --quiet "$base^{commit}") || die "bad base: $base"
head_sha=$(git rev-parse --verify --quiet "$head^{commit}") || die "bad head: $head"
merge_base=$(git merge-base "$base_sha" "$head_sha") || die "no merge base: $base $head"

name=$(git rev-parse --abbrev-ref "$head" 2>/dev/null || true)
[[ -n $name && $name != HEAD ]] || name=detached-${head_sha:0:7}
slug=${name//[^A-Za-z0-9._-]/-}
ref=review/local-$slug

tip=$head_sha
tip_ref=$ref
if [[ $head == HEAD ]]; then
  index=$(mktemp)
  trap 'rm -f "$index"' EXIT
  cp "$(git rev-parse --git-path index)" "$index"
  GIT_INDEX_FILE=$index git add -A
  tree=$(GIT_INDEX_FILE=$index git write-tree)
  if [[ $tree != "$(git rev-parse "HEAD^{tree}")" ]]; then
    tip=$(git commit-tree --no-gpg-sign -p HEAD -m "Review snapshot" "$tree")
    tip_ref=$ref-wip
  fi
fi

if git diff --quiet "$merge_base" "$tip"; then die "empty diff: $base...$head"; fi

git update-ref "refs/remotes/$ref" "$head_sha"
if [[ $tip != "$head_sha" ]]; then
  git update-ref "refs/remotes/$tip_ref" "$tip"
else
  git update-ref -d "refs/remotes/$ref-wip"
fi

dir="$out/local-$slug"
mkdir -p "$dir"
{
  echo "base $base $base_sha"
  echo "merge-base $merge_base"
  echo "head $name $head_sha $ref"
  if [[ $tip != "$head_sha" ]]; then echo "work-tree $tip $tip_ref"; fi
  git diff --shortstat "$merge_base" "$tip"
} >"$dir/range.txt"
git log --reverse --stat "$merge_base..$head_sha" >"$dir/log.txt"
git diff -M --name-status "$merge_base" "$tip" >"$dir/files.txt"
git diff -M "$merge_base" "$tip" >"$dir/diff.patch"
if [[ $tip != "$head_sha" ]]; then
  git diff -M "$head_sha" "$tip" >"$dir/worktree.patch"
fi

title="uncommitted changes"
if [[ $merge_base != "$head_sha" ]]; then title=$(git log -1 --format=%s "$head_sha"); fi
printf 'local:%s\t%s\t%s\t%s\t%s\n' "$name" "$base" "${tip:0:12}" "$tip_ref" "$title" |
  tee -a "$out/index.tsv"
