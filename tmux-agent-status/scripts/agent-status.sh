#!/usr/bin/env bash
set -euo pipefail

# Sets the agent status shown in the tmux window (tab) name, and optionally
# raises a desktop notification. Called from the agent lifecycle hooks in
# ~/.claude/settings.json and ~/.codex/hooks.json through bin/agent-status, and
# from the tmux hooks this plugin's entry point binds.
#
# Five window-scoped tmux user options are written:
#   @agent_state          bare state name, so clear-transient can tell them apart
#   @agent_state_colour   the state's colour, so agent-spinner.sh can redraw frames
#   @agent_glyph          per-agent marker, so the spinner can rebuild the label
#   @agent_status         styled label for an inactive tab (state colour on the bar)
#   @agent_status_active  styled label for the active tab, whose background is the
#                         accent colour -- the state colour is unreadable on it, so
#                         this variant uses the theme's active foreground instead
#
# The status format picks between the two with #{?window_active,...}. Neither
# emits a trailing reset: the label is the last ink, and tmux-nova respecifies
# fg and bg straight after for the padding and separator.
#
# Nothing runs when this file is sourced -- see the dispatch at the bottom --
# so the tests can reach the functions without a tmux server.

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck source-path=SCRIPTDIR source=variables.sh
source "$script_dir/variables.sh"

# --------------------------------------------------------------------- text

