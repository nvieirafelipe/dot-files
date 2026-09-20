#!/usr/bin/env bash
set -uo pipefail

# PreToolUse guard for Edit/Write. Keeps story work out of the shared checkout.
#
# Scoped deliberately narrowly: it only speaks up when THIS session is
# registered in .claude/.shortcut-workflow or .claude/.codeberg-workflow, which
# the workflow skills write at setup. Outside an active story it is silent, so
# editing dot-files, a hotfix, or any repo without a workflow underway is
# untouched. A guard that fires on ordinary edits gets approved reflexively and
# then protects nothing.
#
# Usage in settings.json, so that $PPID is the Claude process:
#   "command": "~/.claude/bin/worktree-edit-guard.sh \"$PPID\""

claude_pid=${1:-$PPID}

payload=$(cat 2>/dev/null || true)
[[ -n $payload ]] || exit 0

path=$(jq -r '.tool_input.file_path // empty' <<<"$payload" 2>/dev/null) || exit 0
[[ -n $path ]] || exit 0

# The file may not exist yet on a Write, so ask git about the nearest existing
# ancestor directory instead.
dir=$(dirname -- "$path")
while [[ ! -d $dir && $dir != / && $dir != . ]]; do
  dir=$(dirname -- "$dir")
done
[[ -d $dir ]] || exit 0

toplevel=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || exit 0
[[ -n $toplevel ]] || exit 0

# --git-common-dir resolves to the MAIN repo's .git from inside a worktree too,
# which is what makes this comparison work at all.
common=$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null) || exit 0
main_root=$(cd "$dir" && cd "$common/.." && pwd) || exit 0

# Already in a worktree: nothing to say.
[[ $toplevel == "$main_root" ]] || exit 0

story=''
for f in "$main_root/.claude/.shortcut-workflow" "$main_root/.claude/.codeberg-workflow"; do
  [[ -f $f ]] || continue
  story=$(awk -v pid="$claude_pid" '$1 == pid {print $2; exit}' "$f")
  [[ -n $story ]] && break
done

# No story registered for this session: not story work, not this guard's business.
[[ -n $story ]] || exit 0

# The workflow keeps plan.md, worklog.md and review.md in the main repo on
# purpose, so the worktree can be thrown away without losing them.
rel=${path#"$main_root"/}
case $rel in
  .snippets/* | .claude/* | .git/*) exit 0 ;;
esac

jq -n --arg r "Story $story is registered for this session, and this edit targets the shared checkout at $main_root rather than its worktree. Move to the worktree first (git worktree list), or the change lands on the wrong branch and dirties the checkout every other session shares. Files under .snippets/ and .claude/ are exempt." '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $r
  }
}'
