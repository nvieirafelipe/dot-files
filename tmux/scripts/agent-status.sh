#!/usr/bin/env bash
set -euo pipefail

# Sets the Agent status shown in the tmux window (tab) name, and optionally
# raises a desktop notification. Called from the agent lifecycle hooks in
# ~/.claude/settings.json and ~/.codex/hooks.json; see the status-tracking block
# in .tmux.conf.
#
# Five window-scoped tmux user options are written:
#   @agent_state          bare state name, so clear-transient can tell them apart
#   @agent_state_colour         the state's colour, so agent-spinner.sh can redraw frames
#   @agent_glyph    per-agent marker, so the spinner can rebuild the label
#   @agent_status         styled label for an inactive tab (state colour on the bar)
#   @agent_status_active  styled label for the active tab, whose background is the
#                       accent colour -- the state colour is unreadable on it, so
#                       this variant uses the theme's active foreground instead
#
# .tmux.conf picks between the two with #{?window_active,...}. Neither emits a
# trailing reset: the label is the last ink and tmux-nova respecifies fg and bg
# straight after for the padding and separator.

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Hooks pipe their event JSON on stdin. Read it only when stdin is not a tty, so
# running this by hand does not block waiting for input.
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
detachable=1
case " $* " in
  *' clear-transient '* | *' reconcile '*) detachable=0 ;;
esac

if ((detachable)) && [[ -z ${AGENT_STATUS_DETACHED:-} && ! -t 0 ]]; then
  now=$EPOCHREALTIME
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

# Detached runs for one window have to take turns. The stamp above orders them,
# but reading it and acting on it are two steps, and without a lock a run can
# read the state before a newer one writes and then overwrite it a moment later
# -- which is exactly how a 'clear' ended up repainted by the 'working' it had
# already superseded. mkdir is the atomic primitive available everywhere.
#
# The wait is bounded and the lock is abandoned if it is older than ten seconds,
# so a run killed mid-flight costs one late update rather than wedging the
# window's status for the rest of the session.
agent_lock=''
take_lock() {
  local dir=${TMPDIR:-/tmp}/agent-status${1//[^A-Za-z0-9]/_}.lock i
  for ((i = 0; i < 60; i++)); do
    if mkdir "$dir" 2>/dev/null; then
      agent_lock=$dir
      trap 'rmdir "$agent_lock" 2>/dev/null || true' EXIT
      return 0
    fi
    # Whoever held it is gone; take it over rather than wait out the timeout.
    if [[ -d $dir ]] && find "$dir" -maxdepth 0 -mmin +0.16 2>/dev/null | grep -q .; then
      rmdir "$dir" 2>/dev/null || true
      continue
    fi
    sleep 0.05
  done
  return 0
}

# One top-level field out of the hook payload, empty if absent.
field() {
  [[ -n $payload ]] || return 0
  printf '%s' "$payload" | jq -r --arg k "$1" '.[$k] // empty' 2>/dev/null || true
}

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

usage() {
  printf 'usage: %s [--agent <name>] <working|waiting|done|idle|clear|clear-transient|reconcile> [pane]\n' \
    "${0##*/}" >&2
  exit 1
}

agent=""
args=()
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

# Per-agent marker shown before the state glyph, so two harnesses running side
# by side are distinguishable at a glance.
# The agent marker keeps its own colour so the harness is identifiable at a
# glance regardless of state. One shade suffices because the active tab uses a
# dark background too -- when it was light purple, every glyph on it had to be
# darkened, and dark orange reads as maroon whatever its hue.
case $agent in
  codex)
    agent_glyph='󰻟'
    agent_colour='#7dcfff'
    ;;
  *)
    agent_glyph='󰚩'
    agent_colour='#ff9e64'
    ;;
esac

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

