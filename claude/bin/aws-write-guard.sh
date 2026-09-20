#!/usr/bin/env bash
set -uo pipefail

# PreToolUse guard for `aws`. Asks before a call that would change something in
# an AWS account, and stays out of the way of reads.
#
# Matching on the word "production" is what a guard must not do: it fires on
# `grep production lib/config.ex` and on reading a file whose path contains the
# word, which trains you to wave the prompt through. What settles it is the
# operation verb, the same way gh-write-guard.sh settles on the HTTP method.
#
# The AWS CLI names operations consistently, so the read set can be described
# rather than enumerated: describe-*, list-*, get-*, batch-get-*, head-*,
# scan, query, search, lookup-*, filter-*, wait, and `s3 ls`. Anything else is
# treated as a write -- including operations added to the CLI after this was
# written, which is the failure direction you want.
#
# A prod-looking profile does not by itself trigger the ask; a read against
# prod is exactly what an investigation is made of. It only sharpens the
# reason when the operation already writes.

payload=$(cat 2>/dev/null || true)
[[ -n $payload ]] || exit 0

# Cheap gate first, on the raw payload and with no subprocess: this hook runs
# ahead of every Bash call, and almost none of them are aws.
[[ $payload =~ aws[[:space:]] ]] || exit 0

cmd=$(jq -r '.tool_input.command // empty' <<<"$payload" 2>/dev/null) || exit 0
[[ -n $cmd ]] || exit 0

[[ $cmd =~ (^|[|;&[:space:]])aws([[:space:]]|$) ]] || exit 0

# service and operation, skipping the global flags that can precede them.
# Word-split the whole command, newlines included: `aws` is often on the second
# line of a multi-line Bash call, and a here-string would drop it. Globbing off
# so an `s3://bucket/*` argument is not expanded against the filesystem.
set -f
# shellcheck disable=SC2206
words=($cmd)
set +f

# Global flags that take a value; anything else starting with `-` is a boolean
# and must not swallow the next word (`aws --no-cli-pager sts get-caller-identity`).
valued='^--(profile|region|output|endpoint-url|query|color|ca-bundle|cli-read-timeout|cli-connect-timeout|cli-binary-format)$'

service=''
operation=''
for ((i = 0; i < ${#words[@]}; i++)); do
  [[ ${words[i]} == aws ]] || continue
  for ((j = i + 1; j < ${#words[@]}; j++)); do
    w=${words[j]}
    if [[ $w == -* ]]; then
      [[ $w =~ $valued && $w != *=* ]] && ((j++))
      continue
    fi
    if [[ -z $service ]]; then
      service=$w
    else
      operation=$w
      break
    fi
  done
  break
done

[[ -n $service ]] || exit 0

reads='^(describe|list|get|batch-get|head|lookup|filter|search|test|validate|estimate|check)(-|$)|^(scan|query|wait|ls|help)$'

# Operations that write by the naming rule but exist only to serve a read, and
# that an investigation runs constantly. Prompting on these teaches you to wave
# the prompt through, which is the thing this guard is built to avoid.
#   s3api restore-object -- asks Glacier to make an archived object readable.
#     It changes no data and is the first step of every archived-log search.
#   sso login/logout, configure -- local credential state, not account state.
case "$service $operation" in
  's3api restore-object' | 'sso login' | 'sso logout' | 'configure '*)
    exit 0
    ;;
esac

# `aws <service>` with no operation prints help.
[[ -n $operation ]] || exit 0

if [[ $service == s3 ]]; then
  # `aws s3` takes shell-style subcommands rather than API operation names, so
  # the verb alone does not settle it: `cp` is a download or an upload
  # depending on which side the s3:// URI is on. Only the destination decides.
  [[ $operation =~ ^(ls|website|help)$ ]] && exit 0
  if [[ $operation == cp || $operation == sync ]]; then
    # Positionals after the subcommand, ignoring flags and their values.
    src='' dst=''
    for ((k = j + 1; k < ${#words[@]}; k++)); do
      w=${words[k]}
      # A bare `-` is stdout, a positional; only `-x` / `--xyz` are flags.
      [[ $w == -* && $w != - ]] && continue
      if [[ -z $src ]]; then src=$w; else dst=$w; break; fi
    done
    # Downloading out of S3 to a local path reads; everything else writes.
    [[ $src == s3://* && -n $dst && $dst != s3://* ]] && exit 0
  fi
elif [[ $operation =~ $reads ]]; then
  exit 0
fi

profile=''
if [[ $cmd =~ --profile[[:space:]=]+([^[:space:]]+) ]]; then
  profile=${BASH_REMATCH[1]}
elif [[ $cmd =~ AWS_PROFILE=([^[:space:]]+) ]]; then
  profile=${BASH_REMATCH[1]}
fi

reason="This aws call would change state: \`$service $operation\`."
if [[ $profile =~ (prod|production|live) ]]; then
  reason="This aws call would change state in production: \`$service $operation\` on profile \`$profile\`. Approve only if the mutation is intended and authorized."
elif [[ -n $profile ]]; then
  reason="$reason Profile: \`$profile\`. Approve only if you meant to run it."
else
  reason="$reason No --profile given, so it runs against whatever AWS_PROFILE is set to. Confirm the target account first."
fi

jq -n --arg r "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "ask",
    permissionDecisionReason: $r
  }
}'