# Collapse to one line and clip with an ellipsis. Notification bodies are a
# single line here on purpose -- a wrapped body pushes the tail out of the
# collapsed banner, and the tail is where the git delta sits.
oneline() {
  local limit=${1:-90}
  local -a words=()
  local text

  # `read -a` splits on IFS, which collapses runs of spaces, tabs and newlines
  # exactly as Python's str.split() did; "${words[*]}" then puts a single space
  # back between them. read reports failure when it reaches EOF without seeing
  # its delimiter, which is the normal case here rather than an error.
  IFS=$' \t\n' read -r -d '' -a words || true
  text="${words[*]}"

  # ${#text} and ${text:0:n} count characters rather than bytes under the UTF-8
  # locale tmux passes down, so an emoji or an accent is never cut in half.
  if ((${#text} > limit)); then
    text=${text:0:limit-1}
    text=${text%"${text##*[![:space:]]}"}
    text+=$'…'
  fi
  printf '%s' "$text"
}

# 93s -> 1m33s, 3771s -> 1h2m
duration() {
  local s=$1
  if   ((s < 60));   then printf '%ds' "$s"
  elif ((s < 3600)); then printf '%dm%ds' "$((s / 60))" "$((s % 60))"
  else                    printf '%dh%dm' "$((s / 3600))" "$(((s % 3600) / 60))"
  fi
}

# git's own summary, shortened to what fits a banner line:
# "3 files changed, 12 insertions(+), 4 deletions(-)" -> "+12 -4 · 3 files".
# Reads the shortstat on stdin and prints nothing for an empty one.
format_shortstat() {
  awk '
    { f=""; i=0; d=0
      for (n = 1; n <= NF; n++) {
        if ($n ~ /^file/)      f = $(n-1) " " ($(n-1) == 1 ? "file" : "files")
        if ($n ~ /^insertion/) i = $(n-1)
        if ($n ~ /^deletion/)  d = $(n-1)
      }
      if (i > 0)   printf "%s\360\237\237\242+%s", (o++ ? " " : ""), i
      if (d > 0)   printf "%s\360\237\224\264-%s", (o++ ? " " : ""), d
      if (f != "") printf " \302\267 %s", f
    }'
}

# What a turn changed is measured from the working tree as the turn found it, not
# from HEAD. Against HEAD, anything already uncommitted when the prompt went in
# was reported as the turn's own work, turn after turn, including by turns that
# changed nothing at all.
#
# The snapshot is git's own staging, pointed somewhere else: a copy of the index
# and an object store of its own, in a directory beside the window's lock. The
# repository is never written. Two things would write to it all the same, and
# both are switched off for every call: a split index keeps a shared file next to
# the index it was written for, and the file-system monitor starts a daemon that
# keeps its socket in .git.
snapshot_git() {
  local snap=$1 top=$2
  shift 2
  GIT_INDEX_FILE=$snap/index GIT_OBJECT_DIRECTORY=$snap/objects \
    git -C "$top" -c core.splitIndex=false -c core.fsmonitor=false "$@"
}

# Where a window's snapshot lives: beside its lock, named the same way.
turn_dir() { printf '%s' "${TMPDIR:-/tmp}/agent-status${1//[^A-Za-z0-9]/_}.turn"; }

# Taken as a turn begins. The real index is copied for its stat cache, so only
# the files that differ from it are read and stored -- which is whatever was
# already dirty or untracked, not the whole tree. A repository with no commits
# has no index yet, and starts from none.
snapshot_turn() {
  local dir=$1 snap=$2 paths top index objects
  rm -rf "$snap"
  paths=$(git -C "$dir" rev-parse --show-toplevel --path-format=absolute \
    --git-path index --git-path objects 2>/dev/null) || return 0
  { read -r top; read -r index; read -r objects; } <<<"$paths"
  mkdir -p "$snap/objects"
  [[ ! -e $index ]] || cp "$index" "$snap/index"
  snapshot_git "$snap" "$top" add -A 2>/dev/null || return 0
  # Last, because it is what makes this a snapshot: one killed or refused part
  # way has none, and is read as no snapshot rather than as half of one.
  printf '%s\n' "$top" "$objects" >"$snap/repo"
}

# The raw shortstat of everything between the snapshot and the working tree now,
# committed or not; nothing, and a failure, when there is no snapshot to read.
turn_shortstat() {
  local snap=$1 top objects
  [[ -r $snap/repo ]] || return 1
  { read -r top; read -r objects; } <"$snap/repo"
  # Files the turn created, entered without their content so the diff counts all
  # of it. --ignore-removal because add otherwise also drops what the turn
  # deleted, and a deletion taken out of the index is no longer in the diff.
  snapshot_git "$snap" "$top" add -N --ignore-removal . 2>/dev/null || return 1
  # The repository's objects are visible to this call and to no other. A git
  # about to store an object it can already see does not store it; it refreshes
  # the time on the copy it found, so the repository's own objects in view of
  # either add above would be touched -- a loose object by one, a pack by the
  # other.
  GIT_ALTERNATE_OBJECT_DIRECTORIES=$objects snapshot_git "$snap" "$top" \
    diff --shortstat 2>/dev/null || return 1
}

usage() {
  printf 'usage: %s [--agent <name>] <working|waiting|done|idle|clear|clear-transient|reconcile> [pane]\n' \
    "${0##*/}" >&2
  exit 1
}

# -------------------------------------------------------------------- style

# The glyph and colour a state is drawn in, or 1 if the state names no style --
# which is how main tells a typo from the states that are actions rather than
# things to draw.
state_style() {
  case $1 in
    working) glyph=$glyph_working; colour=$colour_working ;;
    waiting) glyph=$glyph_waiting; colour=$colour_waiting ;;
    done)    glyph=$glyph_done;    colour=$colour_done ;;
    idle)    glyph=$glyph_idle;    colour=$colour_idle ;;
    *) return 1 ;;
  esac
}

# The marker for the harness itself, which keeps its own colour whatever the
# state is.
agent_style() {
  case $1 in
    codex) agent_glyph=$agent_glyph_codex; agent_colour=$agent_colour_codex ;;
    *)     agent_glyph=$agent_glyph_default; agent_colour=$agent_colour_default ;;
  esac
}

# The label itself: marker, then state glyph, in their own colours.
#
# Two spaces between them, not one: both glyphs are drawn wide inside their
# cells, so a single space reads as the two icons touching. And a trailing one,
# because tmux-nova pads a single cell after the label, which is not enough to
# keep a wide glyph off the separator.
render_label() {
  local agent_glyph=$1 agent_colour=$2 glyph=$3 colour=$4
  [[ -n $glyph ]] && glyph="  $glyph"
  printf '#[fg=%s]%s#[fg=%s]%s ' "$agent_colour" "$agent_glyph" "$colour" "$glyph"
}

# --------------------------------------------------------------------- tmux

