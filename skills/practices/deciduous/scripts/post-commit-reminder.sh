#!/bin/bash
# post-commit-reminder.sh
# Runs after git commit to prompt Claude to link the commit to deciduous.
# Outputs structured context so Claude can derive a pre-filled suggestion
# and ASK the user before creating nodes.
# Exit code 2 ensures Claude sees and acts on this message.

# Check if deciduous is initialized
if [ ! -d ".deciduous" ]; then
    exit 0
fi

# Read the input JSON to check if this was a git commit
input=$(cat)
command=$(echo "$input" | grep -o '"command":"[^"]*"' | head -1 | sed 's/"command":"//;s/"$//')

# Only trigger on git commit commands
if ! echo "$command" | grep -qE '^git commit'; then
    exit 0
fi

# Gather context for Claude to derive a suggestion
commit_hash=$(git rev-parse --short HEAD 2>/dev/null)
commit_msg=$(git log -1 --format=%s 2>/dev/null)
recent_action=$(deciduous nodes 2>/dev/null | grep '\[action\]' | tail -1)

cat >&2 << EOF
DECIDUOUS POST-COMMIT: Ask the user to link this commit to the decision graph.

Commit: $commit_hash "$commit_msg"
Most recent action node: $recent_action

Derive an outcome description from the commit message above.
Present the user with pre-filled deciduous commands and ask
for confirmation before running. Do NOT skip this step.
Do NOT run the commands without user approval.
EOF

exit 2