case $state in
  working) glyph=''; colour='#e0af68' ;;
  waiting) glyph=''; colour='#7dcfff' ;;
  done)    glyph='';    colour='#9ece6a' ;;
  idle)
    # Agent present but between turns: show the harness marker only, dimmed.
    glyph=''
    colour='#a9b1d6'
    ;;
  clear)
    ((seq_now > 0)) && take_lock "$window"
    clear_status
    tmux refresh-client -S
    exit 0
    ;;
  reconcile)
    # State is only ever written by hook events, so it drifts: a missed or lost
    # event leaves a window blank until its next prompt, and an agent killed
    # mid-turn leaves 'working' set forever. Re-derive from what is actually
    # running instead of trusting the event stream.
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
    current=$(tmux show-option -w -t "$window" -qv @agent_state)
    case $current in
      waiting | done)
        clear_status
        tmux refresh-client -S
        ;;
    esac
    # Focus is also a good moment to re-derive: it is when a drifted tab is
    # most visible, and it costs one list-panes call.
    exec "$0" reconcile "$pane"
    ;;
  *) usage ;;
esac

# Taken from the theme rather than hardcoded, so the active-tab variant keeps
# working if the palette changes. Read as a format off the pane already being
# addressed rather than with show-option, so it costs no extra invocation: a
# global user option resolves through #{@name} like any other.
((seq_now > 0)) && take_lock "$window"
read_facts=$(tmux display-message -p -t "$pane" \
  '#{@nova-status-style-active-fg}'$'\x1f''#{pane_current_path}'$'\x1f''#{@agent_seq}' 2>/dev/null) || read_facts=''
IFS=$'\x1f' read -r active_fg pane_cwd seq_seen <<<"$read_facts"

# A later invocation already wrote: leave its state alone. Only meaningful
# between detached runs, which is why the stamp is taken before the fork.
if [[ -n ${seq_seen:-} && -n ${seq_now:-} ]] && ((seq_now > 0)) && ((seq_seen > seq_now)); then
  exit 0
