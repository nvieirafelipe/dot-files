#!/usr/bin/env bash
set -euo pipefail

# Animates the 'working' glyph in the tmux window (tab) name.
#
# tmux only re-runs #() jobs once per status-interval, so a spinner cannot be
# polled into existence at a useful rate. Instead this pushes: it rewrites the
# frame on every working window and calls 'refresh-client -S', which re-expands
# the status format without re-running the cached #() jobs. status-interval and
# the cost of a #() segment are therefore unaffected.
#
# One instance per tmux server. It exits by itself once no window is working, so
# agent-status.sh can call '--ensure-running' unconditionally.
#
# The frames themselves, and why they are the dense braille set, are in
# variables.sh.

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck source-path=SCRIPTDIR source=variables.sh
source "$script_dir/variables.sh"

interval=${AGENT_SPINNER_INTERVAL:-$spinner_interval}
frames=("${spinner_frames[@]}")
frame_count=${#frames[@]}

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

# The label for one frame. Keeps the agent marker and its own colour; only the
# frame animates. Two spaces, and a trailing space, matching render_label in
# agent-status.sh -- see the notes there.
# The spinner turns in the agent's own colour, not the state's. With both
# harnesses drawing the same robot the colour is the only thing that says which
# one is running, so it has to hold for the whole label -- and the state needs
# no colour of its own here, because a frame that is moving is what 'working'
# means. Only when the marker has no colour does the state's stand in.
frame_label() {
  local glyph=$1 glyph_colour=$2 colour=$3 frame=$4
  printf '#[fg=%s]%s#[fg=%s]  %s ' \
    "${glyph_colour:-$colour}" "$glyph" "${glyph_colour:-$colour}" "$frame"
}

# Starts the loop unless one is already running. kill -0 only probes; it sends
# no signal.
ensure_running() {
  local pid
  pid=$(tmux show-option -gqv @agent_spinner_pid)
  if [[ -n $pid ]] && kill -0 "$pid" 2>/dev/null; then
    return 0
  fi
  "$0" </dev/null >/dev/null 2>&1 &
  tmux set-option -g @agent_spinner_pid "$!"
}

cleanup() {
  tmux set-option -gu @agent_spinner_pid 2>/dev/null || true
}

spin() {
  trap cleanup EXIT

  local i=0 frame row window state colour glyph glyph_colour commands label
  local -a rows batch
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
    ((${#rows[@]})) || return 0

    frame=${frames[$((i % frame_count))]}
    local working=0
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

      label=$(frame_label "$glyph" "$glyph_colour" "$colour" "$frame")
      ((${#batch[@]})) && batch+=(';')
      batch+=(
        set-option -w -t "$window" @agent_status "$label" ';'
        set-option -w -t "$window" @agent_status_active "$label"
      )
    done
    ((working)) || return 0

    # The writes and the redraw they exist for go out together: the refresh has
    # to come after every label is set, and a separate client call costs more
    # than the work it carries.
    if ((${#batch[@]})); then
      tmux "${batch[@]}" ';' refresh-client -S 2>/dev/null || true
    fi
    i=$((i + 1))
    sleep "$interval"
  done
}

main() {
  [[ -n ${TMUX:-} ]] || exit 0

  if [[ ${1:-} == --ensure-running ]]; then
    ensure_running
    exit 0
  fi
  spin
}

# Dispatch only when run, so the tests can source this for agent_present and
# frame_label without starting a spinner.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
