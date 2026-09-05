#!/bin/bash
# require-action-node.sh
# Blocks Edit/Write tools if no recent action/goal node exists in deciduous.
# Outputs structured context so Claude can derive a pre-filled suggestion
# and ASK the user before creating nodes.
# Exit code 2 = block the tool and show error to Claude.

# Check if deciduous is initialized
if [ ! -d ".deciduous" ]; then
    exit 0
fi

# Check for any nodes at all
recent_node=$(deciduous nodes 2>/dev/null | grep -E '\[(goal|action)\]' | tail -5)

if [ -z "$recent_node" ]; then
    # No nodes at all - fresh project, allow edits
    exit 0
fi

# Check if any node was created recently (within last 15 min)
now=$(date +%s)
fifteen_min_ago=$((now - 900))

latest_timestamp=$(deciduous nodes 2>/dev/null | tail -1 | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' | tail -1)

if [ -n "$latest_timestamp" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        node_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$latest_timestamp" +%s 2>/dev/null || echo "0")
    else
        node_epoch=$(date -d "$latest_timestamp" +%s 2>/dev/null || echo "0")
    fi

    if [ "$node_epoch" -gt "$fifteen_min_ago" ]; then
        exit 0
    fi
fi

# Gather context for Claude to derive a suggestion
recent_goal=$(deciduous nodes 2>/dev/null | grep '\[goal\]' | tail -1)

cat >&2 << EOF
DECIDUOUS PRE-EDIT: No recent action/goal node found. Ask the user before proceeding.

Most recent goal node: $recent_goal

Derive an action description from the current task context.
Present the user with pre-filled deciduous commands and ask
for confirmation before running. Do NOT skip this step.
Do NOT run the commands without user approval.
Do NOT proceed with the edit until a node is created.
EOF

exit 2
