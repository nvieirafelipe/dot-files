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
pending_action_outcome_count=$(deciduous nodes 2>/dev/null | awk '$3=="pending" && ($2=="action"||$2=="outcome")' | wc -l | tr -d ' ')

# Event log size for checkpoint suggestion
event_dir=".deciduous/sync/events"
event_bytes=0
if [ -d "$event_dir" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        event_bytes=$(find "$event_dir" -type f -name '*.jsonl' -exec stat -f%z {} + 2>/dev/null | awk '{s+=$1} END {print s+0}')
    else
        event_bytes=$(find "$event_dir" -type f -name '*.jsonl' -exec stat -c%s {} + 2>/dev/null | awk '{s+=$1} END {print s+0}')
    fi
fi

checkpoint_hint=""
if [ "$event_bytes" -gt 262144 ]; then
    checkpoint_hint=$'\n\nEvent log is '"$event_bytes"$' bytes (>256KB). Suggest:\n  deciduous events checkpoint --clear-events'
fi

sweep_hint=""
if [ "$pending_action_outcome_count" -gt 10 ]; then
    sweep_hint=$'\n\n'"$pending_action_outcome_count"$' pending action/outcome nodes accumulating. Suggest a status sweep:\n  deciduous nodes | awk '\''$3=="pending" && ($2=="action"||$2=="outcome")'\''\n  # then: deciduous status <id> completed (or rejected)'
fi

cat >&2 << EOF
DECIDUOUS POST-COMMIT: Ask the user to link this commit to the decision graph.

Commit: $commit_hash "$commit_msg"
Most recent action node: $recent_action
Pending action/outcome nodes: $pending_action_outcome_count

Derive an outcome description from the commit message above.
Present the user with pre-filled deciduous commands and ask
for confirmation before running. Do NOT skip this step.
Do NOT run the commands without user approval.

When linking the commit, ALSO consider:
  - Flip the parent action node to completed: deciduous status <id> completed
  - Use --commit HEAD on the new outcome node
  - Link outcome -> action with deciduous link <outcome> <action> -r "..."$sweep_hint$checkpoint_hint
EOF

exit 2
