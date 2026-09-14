#!/usr/bin/env bash
set -euo pipefail

# Entry point. tmux runs this once, when the configuration is loaded, and it
# does nothing but set the hooks that keep the tab label honest -- everything
# else happens when an agent's own lifecycle hook calls bin/agent-status.
#
# The status label itself is not set here. It is a fragment the status format
# interpolates, so where it appears is the bar's business rather than this
# plugin's; see the @agent_status options in scripts/agent-status.sh and the
# README for the format to paste.

plugin_dir=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)
scripts=$plugin_dir/scripts

# tmux hooks are arrays, and a plain `set-hook -g <name>` writes index 0 --
# which would silently replace whatever the user already had on that hook. An
# index of our own leaves theirs alone, and re-running this file overwrites
# only the plugin's own entry rather than stacking a second copy of it.
slot=${AGENT_STATUS_HOOK_SLOT:-50}

# after-select-window rather than pane-focus-in: the latter is set without
# complaint but never fires on a tmux window switch, even with focus-events on,
# so nothing was ever cleared. after-select-pane covers moving inside a window,
# and the client hooks catch reattaching and session switches.
#
# run-shell -b on every one of them: these run on the path of a keypress, and
# the work behind them is a fork and a handful of tmux calls.
#
# Collected and sent in one invocation. Each tmux call is a process, and this
# file is re-run on every configuration reload.
cmds=()
hook() { cmds+=(set-hook -g "$1[$slot]" "run-shell -b \"$2\"" ';'); }

# Focus drops the acknowledged 'waiting' and 'done' glyphs, and re-derives
# anything that has drifted -- see the reconcile mode in agent-status.sh.
hook after-select-window "$scripts/agent-status.sh clear-transient #{pane_id}"
hook after-select-pane   "$scripts/agent-status.sh clear-transient #{pane_id}"
hook client-attached         "$scripts/agent-status.sh reconcile #{pane_id}"
hook client-session-changed  "$scripts/agent-status.sh reconcile #{pane_id}"

# The trailing separator would have tmux parse an empty command after the last.
unset 'cmds[-1]'
tmux "${cmds[@]}"
