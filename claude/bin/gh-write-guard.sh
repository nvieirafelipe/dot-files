#!/usr/bin/env bash
set -uo pipefail

# PreToolUse guard for `gh api`. Asks before a call that would write to GitHub
# in your name, and stays out of the way of reads.
#
# `gh api` is one command for both directions, so the name cannot decide it and
# the URL must not: repos/o/r/issues/1/comments is a GET that lists comments,
# and asking about it trains you to wave the prompt through. What settles it is
# the method:
#
#   -X / --method POST|PATCH|PUT|DELETE   asked for outright
#   -f -F --field --raw-field --input     gh sends POST when a body is given
#   graphql with a mutation               a write with no method flag in sight
#
# Everything else -- including --paginate over a comments endpoint -- is a read.
# Reads on other `gh` subcommands need nothing here; the write ones are named in
# the ask list in settings.json.

payload=$(cat 2>/dev/null || true)
[[ -n $payload ]] || exit 0

# Cheap gate first, on the raw payload and with no subprocess: this hook runs
# ahead of every Bash call, and almost none of them are gh. Only worth starting
# jq once the bytes could plausibly be a gh api call.
[[ $payload =~ gh[[:space:]]+api ]] || exit 0

cmd=$(jq -r '.tool_input.command // empty' <<<"$payload" 2>/dev/null) || exit 0
[[ -n $cmd ]] || exit 0

# Not a gh api call at all: nothing to say.
[[ $cmd =~ (^|[|;&[:space:]])gh[[:space:]]+api([[:space:]]|$) ]] || exit 0

writes=0
reason=''
if [[ $cmd =~ (^|[[:space:]])graphql([[:space:]]|$) ]]; then
  # GraphQL is always a POST carrying a body, so the body rule below would ask
  # about every query. Only a mutation writes anything.
  if [[ $cmd == *mutation* ]]; then
    writes=1
    reason='a GraphQL mutation'
  fi
elif [[ $cmd =~ (-X|--method)[[:space:]]+(POST|PATCH|PUT|DELETE) ]]; then
  writes=1
  reason="an explicit ${BASH_REMATCH[2]}"
elif [[ $cmd =~ (^|[[:space:]])(-f|-F|--field|--raw-field|--input)([[:space:]]|=) ]]; then
  writes=1
  reason='a request body, which gh sends as POST'
fi

((writes)) || exit 0

jq -n --arg r "This gh api call would write to GitHub as you -- $reason. Approve only if you meant to post it." '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "ask",
    permissionDecisionReason: $r
  }
}'
