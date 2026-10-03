#!/usr/bin/env bash
set -euo pipefail

# Focuses a tmux session/window and raises the terminal app showing it. Wired to
# the notification's click action by agent-status.sh (terminal-notifier -execute).
#
# Usage: agent-focus.sh <pane-id|session:window>
#
# A pane id (%12) is preferred: it is globally unique and survives windows being
# renumbered or moved, and it pins the exact pane the agent runs in.

# Notification Center launches this with a minimal PATH (/usr/bin:/bin:/usr/sbin:
# /sbin), which does not include Homebrew -- so an unqualified `tmux` is not
# found and every call fails. Put the usual prefixes back before anything else.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

log=${TMPDIR:-/tmp}/agent-focus.log

note() {
  printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$log" 2>/dev/null || true
}

usage() {
  printf 'usage: %s <session>:<window>\n' "${0##*/}" >&2
  exit 1
}

# The bundled app a process belongs to, found by walking up from it until a
# path of the .app/Contents/MacOS/ shape turns up. Which terminal is hosting
# the client is not assumed anywhere: it is read off the process tree.
app_from_pid() {
  local pid=$1 exe
  while [[ -n ${pid:-} && $pid -gt 1 ]]; do
    exe=$(ps -o comm= -p "$pid" 2>/dev/null || true)
    if [[ $exe == *.app/Contents/MacOS/* ]]; then
      exe=${exe%%.app/Contents/MacOS/*}
      printf '%s' "${exe##*/}"
      return 0
    fi
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ' || true)
  done
  return 0
}

# The bundle id LaunchServices gave the terminal, read off the client's
# environment, which everything the terminal starts inherits. The fallback for
# terminals whose shells do not descend from the app: iTerm2 hosts them in
# iTermServer, a daemon launchd parents, so the walk above reaches pid 1 without
# passing a bundle.
bundle_from_pid() {
  ps -E -ww -o command= -p "$1" 2>/dev/null \
    | tr ' ' '\n' | sed -n 's/^__CFBundleIdentifier=//p' | head -1 || true
}

main() {
  [[ $# -ge 1 ]] || usage

  local target=$1 session client app pid bundle

  # Fail into the log rather than silently: this runs with no terminal attached,
  # so a bare `exit 0` on a broken environment is invisible.
  command -v tmux >/dev/null || {
    note "tmux not on PATH ($PATH)"
    exit 0
  }

  # Resolve whatever was passed to a concrete session, so the target is verified
  # to still exist before anything is switched.
  session=$(tmux display-message -p -t "$target" '#{session_name}' 2>/dev/null || true)
  [[ -n $session ]] || {
    note "target gone: $target"
    exit 0
  }

  note "focusing $target (session $session)"

  # Pick the most recently used attached client, so the jump happens in the
  # terminal window you touched last rather than an arbitrary one.
  client=$(tmux list-clients -F '#{client_activity} #{client_tty}' 2>/dev/null \
    | sort -rn | head -1 | cut -d' ' -f2)

  if [[ -n $client ]]; then
    # Three separate steps on purpose. switch-client -t only honours the session
    # part of its target, so on its own it lands on whichever window that session
    # last had selected -- select-window and select-pane pin the rest.
    tmux switch-client -c "$client" -t "$session" 2>/dev/null || true
    tmux select-window -t "$target" 2>/dev/null || true
    tmux select-pane -t "$target" 2>/dev/null || true
  fi

  # Raise the terminal app hosting that client. @agent-notify-app overrides the
  # search.
  app=$(tmux show-option -gqv @agent-notify-app)

  if [[ -z $app && -n $client ]]; then
    pid=$(tmux list-clients -F '#{client_tty} #{client_pid}' 2>/dev/null \
      | awk -v t="$client" '$1 == t { print $2; exit }')
    app=$(app_from_pid "$pid")
    [[ -n $app ]] || bundle=$(bundle_from_pid "$pid")
  fi

  # Logged either way: a click that raises nothing looks, from outside, exactly
  # like a click that was never delivered.
  if [[ -n ${app:-} ]]; then
    note "raising $app"
    open -a "$app" 2>/dev/null || true
  elif [[ -n ${bundle:-} ]]; then
    note "raising $bundle"
    open -b "$bundle" 2>/dev/null || true
  else
    note "no terminal app found for client ${client:-none} (pid ${pid:-none})"
  fi
  exit 0
}

# Dispatch only when run, so the tests can reach app_from_pid without focusing
# anything.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