fi
active_fg=${active_fg:-#24283b}
active_fg=${active_fg%%,*}

# Every option this script writes goes in one invocation, chained with ';'.
# Each tmux call is a process, and on this machine a process costs tens of
# milliseconds before it has done anything; at a dozen of them the hooks were
# taking longer than the five seconds Claude Code and Codex allow, so the state
# never landed at all. Built as an array and sent once.
declare -a set_cmd=()
add_opt() {
  ((${#set_cmd[@]})) && set_cmd+=(';')
  set_cmd+=(set-option -w -t "$window" "$1" "$2")
}

# A turn starting is the only moment its context is available: the prompt is in
# this event, and HEAD has to be recorded now to diff against later.
if [[ $state == working ]]; then
  cwd=$(field cwd)
  [[ -n $cwd ]] || cwd=$pane_cwd

  add_opt @agent_started "$(date +%s)"

  prompt=$(field prompt | oneline 90)
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
# Two spaces, not one: both glyphs are drawn wide inside their cells, so a
# single space reads as the two icons touching.
[[ -n $glyph ]] && glyph="  $glyph"
[[ $state == idle ]] && agent_colour=$colour

# Trailing space: nova pads one cell after the label, which is not enough to
# keep a wide glyph off the separator.
add_opt @agent_status "#[fg=$agent_colour]$agent_glyph#[fg=$colour]$glyph "
add_opt @agent_status_active "#[fg=$agent_colour]$agent_glyph#[fg=$colour]$glyph "
tmux "${set_cmd[@]}" ';' refresh-client -S
unset -f add_opt

# Desktop notification for the states that want a human. Suppressed while the
# window is on screen -- you are already looking at it -- and disabled entirely
# with: tmux set -g @agent-notify off
# Frontmost macOS application, or empty if it cannot be determined.
frontmost_app() {
  local asn
  asn=$(lsappinfo front 2>/dev/null) || return 0
  [[ -n $asn ]] || return 0
  lsappinfo info -only name "$asn" 2>/dev/null \
    | sed -n 's/.*"LSDisplayName"="\(.*\)".*/\1/p'
}

# Apps that count as "you can see the terminal". Override with:
#   tmux set -g @agent-notify-terminals 'iTerm2,Ghostty'
# One read for everything the notification path needs: the two global settings
# and the three window facts. Separately these were five processes on a path
# that already had too many -- see the note on the batched writes above.
# \x1f rather than a tab: a window name or a terminal list can contain spaces,
# and an unset option is empty, which a tab separator would swallow.
notify_facts=$(tmux display-message -p -t "$window" \
  '#{@agent-notify-terminals}'$'\x1f''#{@agent-notify}'$'\x1f''#{window_active_clients}'$'\x1f''#{window_name}'$'\x1f''#{session_name}' \
  2>/dev/null) || notify_facts=''
IFS=$'\x1f' read -r terminal_apps notify_off win_viewers win_name_f session_f <<<"$notify_facts"
terminal_apps=${terminal_apps:-iTerm2,iTerm,Ghostty,kitty,Terminal,Alacritty,WezTerm}
terminal_apps=${terminal_apps//,/$'\n'}

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

    prompt=$(tmux show-option -w -t "$window" -qv @agent_prompt | oneline 50)
    [[ -n $prompt ]] && prompt="👤 $prompt"

    # Codex hands the reply over directly; Claude Code gives a transcript path
    # and expects the last assistant block to be dug out of the JSONL.
    reply=$(field last_assistant_message | oneline 44)
    if [[ -z $reply ]]; then
      local transcript
      transcript=$(field transcript_path)
      if [[ -n $transcript && -r $transcript ]]; then
        # jq rather than a JSON parser written out by hand: it is already a
        # dependency of this script (see field above), and `fromjson?` drops the
        # partial line that tail -400 can leave at the head of its output
        # instead of failing on it.
        # The closing paragraph summarises; the opening one is usually "let me
        # check ...", so the last one is the one worth showing.
        reply=$(tail -400 "$transcript" 2>/dev/null | jq -nRr '
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
        ' 2>/dev/null | oneline 44 || true)
      fi
    fi

    head=$(tmux show-option -w -t "$window" -qv @agent_head)
    cwd=$(tmux show-option -w -t "$window" -qv @agent_cwd)
    [[ -n $cwd ]] || cwd=$(tmux display-message -p -t "$pane" '#{pane_current_path}' 2>/dev/null || true)
    if [[ -n $cwd ]] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
      local commits stat
      commits=""
      if [[ -n $head ]] && git -C "$cwd" cat-file -e "$head" 2>/dev/null; then
        commits=$(git -C "$cwd" rev-list --count "$head"..HEAD 2>/dev/null || true)
      fi
      # Uncommitted work counts too -- most turns end dirty rather than committed.
      # "3 files changed, 12 insertions(+), 4 deletions(-)" -> "3 files +12 -4"
      stat=$(git -C "$cwd" diff --shortstat HEAD 2>/dev/null | awk '
        { f=""; i=0; d=0
          for (n = 1; n <= NF; n++) {
            if ($n ~ /^file/)      f = $(n-1) " " ($(n-1) == 1 ? "file" : "files")
            if ($n ~ /^insertion/) i = $(n-1)
            if ($n ~ /^deletion/)  d = $(n-1)
          }
          if (i > 0)   printf "%s\360\237\237\242+%s", (o++ ? " " : ""), i
          if (d > 0)   printf "%s\360\237\224\264-%s", (o++ ? " " : ""), d
          if (f != "") printf " \302\267 %s", f
        }')
      delta=""
      [[ -n ${commits:-} && ${commits:-0} -gt 0 ]] && delta="${commits} commit$([[ $commits -eq 1 ]] || printf s)"
      [[ -n $stat ]] && delta="${delta:+$delta · }$stat"
    fi

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
    ask=$(field message | oneline 46)
    detail="💬 ${ask:-waiting for your input}"
    local started_w
    started_w=$(tmux show-option -w -t "$window" -qv @agent_started)
    [[ -n $started_w ]] && elapsed=$(duration "$(( $(date +%s) - started_w ))")
    prompt=$(tmux show-option -w -t "$window" -qv @agent_prompt | oneline 50)
    [[ -n $prompt ]] && prompt="👤 $prompt"
  fi

  # Distinct sounds so 'finished' and 'needs you' are tellable apart without
  # looking. Names come from /System/Library/Sounds; 'none' disables one.
  case $state in
    waiting) sound=$(tmux show-option -gqv @agent-notify-sound-waiting); sound=${sound:-Ping} ;;
    *)       sound=$(tmux show-option -gqv @agent-notify-sound-done);    sound=${sound:-Glass} ;;
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

case $state in
  done)    notify "finished" ;;
  waiting) notify "" ;;
esac

# The spinner animates the 'working' glyph. It exits on its own once no window
# is working, so starting it here is enough.
[[ $state == working ]] && "$script_dir/agent-spinner.sh" --ensure-running

exit 0