# Detached runs for one window have to take turns. Their stamps order them, but
# reading a stamp and acting on it are two steps, and without a lock a run can
# read the state before a newer one writes and then overwrite it a moment later
# -- which is exactly how a 'clear' ended up repainted by the 'working' it had
# already superseded. mkdir is the atomic primitive available everywhere.
#
# The wait is bounded and the lock is abandoned if it is older than lock_stale,
# so a run killed mid-flight costs one late update rather than wedging the
# window's status for the rest of the session.
agent_lock=''
release_lock() {
  [[ -n $agent_lock ]] || return 0
  rm -f "$agent_lock/at" 2>/dev/null || true
  rmdir "$agent_lock" 2>/dev/null || true
}

take_lock() {
  local dir=${TMPDIR:-/tmp}/agent-status${1//[^A-Za-z0-9]/_}.lock i held
  for ((i = 0; i < lock_tries; i++)); do
    if mkdir "$dir" 2>/dev/null; then
      # When it was taken, so whoever comes next can tell a held lock from an
      # abandoned one. In the directory rather than in its mtime, because the
      # only portable way to read an mtime is another process -- and `find
      # -mmin` cannot express ten seconds at all: the fractional minute it was
      # asked for is rejected outright by both the BSD find macOS ships and by
      # bfs, so the steal below never once happened.
      printf '%s' "${EPOCHSECONDS:-0}" >"$dir/at" 2>/dev/null || true
      agent_lock=$dir
      trap release_lock EXIT
      return 0
    fi
    # Whoever held it is gone; take it over rather than wait out the timeout.
    held=$(<"$dir/at") 2>/dev/null || held=''
    if ((${EPOCHSECONDS:-0} - ${held:-0} >= lock_stale)); then
      rm -f "$dir/at" 2>/dev/null || true
      rmdir "$dir" 2>/dev/null || true
      continue
    fi
    sleep "$lock_wait"
  done
  return 0
}

# One top-level field out of the hook payload, empty if absent.
field() {
  [[ -n $payload ]] || return 0
  printf '%s' "$payload" | jq -r --arg k "$1" '.[$k] // empty' 2>/dev/null || true
}

# Which agent, if any, is running anywhere in a window. Claude Code installs its
# binary as ~/.local/share/claude/versions/<version>, so its pane_current_command
# is the version string rather than a name -- hence the numeric pattern.
agent_in_window() {
  local cmd
  while read -r cmd; do
    case $cmd in
      codex) printf 'codex'; return 0 ;;
      claude | [0-9]*.[0-9]*.[0-9]*) printf 'claude'; return 0 ;;
    esac
  done < <(tmux list-panes -t "$1" -F '#{pane_current_command}' 2>/dev/null)
  return 0
}

