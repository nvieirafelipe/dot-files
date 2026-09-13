#!/usr/bin/env bash
set -euo pipefail

# Animates the 'working' glyph in the tmux window (tab) name.
#
# tmux only re-runs #() jobs once per status-interval, so a spinner cannot be
# polled into existence at a useful rate. Instead this pushes: it rewrites the
# frame on every working window and calls 'refresh-client -S', which re-expands
# the status format without re-running the cached #() jobs. status-interval and
# the cost of repo-icon.sh are therefore unaffected.
#
# One instance per tmux server. It exits by itself once no window is working, so
# agent-status.sh can call '--ensure-running' unconditionally.
#
# The frames are the dense braille set, not the common sparse one (⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏).
# Braille occupies a 2x4 dot grid spanning the whole cell, so a frame that only
# lights the top dots renders high above the text baseline. Measured against 'M'
# in SauceCodePro at 64pt: sparse frames centre on y=29 vs the text's y=50, while
# these centre on y=49. Every frame here also shares one bounding box, so the
# glyph does not jitter horizontally as it turns.

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
interval=${AGENT_SPINNER_INTERVAL:-0.3}
frames=(⣾ ⣽ ⣻ ⢿ ⡿ ⣟ ⣯ ⣷)
frame_count=${#frames[@]}

[[ -n ${TMUX:-} ]] || exit 0

# Matched in bash rather than piped through grep: one less process on a path
# that runs several times a second.
agent_present() {
  local cmd
  for cmd in $1; do
    case $cmd in
      claude | codex) return 0 ;;
      *.*.*) [[ $cmd =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && return 0 ;;
    esac
  done
  return 1
}

if [[ ${1:-} == --ensure-running ]]; then
  pid=$(tmux show-option -gqv @agent_spinner_pid)
  # kill -0 only probes; it sends no signal
  if [[ -n $pid ]] && kill -0 "$pid" 2>/dev/null; then
    exit 0
  fi
  "$0" </dev/null >/dev/null 2>&1 &
  tmux set-option -g @agent_spinner_pid "$!"
  exit 0
fi

cleanup() {
  tmux set-option -gu @agent_spinner_pid 2>/dev/null || true
}
trap cleanup EXIT

i=0
while :; do
  # Every field the tick needs, for every window, in one call -- including the
  # pane commands, since #{P:} iterates a window's panes inside the format.
  # This was ten separate tmux invocations per working window, and any keypress
  # arriving mid-tick had to wait behind all of them: it cost the review
  # window's ]/[ navigation about 100ms per press.
  mapfile -t rows < <(
    tmux list-windows -a -F \
      '#{window_id}|#{@agent_state}|#{@agent_state_colour}|#{@agent_glyph}|#{@agent_glyph_colour}|#{P:#{pane_current_command} }' \
      2>/dev/null
  )
  # No rows at all means the server is gone, so no loop outlives its tmux.
  ((${#rows[@]})) || exit 0

  frame=${frames[$((i % frame_count))]}
  working=0
  batch=()
  for row in "${rows[@]}"; do
    IFS='|' read -r window state colour glyph glyph_colour commands <<<"$row"
    [[ $state == working ]] || continue
    working=1
    [[ -n $colour ]] || continue

    # A harness killed mid-turn never fires Stop, so 'working' would spin here
    # forever. Re-derive from the pane instead of trusting the event stream.
    if ! agent_present "$commands"; then
      "$script_dir/agent-status.sh" reconcile "$window"
      continue
    fi

    # Keep the agent marker and its own colour; only the frame animates. Two
    # spaces, and a trailing space, matching agent-status.sh -- see the notes
    # there.
    label="#[fg=${glyph_colour:-$colour}]$glyph#[fg=$colour]  $frame "
    ((${#batch[@]})) && batch+=(';')
    batch+=(
      set-option -w -t "$window" @agent_status "$label" ';'
      set-option -w -t "$window" @agent_status_active "$label"
    )
  done
  ((working)) || exit 0

  # The writes and the redraw they exist for go out together: the refresh has to
  # come after every label is set, and a separate client call costs more than
  # the work it carries.
  if ((${#batch[@]})); then
    tmux "${batch[@]}" ';' refresh-client -S 2>/dev/null || true
  fi
  i=$((i + 1))
  sleep "$interval"
done