clear_status() {
  local opt
  local -a cmd=()
  for opt in @agent_status @agent_status_active @agent_state @agent_state_colour \
    @agent_glyph @agent_glyph_colour @agent_started @agent_prompt @agent_head \
    @agent_cwd; do
    ((${#cmd[@]})) && cmd+=(';')
    cmd+=(set-option -w -t "$window" -u "$opt")
  done
  # Its own stamp survives the wipe, so a detached run that was started before
  # this one but arrives after it cannot repaint what was just cleared.
  if ((${seq_now:-0} > 0)); then
    cmd+=(';' set-option -w -t "$window" @agent_seq "$seq_now")
  else
    cmd+=(';' set-option -w -t "$window" -u @agent_seq)
  fi
  tmux "${cmd[@]}"
}

# Every option this script writes goes out in one invocation, chained with ';'.
# Each tmux call is a process, and on this machine a process costs tens of
# milliseconds before it has done anything; at a dozen of them the hooks were
# taking longer than the five seconds Claude Code and Codex allow, so the state
# never landed at all. Built as an array and sent once.
declare -a set_cmd=()
add_opt() {
  ((${#set_cmd[@]})) && set_cmd+=(';')
  set_cmd+=(set-option -w -t "$window" "$1" "$2")
}

# ------------------------------------------------------------- notification

# Frontmost macOS application, or empty if it cannot be determined.
frontmost_app() {
  local asn
  asn=$(lsappinfo front 2>/dev/null) || return 0
  [[ -n $asn ]] || return 0
  lsappinfo info -only name "$asn" 2>/dev/null \
    | sed -n 's/.*"LSDisplayName"="\(.*\)".*/\1/p'
}

# The last thing the agent said, dug out of a Claude Code transcript.
#
# jq rather than a JSON parser written out by hand: it is already a dependency
# of this script (see field above), and `fromjson?` drops the partial line that
# tailing the file can leave at the head of its output instead of failing on
# it. The closing paragraph summarises; the opening one is usually "let me
# check ...", so the last one is the one worth showing.
transcript_reply() {
  [[ -n $1 && -r $1 ]] || return 0
  tail -"$transcript_tail" "$1" 2>/dev/null | jq -nRr '
    [ inputs
      | fromjson? // empty
      | select(.type == "assistant")
      | (.message.content // [])[]?
      | select(.type == "text" and ((.text // "") | test("\\S")))
      | .text
    ]
    | (last // "")
    | [ splits("\n\n") | sub("^\\s+";"") | sub("\\s+$";"") | select(. != "") ]
    | (last // "")
  ' 2>/dev/null || true
}

# Desktop notification for the states that want a human. Suppressed while the
# window is on screen -- you are already looking at it -- and disabled entirely
# with: tmux set -g @agent-notify off
notify() {
  [[ $notify_off != off ]] || return 0
  # Suppress only when you are genuinely looking at this window, which needs two
  # facts. tmux knows whether a client displays the window (window_active_clients
  # -- not window_active, which is true for the front window of every session,
  # attached or not). It has no idea what macOS has focused, so a terminal buried
  # behind a browser still counts as "viewing". lsappinfo supplies the other half
  # and needs no automation permission, unlike System Events.
  local viewers front
  viewers=${win_viewers:-0}
  if [[ ${viewers:-0} -gt 0 ]]; then
    front=$(frontmost_app)
    # Unknown frontmost app: notify anyway. A spurious banner beats a missed one.
    if [[ -n $front ]] && printf '%s\n' "$terminal_apps" | grep -qxF "$front"; then
      return 0
    fi
  fi
  local win_name session sound
  local elapsed="" prompt="" reply="" delta="" detail="$1" ask=""
  win_name=${win_name_f:-tmux}
  session=${session_f:-tmux}

  # --- what the turn actually did -------------------------------------------
  # Only worth assembling for a finished turn; 'waiting' has nothing to report
  # yet, and Codex's PermissionRequest carries no description of the request.
  if [[ $state == "done" ]]; then
    local started head cwd
    started=$(tmux show-option -w -t "$window" -qv @agent_started)
    [[ -n $started ]] && elapsed=$(duration "$(( $(date +%s) - started ))")

    prompt=$(tmux show-option -w -t "$window" -qv @agent_prompt | oneline "$limit_prompt_notify")
    [[ -n $prompt ]] && prompt="👤 $prompt"

    # Codex hands the reply over directly; Claude Code gives a transcript path
    # and expects the last assistant block to be dug out of the JSONL.
    reply=$(field last_assistant_message | oneline "$limit_reply")
    if [[ -z $reply ]]; then
      reply=$(transcript_reply "$(field transcript_path)" | oneline "$limit_reply")
    fi

    head=$(tmux show-option -w -t "$window" -qv @agent_head)
    cwd=$(tmux show-option -w -t "$window" -qv @agent_cwd)
    [[ -n $cwd ]] || cwd=$(tmux display-message -p -t "$pane" '#{pane_current_path}' 2>/dev/null || true)
    local commits="" stat
    if [[ -n $cwd ]] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
      if [[ -n $head ]] && git -C "$cwd" cat-file -e "$head" 2>/dev/null; then
        commits=$(git -C "$cwd" rev-list --count "$head"..HEAD 2>/dev/null || true)
      fi
    fi
    # Everything the turn changed, committed or not, measured from the snapshot
    # it began with. The snapshot knows its own repository, so this needs no
    # directory from the pane. Without one there is no line at all: HEAD would
    # answer, and HEAD is what counted work from before the turn as the turn's.
    stat=$(turn_shortstat "$(turn_dir "$window")" | format_shortstat) || stat=''
    delta=""
    [[ -n ${commits:-} && ${commits:-0} -gt 0 ]] && delta="${commits} commit$([[ $commits -eq 1 ]] || printf s)"
    [[ -n $stat ]] && delta="${delta:+$delta · }$stat"

    # Reply on its own line, delta on the next, both left-aligned. The banner
    # shows four lines -- title, subtitle and two body lines -- so this is the
    # budget. Right-aligning the delta was tried and reverted: notifications
    # expose no alignment, and padding it with spaces in a proportional font
    # either leaves a ragged edge or overshoots and wraps the line out of the
    # collapsed banner, losing the delta entirely.
    detail="🤖 ${reply:-finished}"
    [[ -n ${delta:-} ]] && detail="$detail"$'\n'"$delta"
  fi

  if [[ $state == waiting ]]; then
    ask=$(field message | oneline "$limit_ask")
    detail="💬 ${ask:-waiting for your input}"
    local started_w
    started_w=$(tmux show-option -w -t "$window" -qv @agent_started)
    [[ -n $started_w ]] && elapsed=$(duration "$(( $(date +%s) - started_w ))")
    prompt=$(tmux show-option -w -t "$window" -qv @agent_prompt | oneline "$limit_prompt_notify")
    [[ -n $prompt ]] && prompt="👤 $prompt"
  fi

  case $state in
    waiting) sound=$(tmux show-option -gqv @agent-notify-sound-waiting)
             sound=${sound:-$notify_sound_waiting_default} ;;
    *)       sound=$(tmux show-option -gqv @agent-notify-sound-done)
             sound=${sound:-$notify_sound_done_default} ;;
  esac
  local sound_args=()
  [[ $sound != none && $sound != off ]] && sound_args=(-sound "$sound")
  # terminal-notifier registers itself as a real app, so its banners can be
  # granted permission in System Settings. osascript's cannot -- 'display
  # notification' is attributed to Script Editor, which is not registered here.
  # Kept as a fallback in case terminal-notifier is not installed.
  #
  # Whether a banner fades on its own or sits there until it is clicked is not
  # ours to decide and there is no flag for it: it is the app's alert style, in
  # System Settings > Notifications > terminal-notifier, Banners rather than
  # Alerts. Banners still land in Notification Center, so nothing is lost by
  # letting them go.
  #
  # It only appears in that list once macOS knows the app, which it does not
  # from a Homebrew Cellar path alone:
  #
  #   lsregister -f /opt/homebrew/Cellar/terminal-notifier/*/terminal-notifier.app
  #
  # (lsregister lives under CoreServices.framework/Frameworks/LaunchServices
  # .framework/Support.) Do not reach for -remove to make them go away -- that
  # withdraws the notification from Notification Center as well, which is the
  # opposite of wanting it out of the way but still readable later.
  if command -v terminal-notifier >/dev/null; then
    # Clicking the banner jumps to the window that raised it: agent-focus.sh
    # switches the tmux client and raises whichever terminal app hosts it.
    # Pass the pane id, not session:window -- it is unique, survives renumbering,
    # and lets the click land on the exact pane the agent runs in.
    local target=$pane
    terminal-notifier \
      -title "$(printf '%s' "$session · ${agent:-agent}${elapsed:+ · $elapsed}")" \
      -subtitle "$prompt" \
      -message "$(printf '%s' "$detail")" \
      -group "tmux-agent-$window" \
      -execute "$script_dir/agent-focus.sh '$target'" \
      "${sound_args[@]+"${sound_args[@]}"}" \
      >/dev/null 2>&1 || true
  elif command -v osascript >/dev/null; then
    osascript -e "display notification \"$1\" with title \"${agent:-agent} - $win_name\" subtitle \"$session\"" \
      >/dev/null 2>&1 || true
  fi
}

# --------------------------------------------------------------------- main

main() {
  # Hooks pipe their event JSON on stdin. Read it only when stdin is not a tty,
  # so running this by hand does not block waiting for input.
  payload=""
  if [[ ! -t 0 ]]; then
    payload=$(cat 2>/dev/null || true)
  fi

  # The agent harnesses allow a hook five seconds, and on a loaded machine the
  # tmux round trips outrun that -- the hook is killed part way and the status
  # never lands. None of this is worth making the agent wait for, so only the
  # part that cannot be deferred runs here: the payload arrives on a pipe the
  # caller closes as soon as this process exits, so it has to be read first, in
  # the foreground. Everything after it re-runs detached with its descriptors
  # off the hook's pipes -- leaving one open would keep the caller waiting even
  # though this process has gone -- and the hook returns immediately.
  #
  # Only when the payload came from a pipe: run by hand from a terminal it stays
  # in the foreground, where its output is the point.
  #
  # The marker travels in the environment, which bash re-exports, so the
  # self-calls further down (idle, reconcile) do not fork a second time. The
  # payload goes the same way rather than through stdin, which no longer exists
  # by then, and is unset once read so a nested call cannot inherit a payload
  # that was never addressed to it.
  # The sequence is taken here, in the caller's order, not in the detached run --
  # once detached they race, and a slow 'clear' could otherwise land on top of
  # the 'working' that legitimately followed it. Microseconds since the epoch,
  # with the dot removed so it compares as an integer.
  # clear-transient and reconcile come from tmux's own hooks, which already call
  # this with run-shell -b. Those must not detach: tmux reaps the process group
  # when the command it launched returns, so the grandchild is killed before it
  # has written anything -- which left a window still showing an agent that had
  # already exited. Only the harness hooks, which wait on this and give it five
  # seconds, have anything to gain.
  local detachable=1
  case " $* " in
    *' clear-transient '* | *' reconcile '*) detachable=0 ;;
  esac

  if ((detachable)) && [[ -z ${AGENT_STATUS_DETACHED:-} && ! -t 0 ]]; then
    local now=$EPOCHREALTIME
    AGENT_STATUS_DETACHED=1 AGENT_STATUS_PAYLOAD=$payload \
    AGENT_STATUS_SEQ="${now%.*}${now#*.}" \
      nohup "$script_dir/${BASH_SOURCE[0]##*/}" "$@" >/dev/null 2>&1 </dev/null &
    exit 0
  fi
  if [[ -n ${AGENT_STATUS_DETACHED:-} ]]; then
    payload=${AGENT_STATUS_PAYLOAD-$payload}
    unset AGENT_STATUS_PAYLOAD
  fi
  seq_now=${AGENT_STATUS_SEQ:-0}

  agent=""
  local -a args=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      --agent) [[ $# -ge 2 ]] || usage; agent=$2; shift 2 ;;
      *) args+=("$1"); shift ;;
    esac
  done
  set -- "${args[@]+"${args[@]}"}"

  [[ $# -ge 1 ]] || usage

  state=$1
  pane=${2:-${TMUX_PANE:-}}

  # Nothing to do outside tmux
  [[ -n ${TMUX:-} && -n $pane ]] || exit 0

  window=$(tmux display-message -p -t "$pane" '#{window_id}' 2>/dev/null) || exit 0

  agent_style "$agent"

  # The states that act on what is already there, rather than naming something
  # to draw. Each one is done when it returns.
  case $state in
    clear)
      ((seq_now > 0)) && take_lock "$window"
      clear_status
      # Only here, when a session starts, and not in clear_status: that also runs
      # when a waiting window is looked at, part way through the turn the
      # snapshot belongs to.
      rm -rf "$(turn_dir "$window")"
      tmux refresh-client -S
      exit 0
      ;;
    reconcile)
      # State is only ever written by hook events, so it drifts: a missed or lost
      # event leaves a window blank until its next prompt, and an agent killed
      # mid-turn leaves 'working' set forever. Re-derive from what is actually
      # running instead of trusting the event stream.
      local current present
      current=$(tmux show-option -w -t "$window" -qv @agent_state)
      present=$(agent_in_window "$window")
      if [[ -z $present && -n $current ]]; then
        clear_status                       # agent gone, state stale
      elif [[ -n $present && -z $current ]]; then
        "$0" --agent "$present" idle "$pane"
      fi
      tmux refresh-client -S
      exit 0
      ;;
    clear-transient)
      # 'waiting' and 'done' are acknowledged by looking at the tab, so drop them
      # on focus. 'working' is left alone -- the agent is still going.
      local seen
      seen=$(tmux show-option -w -t "$window" -qv @agent_state)
      case $seen in
        waiting | done)
          clear_status
          tmux refresh-client -S
          ;;
      esac
      # Focus is also a good moment to re-derive: it is when a drifted tab is
      # most visible, and it costs one list-panes call.
      exec "$0" reconcile "$pane"
      ;;
  esac

  # Anything left has to name a style; anything that does not is a typo.
  state_style "$state" || usage

  # The active-tab foreground is taken from the theme rather than hardcoded, so
  # the variant keeps working if the palette changes. Read as a format off the
  # pane already being addressed rather than with show-option, so it costs no
  # extra invocation: a global user option resolves through #{@name} like any
  # other.
  ((seq_now > 0)) && take_lock "$window"
  local read_facts seq_seen
  read_facts=$(tmux display-message -p -t "$pane" \
    '#{@nova-status-style-active-fg}'$'\x1f''#{pane_current_path}'$'\x1f''#{@agent_seq}' 2>/dev/null) || read_facts=''
  IFS=$'\x1f' read -r active_fg pane_cwd seq_seen <<<"$read_facts"

  # A later invocation already wrote: leave its state alone. Only meaningful
  # between detached runs, which is why the stamp is taken before the fork.
  if [[ -n ${seq_seen:-} && -n ${seq_now:-} ]] && ((seq_now > 0)) && ((seq_seen > seq_now)); then
    exit 0
  fi
  active_fg=${active_fg:-$active_fg_default}
  active_fg=${active_fg%%,*}

  # A turn starting is the only moment its context is available: the prompt is in
  # this event, and HEAD has to be recorded now to diff against later.
  if [[ $state == working ]]; then
    local cwd prompt head
    cwd=$(field cwd)
    [[ -n $cwd ]] || cwd=$pane_cwd

    add_opt @agent_started "$(date +%s)"

    prompt=$(field prompt | oneline "$limit_prompt")
    [[ -n $prompt ]] && add_opt @agent_prompt "$prompt"

    head=$(git -C "$cwd" rev-parse HEAD 2>/dev/null || true)
    [[ -n $head ]] && add_opt @agent_head "$head"
    [[ -n $cwd ]] && add_opt @agent_cwd "$cwd"
  fi

  ((seq_now > 0)) && add_opt @agent_seq "$seq_now"
  add_opt @agent_state "$state"
  add_opt @agent_state_colour "$colour"
  add_opt @agent_glyph "$agent_glyph"
  add_opt @agent_glyph_colour "$agent_colour"
  # An idle agent is the marker alone, so the marker takes the state's colour
  # rather than the harness's.
  [[ $state == idle ]] && agent_colour=$colour

  local label
  label=$(render_label "$agent_glyph" "$agent_colour" "$glyph" "$colour")
  add_opt @agent_status "$label"
  add_opt @agent_status_active "$label"
  tmux "${set_cmd[@]}" ';' refresh-client -S

  # After the tab is drawn rather than before, so the reader is not kept waiting
  # on it. The lock is still held, so the done that ends this turn cannot read
  # the snapshot before it is whole.
  [[ $state == working ]] && snapshot_turn "$cwd" "$(turn_dir "$window")"

  # One read for everything the notification path needs: the two global settings
  # and the three window facts. Separately these were five processes on a path
  # that already had too many -- see the note on the batched writes above.
  # \x1f rather than a tab: a window name or a terminal list can contain spaces,
  # and an unset option is empty, which a tab separator would swallow.
  local notify_facts
  notify_facts=$(tmux display-message -p -t "$window" \
    '#{@agent-notify-terminals}'$'\x1f''#{@agent-notify}'$'\x1f''#{window_active_clients}'$'\x1f''#{window_name}'$'\x1f''#{session_name}' \
    2>/dev/null) || notify_facts=''
  IFS=$'\x1f' read -r terminal_apps notify_off win_viewers win_name_f session_f <<<"$notify_facts"
  terminal_apps=${terminal_apps:-$notify_terminals_default}
  terminal_apps=${terminal_apps//,/$'\n'}

  case $state in
    done)    notify "finished" ;;
    waiting) notify "" ;;
  esac

  # The spinner animates the 'working' glyph. It exits on its own once no window
  # is working, so starting it here is enough.
  [[ $state == working ]] && "$script_dir/agent-spinner.sh" --ensure-running

  exit 0
}

# Dispatch only when run. The tests source this file to reach the functions
# that need no tmux, and sourcing must not run anything.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
