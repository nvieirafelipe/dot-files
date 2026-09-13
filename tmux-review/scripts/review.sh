#!/usr/bin/env bash
set -euo pipefail

# Two-pane review window: a narrow commit list on the left, the diff on the
# right, and the list highlights whichever commit the diff cursor is sitting in.
#
#   review.sh open <pane> [<range> [<return window>]]
#                                       build the window beside <pane>
#   review.sh diff <range> <width>      pane command: dump the diff
#   review.sh sidebar <pane> <range> [<window width> <window height>]
#                                       pane command: the commit list
#   review.sh jump <pane> next|prev|first|last <hist> <scroll> <cy> <row>...
#                                       move the view one stop point
#   review.sh quit <target>             close the window, back to where q was hit
#   review.sh nav <window> next|prev|first|last stop|file|commit
#                                       jump, addressed by window not pane
#
# The diff deliberately does not go through less. less is a full-screen
# application, so tmux cannot see where inside it the reader is. Dumping the
# diff into the pane's own scrollback and scrolling that with copy-mode instead
# exposes #{scroll_position} and #{copy_cursor_y}, which is what lets the sidebar
# highlight the commit being read rather than guess at one.

# Where this file lives, and so where the rest of the plugin does. -P so it
# survives being reached through the symlink install.sh puts in
# ~/.tmux/plugins: everything below is found beside the real file, not beside
# the link.
scripts_dir=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)
plugin_dir=${scripts_dir%/scripts}

# Sourced, not spawned. It answers the range and owns the git log options, and
# fetching those by running it cost a bash apiece -- once here and once per
# chunk of the diff. Everything it defines is prefixed gr_, so nothing here is
# shadowed. Still spawned by review.tmux's popup binding, which wants it as a
# command.
#
# Reached inside the plugin rather than at ~/.local/bin, so a review works from
# a checkout that has never been installed. install.sh still links it onto PATH,
# because `git review` on its own is worth having.
# Held in a variable as well as sourced: the popups that show the working tree
# and a stash want it as a command, and they are opened from here.
# SCRIPTDIR so the path resolves against this file rather than whatever
# directory shellcheck was run from.
git_review=$plugin_dir/bin/git-review
# shellcheck source-path=SCRIPTDIR source=../bin/git-review
source "$git_review"

# The widths and the palette, which review.tmux also has to be able to read.
# shellcheck source-path=SCRIPTDIR source=variables.sh
source "$scripts_dir/variables.sh"

# Where the time goes, when REVIEW_TRACE names a file to write it to. Off it
# costs one test per call; on it costs one append, and EPOCHREALTIME is a bash
# variable rather than a date, so tracing does not itself fork.
#
# The file is appended to, so it holds every review the server has opened.
# Each block starts at its own diff-start, which is what to measure from -- an
# offset taken from the first line of the file is the wall clock gap since the
# first review, not the cost of this one.
#
#   tmux set-environment -g REVIEW_TRACE /tmp/review.trace   then open a review
#   awk '$2=="diff-start"{t=$1; n++; printf "\n--- review %d ---\n", n}
#        {printf "%7.2fs  %s\n", $1-t, $2}' /tmp/review.trace
trace() {
  [[ -n ${REVIEW_TRACE-} ]] || return 0
  printf '%s %s\n' "$EPOCHREALTIME" "$1" >> "$REVIEW_TRACE"
  return 0
}
# This file's own path, for the pane commands and the prompts it hands to tmux.
self=$scripts_dir/${BASH_SOURCE[0]##*/}

# The pane is passed in rather than read from the current client: the binding
# expands #{pane_id} at press time, which keeps the window in the session the
# key was pressed in even when several clients are attached.
open() {
  local target=$1 cwd session came_from win_w win_h range diff_pane info
  # One call for all five: each round trip costs tens of milliseconds, and this
  # is the path the reader waits on before anything appears.
  # \x1f between the fields rather than a tab. Tab is one of the characters
  # bash treats as IFS whitespace, so `read` folds a run of them into a single
  # delimiter and an empty field simply disappears, shifting everything after
  # it one place to the left. A unit separator is not IFS whitespace, so each
  # one delimits exactly one field and an empty value stays empty.
  info=$(tmux display-message -p -t "$target" \
    '#{pane_current_path}'$'\x1f''#{session_name}'$'\x1f''#{window_id}'$'\x1f''#{window_width}'$'\x1f''#{window_height}')
  IFS=$'\x1f' read -r cwd session came_from win_w win_h <<<"$info"
  # A retarget passes the window the review was originally opened from, so that
  # q still goes back there rather than to the review it replaced.
  [[ -n ${3-} ]] && came_from=$3
  # cd rather than a subshell around the resolution: a subshell is a fork, and
  # this process does nothing after this but hand paths to tmux explicitly.
  cd "$cwd" 2>/dev/null || {
    tmux display-message -t "$target" "review: cannot reach $cwd"
    return 0
  }
  gr_resolve_range "${2-}" 2>/dev/null || {
    tmux display-message -t "$target" "review: no commits to review in $cwd"
    return 0
  }
  range=$REPLY

  # Both panes are told the layout rather than negotiating it. The list used to
  # measure its commits, publish the width, and the diff pane poll for it
  # before it could start -- a second and a half of one process waiting on
  # another. A share of the window needs no commits, so it is settled here,
  # before either exists.
  columns_for "$win_w"
  local columns=$REPLY
  # What is left for the diff once the border is taken: the width delta has to
  # render at, or its rows fold and a search cannot match across the fold.
  local diff_w=$((win_w - columns - 1))
  ((diff_w < 1)) && diff_w=0

  diff_pane=$(tmux new-window -t "$session:" -P -F '#{pane_id}' -c "$cwd" \
    -n "$range review" "$self diff $(printf '%q' "$range") $diff_w")
  # Width and height are passed rather than looked up, so the list can be on
  # screen before the sidebar asks tmux anything -- see the note in sidebar().
  # Split, focus and zoom in one invocation. Done as three calls there is a
  # window -- better than a second on a busy server -- where the diff is on
  # screen and rendering, which is the whole thing being avoided.
  # -l "$columns" is the final width, not a floor: the pane is born the size it
  # will stay, so the reveal has no resize to do and the diff's scrollback is
  # never reflowed under the row map.
  tmux split-window -hb -l "$columns" -t "$diff_pane" -c "$cwd" \
    "$self sidebar $diff_pane $(printf '%q' "$range") $win_w $win_h" ';' \
    select-pane -t '{left}' ';' resize-pane -Z -t '{left}'

  # @review marks the window for the q binding, which has to stay a pure format
  # test so that q in an ordinary copy-mode is not slowed down by a shell.
  # @review_return is where q goes back to.
  tmux set-option -w -t "$diff_pane" @review 1
  tmux set-option -w -t "$diff_pane" @review_return "$came_from"
  # Which pane holds the diff, so nav() can steer it from either side.
  tmux set-option -w -t "$diff_pane" @review_diff_pane "$diff_pane"
}

# kill-window on its own leaves the client on whichever window happens to be
# adjacent, which is rarely the one the review was opened from.
quit() {
  local target=$1 back
  back=$(tmux show-options -w -t "$target" -qv @review_return 2>/dev/null) || back=''
  # Switch and close in one invocation, so the review is never briefly the
  # current window with its panes already going away.
  if [[ -n $back ]]; then
    tmux select-window -t "$back" ';' kill-window -t "$target" 2>/dev/null ||
      tmux kill-window -t "$target"
  else
    tmux kill-window -t "$target"
  fi
  return 0
}

# The commit list itself: the same fields, in the same order, that the glog
# alias shows. Fills the caller's shas/subs/whens/authors, which every renderer
# below reads.
load_commits() {
  local sha sub when author
  while IFS=$'\x1f' read -r sha sub when author; do
    shas+=("$sha")
    subs+=("$sub")
    whens+=("$when")
    authors+=("$author")
  done < <(git log --reverse --format='%h%x1f%s%x1f%cr%x1f%an' "$1")
}

# Every commit's diffstat in one read, keyed by sha. It used to be a git show
# per frame, which on a machine where an exec costs 30ms and a git exec 80
# meant paying that on every selection change.
#
# A pass of its own rather than the tail of load_commits, because the diff pane
# is blocked until the width the list wants has been published and that is
# derived from the fields load_commits reads. Everything between the two is
# time the diff spends not rendering.
load_stats() {
  local sha='' line
  while IFS= read -r line; do
    case $line in
      '') continue ;;
      $'\x1e'*) sha=${line#?} ;;
      *) [[ -n $sha ]] && stat_of[$sha]=${line# } ;;
    esac
  done < <(git log --reverse --shortstat --format="%x1e%h" "$1")
}

# The diffstat the placeholder shows, in both a plain and a coloured form. Sets
# the caller's change_plain and change_col.
load_change_summary() {
  local line files='' ins='' del=''
  line=$(git diff --shortstat "$1") || return 0
  # Three independent matches rather than one pattern spelling all of them in
  # order. A range that only deletes has no insertions at all, and the ordered
  # form left that field empty -- which `read` then dropped, because a run of
  # spaces is one separator, so the deletions were read into ins and the list
  # showed them as additions. It costs a sed and a process substitution less.
  [[ $line =~ ([0-9]+)\ files?\ changed ]] && files=${BASH_REMATCH[1]}
  [[ $line =~ ([0-9]+)\ insertions?\(\+\) ]] && ins=${BASH_REMATCH[1]}
  [[ $line =~ ([0-9]+)\ deletions?\(-\) ]] && del=${BASH_REMATCH[1]}
  [[ -n $files ]] || return 0

  change_plain="$files file$( ((files == 1)) || printf s)"
  change_col="$dim$change_plain$reset"
  if [[ -n $ins ]]; then
    change_plain+="  +$ins"
    change_col+="  $added+$ins$reset"
  fi
  if [[ -n $del ]]; then
    change_plain+="  -$del"
    change_col+="  $removed-$del$reset"
  fi
}

# Wide enough for the longest subject, date and author it will show, but bounded
# so the diff keeps diff_min columns to read side by side in.
# A share of the window, then three clamps. Depends on nothing but the window,
# which is what lets open work it out before either pane exists.
columns_for() {
  local window=$1 need
  need=$((window * sidebar_pct / 100))
  ((need > sidebar_max)) && need=$sidebar_max
  # The pane border costs a column too, so diff_min really is a minimum.
  ((need > window - diff_min - 1)) && need=$((window - diff_min - 1))
  ((need < sidebar_min)) && need=$sidebar_min
  # REPLY rather than stdout, the way fit answers: a caller reading this
  # through $(...) pays a fork for it, and on a machine whose endpoint agent
  # inspects every exec that is a quarter of a second.
  REPLY=$need
}


diff_pane_cmd() {
  # GIT_PAGER rather than a pipe: git only emits colour when it believes a
  # pager is consuming the output, and delta with paging off writes straight
  # into the pane's scrollback where copy-mode can reach it.
  # --no-header: the sidebar already names the range and counts the commits, so
  # repeating it above the diff wastes the first two rows of the pane.
  # delta sizes its columns to the width it believes it is writing into, and
  # this pane is still the full window: the sidebar is only split off it once
  # the diff has been written. Every row then overflows the narrowed pane and
  # the terminal folds the remainder onto a line of its own -- which is what
  # broke searching. A match spanning the fold is no longer one string in the
  # scrollback, so `transcript_path` was stored as `...tra` + `nscript_path)`
  # and could not be found, and n and N stepped onto the stray fragments.
  #
  # So delta is told the width the pane will end up at. open works that out
  # from the window and hands it over as an argument: it is a share of the
  # window, not a measurement of the commits, so nothing has to be waited for.
  trace diff-start
  local diff_w=${2:-0} width_opt=''
  ((diff_w > 0)) && width_opt=" --width=$diff_w"
  # The diff is written in two goes: the head of it, and then everything else
  # behind the reader. delta turns this range into five megabytes of escapes
  # and the tmux server parses every one of them on the thread the sidebar is
  # also queueing behind, so waiting for the whole thing before showing any of
  # it is most of the wait. The first commit is about two per cent of it.
  #
  # Appending to a pane that is already in copy-mode does not move the view --
  # the reader stays where they are while the rest arrives underneath. What it
  # does do is strand #{scroll_position}, which keeps being measured against
  # the grid as it stood when copy-mode was entered: see @review_hist_base.
  local -a chunks=()
  plan_chunks "$1"
  trace "chunks-planned:${#chunks[@]}"
  local chunk first=1
  for chunk in "${chunks[@]}"; do
    # git log directly rather than through git-review, whose options are
    # sourced above: running it was a bash of its own, per chunk.
    # gr_log_opts comes from that source, which shellcheck cannot follow
    # through a path held in a variable.
    # shellcheck disable=SC2154
    GIT_PAGER="delta --paging=never$width_opt" git log "${gr_log_opts[@]}" "$chunk" || true
    trace "chunk-rendered:$chunk"
    ((first)) || continue
    first=0
    reveal_diff
    trace revealed
  done
  # Nothing arrives after this, so the sidebar can trust the scrollback: build
  # the row map, drop the placeholder, start following the reader.
  ((${#chunks[@]} > 1)) && settle_view
  trace loaded
  # The key is what wakes the list. It is throttled to a quarter of its frames
  # while the diff is arriving, so left to notice this on its own it would sit
  # on the placeholder for up to another second after there was nothing left
  # to wait for. z is not bound to anything there; it costs no round trip of
  # its own, riding the invocation that sets the flag.
  tmux set-option -w -t "$TMUX_PANE" @review_loaded 1 ';' send-keys -t '{left-of}' z
  read -r || true
  quit "$TMUX_PANE"
}

# Re-enter copy-mode on the finished grid, holding the reader where they are.
#
# Copy-mode is bounded by the grid as it stood when it was entered: everything
# appended behind the reader is in the scrollback but cannot be scrolled to,
# and history-bottom stops at the end of the first chunk. Leaving and entering
# again re-reads the grid, which is now all of it. The position is put back by
# the same two moves the sidebar uses after a yank -- goto-line for the view,
# then the cursor walked to the screen row it was on, which is at most a pane
# of moves.
settle_view() {
  local raw base scroll cy live row n
  raw=$(tmux display-message -p -t "$TMUX_PANE" \
    "$hist_base"$'\x1f''#{scroll_position}'$'\x1f''#{copy_cursor_y}'$'\x1f''#{history_size}' \
    2>/dev/null) || return 0
  IFS=$'\x1f' read -r base scroll cy live <<<"$raw"
  [[ -n $base && -n $live ]] || return 0
  row=$((base - ${scroll:-0} + ${cy:-0}))
  ((row < 0)) && row=0
  # The row goes to the top of the view rather than back to the screen row it
  # was on. Putting it back exactly needs the cursor's position after the
  # re-entry, which is another round trip and then a walk -- and this runs
  # before the list can be built, so every round trip here is the list waiting.
  # In the common case there is nothing to see: the reader is still on the
  # first commit, so row is 0 and this is where the view already was.
  n=$((live - row))
  ((n > live)) && n=$live
  ((n < 0)) && n=0
  # top-line rides along rather than costing a call of its own. Without it the
  # cursor stays where re-entering copy-mode left it -- the bottom row -- and
  # the sidebar would follow that rather than the row the reader is on.
  tmux send-keys -X -t "$TMUX_PANE" cancel ';' copy-mode -t "$TMUX_PANE" ';' \
    send-keys -X -t "$TMUX_PANE" goto-line "$n" ';' \
    send-keys -X -t "$TMUX_PANE" top-line ';' \
    set-option -p -t "$TMUX_PANE" -F @review_hist_base '#{history_size}'
  return 0
}

# The diff, split so that something is on screen before all of it is rendered.
# The head is the range's first commit on its own -- the cheapest thing that is
# still a whole commit -- and the tail is everything after it. Fills the
# caller's chunks.
#
# A range with no "..", which is what --wip and a single-commit repository
# resolve to, has nothing to split and is rendered in one go.
plan_chunks() {
  local range=$1 all head_sha
  chunks=("$range")
  [[ $range == *..* ]] || return 0
  # Asked for here rather than handed over by the list. It costs a git, but it
  # is spent in the time this pane used to spend blocked on the list for its
  # width -- and the list no longer has to be reached at all.
  #
  # Read whole rather than piped through head: under pipefail a closed pipe
  # takes the whole command down with it, and this would fall back to one
  # chunk without saying so. It is one short line per commit.
  all=$(git rev-list --reverse "$range" 2>/dev/null) || return 0
  # A single commit in the range has nothing to split, and would otherwise buy
  # an empty second chunk for a git, a delta and a settle.
  [[ $all == *$'\n'* ]] || return 0
  head_sha=${all%%$'\n'*}
  [[ -n $head_sha ]] || return 0
  chunks=("${range%%..*}..$head_sha" "$head_sha..${range##*..}")
  return 0
}

# Put the reader at the top of what has been written and hand them the pane.
# Copy-mode has to be entered before the rest of the diff arrives, or the pane
# scrolls with it and there is nothing to read; entered here, the view stays on
# the first commit however much lands behind it.
reveal_diff() {
  local -a cmd=(copy-mode -t "$TMUX_PANE" ';' send-keys -X -t "$TMUX_PANE" history-top ';')
  # Selecting a pane the zoom was hiding unzooms the window, so this both
  # restores the layout and takes the focus. It used to resize the list back to
  # the width it wanted as well; the list is now split at that width to begin
  # with, so there is nothing to put back.
  cmd+=(select-pane -t "$TMUX_PANE" ';')
  # And a key to the list, which is throttled to a quarter of its frames while
  # the diff arrives. The reveal is the moment its width becomes the real one
  # and it can draw the commits instead of the placeholder, so it is told
  # rather than left to notice on its next turn. z is bound to nothing there,
  # and it costs no round trip of its own.
  cmd+=(send-keys -t '{left-of}' z ';')
  # What #{scroll_position} is measured against from here on. tmux stops
  # counting lines appended after copy-mode was entered, so hist - scroll + cy
  # reads high by exactly the number of them -- the sidebar works from this
  # instead of the live history size.
  #
  # Taken from the scroll rather than the history size, though at the top they
  # name the same number: the scroll cannot race a line landing between
  # history-top and the read. And -F so the server evaluates it in place,
  # which is what lets the whole reveal be one round trip.
  cmd+=(set-option -p -t "$TMUX_PANE" -F @review_hist_base '#{scroll_position}')
  tmux "${cmd[@]}"
  return 0
}

# delta's file headers, as a regex over the pane text. The labels come from git
# config rather than being restated here, so this stays in step with whatever
# .gitconfig sets delta up with.
file_row_regex() {
  local -a labels=()
  local key label
  # One --get-regexp rather than five --get calls: the five cost 196ms, which
  # is time the commit list would spend not being on screen.
  while read -r key label; do
    [[ -n $label ]] && labels+=("$label")
  done < <(git config --get-regexp 'delta\.file-.*-label' 2>/dev/null || true)
  # delta's own defaults, for a checkout that does not set them.
  ((${#labels[@]})) || labels=(added: removed: renamed: copied:)
  local IFS='|'
  # delta indents the label by a column, so the anchor has to allow for it --
  # hard-anchored at zero this matched nothing at all, which left the file rows
  # empty and ][ with nowhere to go.
  printf '^[[:space:]]*(%s) ' "${labels[*]}"
}

# Everything this loop watches, in one format. Held here because the two ways
# of getting it -- pushed by the server, or asked for -- must not drift.
#
# \x1f, not a tab: outside copy-mode both scroll_position and copy_cursor_y are
# empty, and because tab counts as IFS whitespace `read` collapsed the two
# adjacent separators and shifted every field after them two places left.
# window_width was read out of window_zoomed_flag -- so the width the loop
# worked from was 1, the list asked for the narrowest layout it has, and
# build_rows was handed a negative width, which is what drew the broken frame
# while the diff was still loading. A unit separator is not IFS whitespace, so
# empty fields survive, and they survive a control-mode notification too.
# The basis #{scroll_position} is measured against, falling back to the live
# history size until one has been published.
#
# The emptiness is tested rather than the value, because #{?opt,a,b} is false
# for the string "0" exactly as it is for unset -- and every one of the four
# places that writes this option can legitimately write a zero: a diff that
# fits on screen leaves #{history_size} and #{scroll_position} both at 0. Read
# through #{?@review_hist_base,...} that zero was indistinguishable from never
# having been set, so the read fell back to the live history size. The basis
# then ran ahead of the scroll by the whole of the second chunk, and the view
# the sidebar restored -- and the cursor with it -- landed that far down: on
# the last line of the first commit rather than its first.
hist_base='#{?#{==:#{@review_hist_base},},#{history_size},#{@review_hist_base}}'

state_format='#{pane_in_mode}'$'\x1f'"$hist_base"$'\x1f''#{scroll_position}'$'\x1f''#{copy_cursor_y}'$'\x1f''#{pane_width}'$'\x1f''#{window_width}'$'\x1f''#{pane_height}'$'\x1f''#{window_zoomed_flag}'$'\x1f''#{pane_active}'$'\x1f''#{!=:#{pane_search_string},}'$'\x1f''#{@review_loaded}'$'\x1f''#{history_size}'

# A control-mode client, subscribed to that format. tmux pushes the value every
# time it changes, so the loop stops asking: it used to spend a round trip on
# every turn, four times a second, for as long as a review was open -- against
# a server that is at the same time parsing megabytes of delta output, on a
# machine where a round trip is a third of a second.
#
# -f no-output because we want notifications, not the pane's output. A control
# client is not counted as attached and does not take part in sizing the
# window, which is the thing that would otherwise make this unusable: tmux
# sizes a window to its smallest client.
#
# Answers false if the client cannot be started, and the loop polls instead.
# Fills tick with the current state: drained from the subscription when one is
# up, asked for when it is not. Answers false only when the pane has gone, which
# is the loop's signal to stop.
#
# Drained rather than read: the server pushes at most once a second, so a turn
# with nothing waiting is the normal case and must not block. Whatever arrived
# since the last turn is taken, and the last line wins -- the earlier ones are
# states already superseded.
read_state() {
  local pane=$1 line got=0
  if ((sub_out < 0)); then
    tick=$(tmux display-message -p -t "$pane" "$state_format" 2>/dev/null) || return 1
    return 0
  fi
  while IFS= read -r -t 0.02 -u "$sub_out" line; do
    case $line in
      '%subscription-changed rv '*)
        tick=${line#*" : "}
        got=1
        ;;
      # The client has gone: fall back to asking, rather than going blind.
      '%exit'*)
        sub_out=-1
        tick=$(tmux display-message -p -t "$pane" "$state_format" 2>/dev/null) || return 1
        return 0
        ;;
    esac
  done
  # Nothing new means nothing changed, so the values from last turn still hold.
  ((got)) || return 0
  return 0
}

start_subscription() {
  local pane=$1 session=$2
  coproc SUB { exec tmux -C attach-session -f no-output -t "$session" 2>/dev/null; } || return 1
  sub_out=${SUB[0]}
  sub_in=${SUB[1]}
  # SUB_PID is bash's, named for the coproc; shellcheck reads it as a typo.
  # shellcheck disable=SC2153
  sub_pid=$SUB_PID
  # 1>&, spelled out: with the fd in a variable the bare >& form reads as a
  # stderr redirection to anything parsing this.
  printf 'refresh-client -B "rv:%s:%s"\n' "$pane" "$state_format" 1>&"$sub_in" || return 1
  return 0
}

sidebar() {
  local pane=$1 range=$2 win_w=${3:-0} win_h=${4:-0}
  # Initialised, not just declared: bash leaves a declared-but-unassigned array
  # unset, so ${#shas[@]} on a range with no commits is an unbound variable and
  # set -u takes the sidebar down -- on exactly the path that exists to say
  # there is nothing to review.
  local -a shas=() subs=() whens=() authors=() rows_plain=() rows_col=()
  # Declared before load_commits fills it, and declared associative: bash reads
  # an undeclared name's subscript as arithmetic, so a sha would be taken for a
  # variable and set -u would object to it.
  local -A stat_of=()
  trace sidebar-start
  load_commits "$range"
  trace sidebar-commits-loaded
  ((${#shas[@]})) || { printf '%s  nothing to review%s\n' "$dim" "$reset"; read -r; return; }

  # The pane is a display, not a prompt. read -s only suppresses echo while it
  # is actually reading, so a key pressed while this loop was rendering or
  # waiting on tmux got echoed into the list by the terminal itself -- and the
  # cursor it left behind marks nothing worth pointing at.
  stty -echo 2>/dev/null || true
  printf '\e[?25l'
  # The control client is a process of ours and has to go with us; left behind
  # it would sit attached to the session for good.
  trap 'stty echo 2>/dev/null; printf "\e[?25h"; [[ -n ${sub_pid:-} ]] && kill "$sub_pid" 2>/dev/null; true' EXIT INT TERM

  # Filled in below, after the first frame is up, so the shortstat's 170ms is
  # never on the path to something appearing.
  local change_plain='' change_col=''
  local -A row_of=()
  # Parallel: the scrollback row each file header sits on, and its path. Used to
  # say which file a comment is against.
  local -a file_rows=() file_names=()
  local mapped=0 width=0 height=0 diff_width=0 shown=-2
  # Where the reader was, and whether the diff has ever been in copy-mode, so a
  # cancelled copy can be undone -- see the restore below.
  local last_pos=-1 last_scroll=0 last_cy=0 seen_mode=0
  local window_seen=0 want_sha=0 want_subject=0 want_date=0 want_author=0 spin=0
  local rule_dashes=''
  local needs_clear=0 shown_focus='' shown_searching=-1
  local picking=0 pick_cur=0 pick_shown=-1 pick_mode=range
  local on_range=0 shown_range=-1
  # The session a comment would be sent to, and how the row is drawn. Restored
  # from the window so it survives a retarget, which replaces this process.
  local on_session=0 shown_session=-1
  local agent_pane_cur='' agent_label_cur='' agent_glyph_cur='󰚩'
  # Whether the agent on the row was guessed rather than chosen, and whether
  # the guess has been attempted yet. Both belong to the review, not the
  # process, so the first is restored from the window like the rest.
  local agent_guessed=0 preselect_done=0
  # The row a keypress has already drawn and is waiting for the pane to
  # confirm, and how many turns it has been waiting.
  local expect_row=-1 expect_turns=0
  # Where the keys have asked the diff to go, still to be sent.
  local pending_row=-1
  local -a agent_pane=() agent_label=() agent_kind=() agent_state=() agent_cwd=()
  local -a agent_session=()
  local comments=0 shown_comments=-1
  local -a pick_kind=() pick_label=() pick_extra=() pick_payload=()
  local win
  # Nothing is published here any more. The width the diff pane renders at is
  # a share of the window, so open settles it before either pane exists and
  # hands it to both -- there is no measurement here for the diff pane to wait
  # on, and no round trip spent telling it.
  #
  # The agent comes back with the window id: a retarget builds a new sidebar
  # for the same window, and the choice belongs to the review, not the process.
  local session=''
  win=$(tmux display-message -p -t "$pane" \
    '#{window_id}'$'\x1f''#{@review_agent_pane}'$'\x1f''#{@review_agent_label}'$'\x1f''#{session_name}'$'\x1f''#{@review_agent_guessed}')
  IFS=$'\x1f' read -r win agent_pane_cur agent_label_cur session agent_guessed <<<"$win"
  agent_guessed=${agent_guessed:-0}
  # A review that already has an agent has nothing to guess.
  [[ -z $agent_pane_cur ]] || preselect_done=1
  # The toplevel rather than this pane's directory, so a review opened from a
  # subdirectory finds the queue left by one opened from the root. One git, once,
  # when the review opens -- next to the log load_commits has already run, and
  # nowhere near a frame.
  local store repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || repo_root=$PWD
  store=$(comment_file "$repo_root" "$range")
  # Non-zero here means comments survived an earlier review of this range: the
  # sidebar's agent row shows the count, which is how they announce themselves.
  comments=$(comment_count "$store")
  # -1 until the first tick has seen which pane has the focus.
  local was_active=-1
  # Set once the diff pane has said it is done, so the throttle below applies
  # only while it is not.
  local loaded_seen=0
  # The subscription, and where the state read out of it lands. -1 until one is
  # up, which is also what read_state falls back to asking on.
  local tick='' sub_out=-1 sub_in=-1 sub_pid=''
  local pub_commits='' pub_files='' pub_stops='' i

  # Paint before touching tmux. While delta is writing its thousands of lines
  # the server has a queue, and the first display-message from here used to wait
  # seconds behind it -- seconds of blank pane. The placeholder needs nothing
  # from tmux: the geometry came in as arguments and the commit count from the
  # log just read, so the first frame costs one git log and no round trip.
  if ((win_w > 0 && win_h > 0)); then
    render_loading "$win_w" "$win_h" 0
  fi

  # Behind the first frame: the loop can poll until this is up, and it costs a
  # process to start.
  if [[ -n $session ]] && start_subscription "$pane" "$session"; then
    trace subscribed
  else
    sub_out=-1
  fi

  # All three are behind the first frame and behind the width the diff waits
  # on, which is the only ordering that matters here.
  load_stats "$range"

  local file_re
  file_re=$(file_row_regex)

  load_change_summary "$range"

  while :; do
    # While the diff is still arriving, the only thing this loop needs from
    # tmux is whether it has finished. Asking four times a second costs four
    # round trips a second on a server that is at the same time parsing
    # megabytes of delta output -- and on a machine with an endpoint security
    # agent inspecting every exec, a round trip is a third of a second. So the
    # spinner is animated from what is already known and tmux is asked only
    # every fourth frame. Not before the first tick, which is what establishes
    # the geometry the placeholder is drawn at.
    # The throttle is only worth anything while the state is being asked for.
    # Subscribed, a turn that finds nothing waiting costs nothing at all.
    if ((sub_out < 0 && width > 0 && !loaded_seen && spin % 4 != 0)); then
      hold_placeholder
      continue
    fi

    local in_mode hist live scroll cy dw ww dh zoomed diff_active searching pos loaded
    read_state "$pane" || return 0
    IFS=$'\x1f' read -r in_mode hist scroll cy dw ww dh zoomed diff_active searching loaded live <<<"$tick"
    # Not the live history size. tmux stops counting lines appended after
    # copy-mode was entered, so while the tail of the diff is still arriving
    # #{history_size} runs ahead of the grid #{scroll_position} is measured
    # against, by exactly the number of those lines. The diff pane publishes
    # what the basis actually is; every row sum below, and everything steer
    # and jump do with it, works from that.
    loaded=${loaded:-0}
    ((loaded)) && loaded_seen=1

    # Focus just moved off the diff and onto this list. Park the diff cursor at
    # the top of its view, so that a jump driven from here lands its file or
    # commit at the top of the pane instead of wherever the cursor was left
    # mid-read -- top-line takes it to column 0 of that row as well, and leaves
    # the view itself alone. cy is corrected here too, or this tick would render
    # from a position that has just stopped being true.
    if ((was_active == 1 && !diff_active)) && [[ $in_mode == 1 ]]; then
      tmux send-keys -X -t "$pane" top-line
      cy=0
    fi
    was_active=$diff_active
    # Which scrollback row the copy cursor is on: the top of the view is
    # history_size - scroll_position, and copy_cursor_y is the offset into it.
    # copy_cursor_y, not cursor_y -- cursor_y is the shell's own cursor, which
    # sits wherever the prompt was left and does not move when the reader
    # scrolls. Outside copy-mode there is no position at all, and -1 stands for
    # "not scrolling, so the pane is showing its bottom".
    if [[ $in_mode == 1 ]]; then
      pos=$((hist - scroll + cy))
      # Both halves of where the reader is: which scrollback row, and which
      # screen row it is showing on. Restoring the row alone would put it back
      # on screen somewhere else, which reads as the diff having jumped.
      last_pos=$pos
      last_scroll=$scroll
      last_cy=$cy
      seen_mode=1
    else
      pos=-1
    fi

    # Every one of tmux-yank's copy bindings ends in -and-cancel, and a review
    # diff that has left copy-mode is inert: the jump keys are all guarded on
    # the mode, and this loop follows the reader through copy_cursor_y. Copying
    # used to end the review outright.
    #
    # Putting the mode back here rather than rebinding the copy keys, because
    # the keys are not reliably ours to hold: tpm loads tmux-yank with run-shell
    # from the foot of .tmux.conf, so a binding set after it can still be
    # overwritten once the plugin catches up. This covers every route out of
    # copy-mode -- y, Enter, the mouse drag, and the ones no override lists.
    #
    # Only once the diff has been in copy-mode at least once: before that it is
    # still rendering, and copy-mode is entered by diff_pane_cmd when it is done.
    if ((seen_mode && in_mode == 0 && last_pos >= 0)); then
      # Entering copy-mode afresh re-bases #{scroll_position} on the grid as
      # it stands now, so the basis becomes the live size -- not $hist, which
      # is the basis the previous entry was working from.
      tmux set-option -p -t "$pane" @review_hist_base "$live" ';' copy-mode -t "$pane"
      # goto-line sets scroll_position and leaves copy_cursor_y where it is, so
      # the view goes back first and the cursor is then walked to the screen row
      # it was on -- inside the view, so neither move scrolls it again.
      local cy0
      cy0=$(tmux display-message -p -t "$pane" '#{copy_cursor_y}' 2>/dev/null) || return 0
      tmux send-keys -X -t "$pane" goto-line "$last_scroll"
      if ((last_cy > cy0)); then
        tmux send-keys -X -N $((last_cy - cy0)) -t "$pane" cursor-down
      elif ((last_cy < cy0)); then
        tmux send-keys -X -N $((cy0 - last_cy)) -t "$pane" cursor-up
      fi
      continue
    fi

    # While the diff is still rendering this pane is zoomed over the whole
    # window, so its width is the window's -- the usual subtraction describes a
    # layout that is not on screen yet.
    local w=$((ww - dw - 1))
    ((zoomed)) && w=$ww
    if ((w != width || dh != height)); then
      width=$w
      height=$dh
      build_rows "$width"
      # A frame drawn at the old width may have wrapped at the new one, and a
      # wrapped row occupies two that per-row erases never reach. Cleared as
      # part of the next frame rather than on its own, or the pane goes blank
      # for however long that frame takes to arrive.
      needs_clear=1
      shown=-2
    fi

    # The width is claimed before anything else, and before the diff has
    # finished. It is a share of the window now, so it needs no measurement of
    # the commits and there is nothing to wait for -- and settling the geometry
    # while the diff is still arriving means the map below is built once,
    # against a pane that has stopped moving. Claiming it resizes this pane,
    # which resizes the diff, which reflows its scrollback and moves every row.
    if ! claim_width "$pane" "$ww" "$w"; then
      continue
    fi

    # Still loading. The zoom used to stand for this, but the diff pane now
    # drops the zoom as soon as its first commit is down -- the reader is
    # already reading while the rest arrives -- so the diff pane says when it
    # is done instead. Everything below here is either pointless or actively
    # wasteful until then: the row map would be rebuilt from a scrollback that
    # is still growing, once a tick over thousands of lines, which is what
    # starved this loop of the time to draw anything at all.
    # Once the reader has the list, and only then: it costs a round trip to
    # ask the server what is running, and nobody is waiting on the answer.
    ((preselect_done || !loaded_seen)) || preselect_agent "$win" "$session"

    if ((!loaded)); then
      # While the pane is zoomed the list would be drawn at the full window
      # width and reflow the moment the zoom came off, which is the flicker the
      # placeholder exists to avoid. Once the diff pane has revealed itself the
      # width is the real one and the list can go up -- its rows are known from
      # the first tick; it is only the highlight that waits for the map.
      if ((zoomed || ${#shas[@]} == 0 || width < 1 || height < 1)); then
        hold_placeholder
      else
        hold_list
      fi
      continue
    fi

    # Resizing the diff makes tmux reflow its scrollback, which moves every row.
    if ((dw != diff_width)); then
      diff_width=$dw
      row_of=()
      mapped=0
    fi
    ((mapped)) || { trace map-rows-start; map_rows "$pane"; trace map-rows-done; }

    # The map is built in a single pass once the diff is complete, and that
    # pass costs about a second on a large one. The placeholder stays up for it
    # rather than the pane going blank, or a list appearing whose highlight has
    # nothing to point at yet.
    if ((${#row_of[@]} == 0)); then
      hold_placeholder
      continue
    fi

    # Where the reader is as far as the keys are concerned: the row reported by
    # the pane, unless something has been asked for since and not yet arrived
    # there. Everything the keys do is measured from this rather than from the
    # report, so no keypress is lost while the pane catches up.
    local at_row=$pos
    ((expect_row >= 0)) && at_row=$expect_row
    ((pending_row >= 0)) && at_row=$pending_row

    local cur settled=1
    current_index "$at_row"
    cur=$REPLY

    # A move this loop drew but the server has not reported yet. Its state
    # still describes where the reader was, so the highlight is left where it
    # was painted until the two agree. Given up on after a couple of seconds,
    # because place clamps at the ends of the history and the position it
    # lands on there is not the one it was asked for.
    # A move the keys have asked for but that has not gone out yet: the state
    # describes where the reader was, not where the list has already drawn.
    ((pending_row >= 0)) && settled=0
    if ((expect_row >= 0)); then
      if ((pos == expect_row)); then
        expect_row=-1
        expect_turns=0
      elif ((expect_turns < 8)); then
        expect_turns=$((expect_turns + 1))
        settled=0
      else
        expect_row=-1
        expect_turns=0
      fi
    fi

    if ((picking)); then
      if ((pick_shown != pick_cur)); then
        render_picker "$width" "$height" "$pick_cur"
        pick_shown=$pick_cur
      fi
      pick_keys "$pane" "$win"
      continue
    fi

    local focus=diff
    ((diff_active)) || focus=list
    if ((settled)) && { ((cur != shown || on_range != shown_range ||
      searching != shown_searching || on_session != shown_session ||
      comments != shown_comments)) || [[ $focus != "$shown_focus" ]]; }; then
      render "$cur" "$width" "$height" "$focus" "$on_range" "$searching" "$on_session"
      shown=$cur
      shown_focus=$focus
      shown_range=$on_range
      shown_searching=$searching
      shown_session=$on_session
      shown_comments=$comments
    fi

    # read is the tick delay as well as the key reader, so making the list
    # navigable costs the loop nothing extra. The keys steer the diff pane
    # rather than tracking a selection of their own: moving its cursor is what
    # moves this highlight, so there is only ever one idea of where the reader
    # is.
    # The read is the tick's delay as well as its key reader, so making the list
    # navigable costs the loop nothing extra.
    local key
    if ! read_key; then
      # A quarter of a second with no keypress: the reader has stopped, so the
      # diff goes to wherever the keys left the highlight. Once, not once per
      # key -- which is what had it crawling several commits behind.
      flush_pending "$pane"
      continue
    fi
    key=$REPLY
    [[ -n $key ]] || continue

    # Anything that is not another movement needs the pane where the list says
    # it is: c reads the diff cursor to work out what is being commented on.
    case $key in
      j | k | n | N | ']' | '[' | '}' | '{' | first | last | page_up | page_down) ;;
      *) flush_pending "$pane" ;;
    esac

    if [[ $key == q ]]; then
      quit "${TMUX_PANE:-$pane}"
      return 0
    fi

    # Enter opens whichever of the two header rows is selected: the range names
    # what is being reviewed, so it offers the other things to review, and the
    # row below it names where a comment would go, so it offers the other
    # agents to send to. Nowhere else does enter mean anything.
    if [[ $key == enter ]]; then
      if ((on_range)); then
        pick_mode=range
        load_pick_items "$range"
        pick_seek 0 1
        pick_cur=$REPLY
        pick_shown=-1
        picking=1
      elif ((on_session)); then
        pick_mode=session
        load_pick_sessions "$win"
        pick_seek 0 1
        pick_cur=$REPLY
        pick_shown=-1
        picking=1
      fi
      continue
    fi

    # c comments on whatever the diff cursor is sitting on -- or on the visual
    # selection, if one is up -- and s hands the queue to the chosen agent.
    # Both are routed here from the diff pane, so they answer from either side.
    # a opens the agent picker wherever the selection happens to be. The row
    # can be reached by walking up to it, but a menu entry cannot rely on the
    # cursor being anywhere in particular, so this is the way in that does not
    # care.
    if [[ $key == a ]]; then
      on_range=0
      on_session=1
      pick_mode=session
      load_pick_sessions "$win"
      pick_seek 0 1
      pick_cur=$REPLY
      pick_shown=-1
      picking=1
      continue
    fi

    if [[ $key == c ]]; then
      add_comment "$pane" "$store"
      continue
    fi
    if [[ $key == s ]]; then
      send_comments "$win" "$store" "$range"
      continue
    fi

    # Nothing to steer if the diff pane is not scrolling; put it back into
    # copy-mode and let the next tick supply a usable position.
    if [[ $in_mode != 1 ]]; then
      tmux set-option -p -t "$pane" @review_hist_base "$live" ';' copy-mode -t "$pane"
      continue
    fi
    steer "$pane" "$key" "$cur" "$hist" "$scroll" "$cy"
  done
}

# Keys while the picker is up. Leaves picking set to 0 once it is done, either
# because something was chosen or because it was dismissed.
pick_keys() {
  local pane=$1 win=$2 key
  read_key || return 0
  key=$REPLY
  [[ -n $key ]] || return 0

  case $key in
    j | page_down) pick_seek $((pick_cur + 1)) 1; pick_cur=$REPLY ;;
    k | page_up) pick_seek $((pick_cur - 1)) -1; pick_cur=$REPLY ;;
    first) pick_seek 0 1; pick_cur=$REPLY ;;
    last) pick_seek $((${#pick_kind[@]} - 1)) -1; pick_cur=$REPLY ;;
    cancel | q)
      picking=0
      shown=-2
      needs_clear=1
      ;;
    enter)
      picking=0
      shown=-2
      needs_clear=1
      if [[ $pick_mode == session ]]; then
        apply_pick_session "$win" "$pick_cur"
      else
        apply_pick "$pane" "$win" "$pick_cur"
      fi
      ;;
  esac
}

# The commit being read: the one whose header is the last at or above the
# cursor. Absent a position -- the reader left copy-mode -- the pane is showing
# its bottom, which is the newest commit.
# Answers in REPLY, for the same reason as read_key: this ran once a tick.
current_index() {
  local pos=$1 i cur=$((${#shas[@]} - 1))
  if ((pos >= 0 && ${#row_of[@]} > 0)); then
    cur=0
    for i in "${!shas[@]}"; do
      # The map can still be partial, so a commit without a row is skipped
      # rather than treated as row zero.
      [[ -v row_of[${shas[i]}] ]] || continue
      ((row_of[${shas[i]}] <= pos)) && cur=$i
    done
  fi
  REPLY=$cur
  return 0
}

# One keypress, resolved to a name this script acts on, or empty for anything
# it does not. Answers false when the read timed out, which is the tick.
# Answers in REPLY. Read through $(...) this forked once a tick, whether or
# not a key was pressed -- the loop's own heartbeat cost a process, which on a
# machine whose endpoint agent inspects every exec is a quarter of a second
# between the reader pressing j and anything moving.
read_key() {
  local key seq c
  REPLY=''
  IFS= read -rsn1 -t 0.25 key || return 1

  case $key in
    # read strips the delimiter, so a newline arrives as an empty string that
    # still read successfully -- which is how Enter is told from the tick.
    '' | $'\r') key=enter ;;
    $'\e')
      # Arrows and page keys are escape sequences: ESC [ A, ESC [ 6 ~ and so on.
      # Read to the terminating letter or tilde with a short timeout of its own,
      # so a bare Escape does not stall the loop. CSI is ESC [, but Home and End
      # often arrive as SS3 -- ESC O F -- so both introducers are accepted.
      seq=''
      if IFS= read -rsn1 -t 0.05 c && [[ $c == '[' || $c == O ]]; then
        while IFS= read -rsn1 -t 0.05 c; do
          seq+=$c
          [[ $c == [A-Z~] ]] && break
        done
      fi
      # Home and End are 1~ and 4~ here, not the H and F that xterm sends;
      # both spellings are accepted rather than assumed.
      case $seq in
        A) key=k ;;
        B) key=j ;;
        '5~') key=page_up ;;
        '6~') key=page_down ;;
        '1~' | H) key=first ;;
        '4~' | F) key=last ;;
        # A bare Escape: nothing followed the introducer.
        '') key=cancel ;;
        *) key='' ;;
      esac
      ;;
    g)
      # gg, the vi way to the top. A lone g does nothing.
      IFS= read -rsn1 -t 0.4 c || c=''
      if [[ $c == g ]]; then key=first; else key=''; fi
      ;;
    G) key=last ;;
    j | k | n | N | ']' | '[' | '}' | '{' | q | c | s | a) ;;
    *) key='' ;;
  esac
  REPLY=$key
  return 0
}

# Moves the diff pane in answer to a key. The keys steer that pane rather than
# tracking a selection of their own: moving its cursor is what moves the
# highlight, so there is only ever one idea of where the reader is.
steer() {
  local pane=$1 key=$2 cur=$3 hist=$4 scroll=$5 cy=$6 page=$((height - 8))
  # Same reason as render's: the two selection flags belong to the loop, and
  # default so this can be driven directly.
  : "${on_range:=0}" "${on_session:=0}"
  ((page < 1)) && page=1

  # The range line sits above the first commit. Moving up off that commit
  # selects it, moving down goes back, and anything else leaves it -- so enter
  # only ever offers the picker when the range is what is highlighted.
  if ((on_range)); then
    case $key in
      # Nothing sits above the range line, so every list movement from it is a
      # no-op rather than a jump to somewhere it was not asked to go.
      k | first | last | page_up | page_down) return 0 ;;
      j)
        on_range=0
        on_session=1
        return 0
        ;;
      *) on_range=0 ;;
    esac
  elif ((on_session)); then
    case $key in
      # gg and G address the commit list, and the two rows above it are not part
      # of it -- landing on its first or last entry from here would be a jump
      # nobody asked for.
      first | last | page_up | page_down) return 0 ;;
      k)
        on_session=0
        on_range=1
        return 0
        ;;
      j)
        on_session=0
        select_index 0
        return 0
        ;;
      *) on_session=0 ;;
    esac
  elif [[ $key == k ]] && ((cur == 0)); then
    on_session=1
    return 0
  fi

  # The row lists are unquoted on purpose: jump takes them as trailing
  # arguments, which is what keeps the escaping out of the tmux bindings.
  # shellcheck disable=SC2086
  case $key in
    j) jump "$pane" next "$hist" "$scroll" "$cy" $pub_commits ;;
    k) jump "$pane" prev "$hist" "$scroll" "$cy" $pub_commits ;;
    n) jump "$pane" next "$hist" "$scroll" "$cy" $pub_stops ;;
    N) jump "$pane" prev "$hist" "$scroll" "$cy" $pub_stops ;;
    ']') jump "$pane" next "$hist" "$scroll" "$cy" $pub_files ;;
    '[') jump "$pane" prev "$hist" "$scroll" "$cy" $pub_files ;;
    '}') jump "$pane" next "$hist" "$scroll" "$cy" $pub_commits ;;
    '{') jump "$pane" prev "$hist" "$scroll" "$cy" $pub_commits ;;
    first) select_index 0 ;;
    last) select_index $((${#shas[@]} - 1)) ;;
    page_up) select_index $((cur - page)) ;;
    page_down) select_index $((cur + page)) ;;
  esac
}

# One row per pane, because jk means a different thing in each: in the diff it
# is copy-mode's own line movement, in the list it steps a commit. Longest form
# first; render_legend takes the longest that fits. Laid out the way lazygit's
# and gitui's bottom bars are -- the key, then what it stops at, groups spaced
# apart, alternatives joined with a slash. n/N, ][ and q answer in either pane;
# they are listed where they get used.
#
# keys=label, groups separated by a pipe. The boundary is explicit because a
# group's keys can themselves contain spaces.
# Both are read by render_legend through a nameref, which shellcheck cannot
# follow.
# shellcheck disable=SC2034
legend_diff_tiers=(
  'jk=line|n/N=any|][=file|}{=commit|c=comment|s=send'
  'jk=line|n/N=any|}{=commit|c=comment'
  'n/N=any|}{=commit|c=comment'
  'n/N=any|c=comment'
)
# shellcheck disable=SC2034
legend_list_tiers=(
  'jk=commit|PgUp/PgDn=page|gg/G=first/last|a=agent|c=comment|s=send|q=close'
  'jk=commit|PgUp/PgDn=page|c=comment|s=send|q=close'
  'jk=commit|c=comment|q=close'
  'jk=commit|q=close'
)
# Once / or ? has been used the diff's own stops step aside: n and N follow the
# match, as they do in vim and in less. Files and commits keep ][ and }{, so
# nothing is lost by searching. See the binding in .tmux.conf.
# shellcheck disable=SC2034
legend_diff_search_tiers=(
  'jk=line|n/N=match|][=file|}{=commit|c=comment|s=send'
  'jk=line|n/N=match|}{=commit|c=comment'
  'n/N=match|}{=commit|c=comment'
  'n/N=match|c=comment'
)
# Shown only while the range line itself is selected, which is the one place
# enter does anything.
# shellcheck disable=SC2034
legend_range_tiers=(
  'enter=pick|j=agent|q=close'
  'enter=pick|j=agent'
  'enter=pick'
)
# Shown while the agent row is selected. enter picks which agent, and the two
# comment keys are listed here because this is the row that says where they go.
# shellcheck disable=SC2034
legend_session_tiers=(
  'enter=agent|c=comment|s=send|k=range|j=list|q=close'
  'enter=agent|c=comment|s=send|q=close'
  'enter=agent|c=comment|s=send'
  'enter=agent|c=comment'
)

render_legend() {
  local width=$1 prefix=$2 tier group keys label plain col
  local -n tiers=$3
  for tier in "${tiers[@]}"; do
    plain="$prefix"
    col="$dim$prefix$reset"
    while IFS= read -r group; do
      keys=${group%%=*}
      label=${group#*=}
      plain+="  $keys $label"
      col+="  $c_subject$keys$reset $dim$label$reset"
    done < <(printf '%s\n' "${tier//|/$'\n'}")
    ((${#plain} <= width - 1)) && break
  done

  # Even the shortest form can be too wide for a very narrow pane -- tmux will
  # crush one to a couple of columns given the chance -- and a legend that wraps
  # costs a row. Cut the plain text rather than the coloured one: truncating a
  # string with escapes in it slices them in half.
  if ((${#plain} > width - 1)); then
    fit "$plain" $((width - 1))
    # shellcheck disable=SC2034
    REPLY_PLAIN=$REPLY
    REPLY="$dim$REPLY$reset"
    return
  fi
  # The uncoloured form as well, so a caller that needs the width does not have
  # to parse the escapes back out of it. Read by the tests, not from here.
  # shellcheck disable=SC2034
  REPLY_PLAIN=$plain
  REPLY=$col
}

# Pads and truncates to a fixed column width, answering in REPLY. Bash counts
# and slices strings by character, so this is multibyte-safe -- printf '%-*s'
# is not, and would misalign every row after an ellipsis or an accented name.
# REPLY rather than stdout keeps it free of a subshell per field, which at three
# fields a row is the difference between a paint and a noticeable pause.
# The columns a string occupies, answered in REPLY. Nerd-font glyphs live in
# the private use areas and render two cells wide, but bash counts each as one
# character -- so a row measured with ${#s} comes out narrower than it draws,
# overflows the pane and folds its tail onto a line of its own.
dwidth() {
  local s=$1 n=${#1} i c cp
  # All ASCII, so the character count is the column count. Every commit row
  # takes this path, which is why it comes before any per-character work.
  if [[ $s != *[![:ascii:]]* ]]; then
    REPLY=$n
    return 0
  fi
  REPLY=0
  for ((i = 0; i < n; i++)); do
    c=${s:i:1}
    printf -v cp '%d' "'$c"
    if ((cp >= 0xE000 && cp <= 0xF8FF)) || ((cp >= 0xF0000 && cp <= 0x10FFFD)); then
      REPLY=$((REPLY + 2))
    else
      REPLY=$((REPLY + 1))
    fi
  done
  return 0
}

fit() {
  local text=$1 w=$2 n pad
  if ((w <= 0)); then
    REPLY=''
    return
  fi
  dwidth "$text"
  n=$REPLY
  if ((n > w)); then
    if [[ $text != *[![:ascii:]]* ]]; then
      text=${text:0:$((w - 1))}
      while [[ $text == *' ' ]]; do text=${text% }; done
      n=$((${#text} + 1))
      text+='…'
    else
      # Cut by column rather than by character: a glyph is one character and
      # two columns, so a character-indexed slice leaves the row too wide.
      local i c out='' acc=0
      for ((i = 0; i < ${#text}; i++)); do
        c=${text:i:1}
        dwidth "$c"
        ((acc + REPLY > w - 1)) && break
        out+=$c
        acc=$((acc + REPLY))
      done
      while [[ $out == *' ' ]]; do
        out=${out% }
        acc=$((acc - 1))
      done
      text="${out}…"
      n=$((acc + 1))
    fi
  fi
  pad=$((w - n))
  ((pad > 0)) && printf -v text '%s%*s' "$text" "$pad" ''
  REPLY=$text
}

# One row per commit, laid out in fixed columns so the date and author line up
# down the list.
# The widest each column has to be. Depends on the commits alone, not on the
# pane, which is what lets the width be published before the first frame is
# drawn -- and the diff pane is waiting on exactly that.
measure_rows() {
  local i
  want_sha=0
  want_subject=0
  want_date=0
  want_author=0
  for i in "${!shas[@]}"; do
    # Measured, not assumed. git abbreviates to whatever is unique in the
    # repository: 7 in a small one, 9 or more in a large one. Fixed at 7, every
    # row in a large repository came out two columns over the pane width and
    # the tail of the author field folded onto a line of its own.
    dwidth "${shas[i]}"
    ((REPLY > want_sha)) && want_sha=$REPLY
    dwidth "${subs[i]}"
    ((REPLY > want_subject)) && want_subject=$REPLY
    dwidth "(${whens[i]})"
    ((REPLY > want_date)) && want_date=$REPLY
    dwidth "<${authors[i]}>"
    ((REPLY > want_author)) && want_author=$REPLY
  done
  return 0
}

build_rows() {
  local width=$1 i dw aw sw sha subject when author
  # The horizontal rule, built here rather than in the renderers: it only
  # changes with the width, and a printf piped through tr on every frame is an
  # exec every frame.
  rule_dashes=''
  for ((i = 0; i < width - 2; i++)); do rule_dashes+='─'; done
  measure_rows
  dw=$want_date
  aw=$want_author

  # " sha  subject  (date) <author>" is the sha plus six columns of leading
  # space and separators. The subject takes whatever is left, so a wider pane
  # shows more of it.
  local fixed=$((6 + want_sha))
  sw=$((width - fixed - dw - aw))
  # Too narrow for any useful subject: take it out of the author, which is the
  # field the reader can most easily do without.
  if ((sw < 12)); then
    aw=$((width - fixed - dw - 12))
    ((aw < 6)) && aw=6
    sw=$((width - fixed - dw - aw))
    ((sw < 4)) && sw=4
  fi

  rows_plain=()
  rows_col=()
  for i in "${!shas[@]}"; do
    # Padded to the widest, so a repository that abbreviates unevenly still
    # lines its columns up.
    fit "${shas[i]}" "$want_sha" && sha=$REPLY
    fit "${subs[i]}" "$sw" && subject=$REPLY
    fit "(${whens[i]})" "$dw" && when=$REPLY
    fit "<${authors[i]}>" "$aw" && author=$REPLY
    rows_plain+=(" $sha  $subject  $when $author")
    rows_col+=(" $c_sha$sha$reset  $c_subject$subject$reset  $c_date$when$reset $c_author$author$reset")
  done
}

# Shown, centred, while the diff renders. The list is deliberately not drawn
# yet: it would appear at the full width of the zoomed pane and then reflow to
# its real width the moment the zoom came off, which is the flicker this
# replaces. Frames are the spinner's, and  is the git glyph repo-icon.sh
# already uses -- both measured against the font.
loading_frames=(⣾ ⣽ ⣻ ⢿ ⡿ ⣟ ⣯ ⣷)

render_loading() {
  local width=$1 height=$2 frame=$3 i out='' pad padding
  local -a plain=() col=()
  local spinner=${loading_frames[frame % ${#loading_frames[@]}]}

  # Plain and coloured are built side by side rather than the coloured one being
  # parsed back: an SGR escape ends at the first m after the introducer, and
  # looking for that m in the whole string finds the one in "commits".
  plain+=("$spinner  $range")
  col+=("$accent$spinner$reset  $c_subject$range$reset")
  plain+=('')
  col+=('')
  # Two spaces after the glyph, which takes two cells of its own.
  plain+=("  ${#shas[@]} commit$( ((${#shas[@]} == 1)) || printf s)")
  col+=("${c_git}$reset  $c_subject${#shas[@]}$reset $dim""commit$( ((${#shas[@]} == 1)) || printf s)$reset")
  if [[ -n $change_plain ]]; then
    plain[-1]+="    $change_plain"
    col[-1]+="    $change_col"
  fi

  out+=$'\e[H\e[2J'
  needs_clear=0
  for ((i = 0; i < (height - ${#plain[@]}) / 2; i++)); do
    out+=$'\n'
  done
  for i in "${!plain[@]}"; do
    # By column, not by character: the git glyph in the row above counts once
    # for bash and twice on screen, so centring on ${#} sits it off to the left.
    dwidth "${plain[i]}"
    pad=$(((width - REPLY) / 2))
    ((pad < 0)) && pad=0
    padding=''
    ((pad > 0)) && printf -v padding '%*s' "$pad" ''
    out+="$padding${col[i]}"$'\e[K\n'
  done
  printf '%s' "$out"
}

# Locates every commit and file header in the diff pane's scrollback and
# publishes the three row lists the jump keys read. Fills the caller's row_of
# and sets mapped once every commit has been found.
#
# The diff is written once and never changes, so this runs once -- but not
# before delta has finished, or it would be re-run every tick over a scrollback
# that is still growing.
# The scrollback rows a comment is about: the visual selection if one is up,
# otherwise the single row the cursor is on. selection_start_y and _end_y are
# screen rows, the same coordinates copy_cursor_y uses, so both convert through
# the top of the view. The selection can be dragged upwards, so they are not
# ordered.
anchor_rows() {
  local dpane=$1 raw present sy ey hist base scroll cy top
  # Two sizes, and they are not interchangeable. base is what
  # #{scroll_position} is measured against, so it is what turns the cursor into
  # a row. hist is the live one, which is what capture-pane counts back from.
  # They differ by however much of the diff landed after copy-mode was entered.
  raw=$(tmux display-message -p -t "$dpane" \
    '#{selection_present}'$'\x1f''#{selection_start_y}'$'\x1f''#{selection_end_y}'$'\x1f''#{history_size}'$'\x1f''#{scroll_position}'$'\x1f''#{copy_cursor_y}'$'\x1f'"$hist_base" \
    2>/dev/null) || return 1
  IFS=$'\x1f' read -r present sy ey hist scroll cy base <<<"$raw"
  [[ -n $hist ]] || return 1
  top=$((base - ${scroll:-0}))
  # Handed on to anchor_text, which counts back from the live grid.
  ANCHOR_HIST=$hist
  if [[ $present == 1 && -n $sy && -n $ey ]]; then
    ANCHOR_FIRST_ROW=$((top + (sy < ey ? sy : ey)))
    ANCHOR_LAST_ROW=$((top + (sy > ey ? sy : ey)))
  else
    ANCHOR_FIRST_ROW=$((top + ${cy:-0}))
    ANCHOR_LAST_ROW=$ANCHOR_FIRST_ROW
  fi
  return 0
}

# What those rows amount to: a file, the span of its lines, and the first line
# itself to quote back. Rows that carry no number -- a header, a rule, the
# continuation of a wrapped line -- are skipped, so a selection that starts on
# one still resolves.
# What a span of rows amounts to: the commit it is in, the file if it is in
# one, the lines of that file it covers, and the rows themselves.
#
# The block is the whole selection, not a line of it. Selecting a commit
# message and its diffstat used to arrive at the agent as one stat line, which
# said nothing about what the reader had picked out.
anchor_text() {
  local dpane=$1 a=$2 b=$3 hist=${4:-0}
  local dump line first='' last='' text
  local back i=0 above=''
  local commit_row=-1 commit_sha='' file_row=-1 file_name=''
  local -a block=()

  commit_at "$a" && { commit_row=$REPLY; commit_sha=$REPLY_SHA; }
  file_at "$a" && { file_name=$REPLY; file_row=$REPLY_ROW; }
  # The header and message of a commit sit above its first file, so the file
  # found here belongs to the commit before and is not this selection's.
  ((commit_row > file_row)) && { file_name=''; file_row=-1; }

  # capture-pane counts from the top of the visible screen, with the history
  # behind it as negative numbers. a and b count from the start of the history,
  # so they are shifted back by its size.
  #
  # The capture starts above the span. Nearly half the rows delta writes carry
  # no number of their own -- the continuation of a wrapped line, the rows of a
  # hunk header box, a rule -- and a selection can sit entirely inside a run of
  # them. Those rows belong to the numbered row above, so it is read in the
  # same capture and used when the span itself yields no number. Bounded by the
  # commit header: the rows before it are a different commit's diff.
  back=$a
  ((back > 60)) && back=60
  ((commit_row >= 0 && a - back <= commit_row)) && back=$((a - commit_row - 1))
  ((back < 0)) && back=0
  dump=$(tmux capture-pane -p -S $((a - back - hist)) -E $((b - hist)) -t "$dpane" 2>/dev/null) ||
    return 1

  while IFS= read -r line; do
    i=$((i + 1))
    if ((i <= back)); then
      # Above the span: remembered only in case the span yields no number.
      gutter_line "$line" && above=$REPLY
      continue
    fi
    if gutter_line "$line"; then
      [[ -n $first ]] || first=$REPLY
      last=$REPLY
    fi
    # A selection of two hundred rows is a paste, not a comment. Kept to
    # something an agent can read, and said so rather than truncated silently.
    if ((${#block[@]} < 60)); then
      text=$(row_excerpt "$line")
      # Blank rows are kept inside the block but never lead it, so a selection
      # that starts on a rule does not open with empty lines.
      [[ -n $text || ${#block[@]} -gt 0 ]] && block+=("$text")
    elif ((${#block[@]} == 60)); then
      block+=("… selection continues")
    fi
  done <<<"$dump"

  [[ -n $first ]] || { first=$above; last=$above; }
  # Trailing blanks, from a selection that ran past the end of what it wanted.
  while ((${#block[@]})) && [[ -z ${block[-1]} ]]; do unset 'block[-1]'; done

  # Nothing at all: no commit, no file, no text. Nothing to say.
  [[ -n $commit_sha || -n $file_name || ${#block[@]} -gt 0 ]] || return 1

  ANCHOR_COMMIT=$commit_sha
  ANCHOR_FILE=$file_name
  ANCHOR_FIRST=$first
  ANCHOR_LAST=$last
  ANCHOR_BLOCK=$(printf '%s\n' "${block[@]+"${block[@]}"}")
  ANCHOR_BLOCK=${ANCHOR_BLOCK%$'\n'}
  return 0
}

# The text of a diff row, without its gutters: the new column if the row has
# one, else the old -- the same side the line number came from.
row_excerpt() {
  local line=$1 out=''
  if [[ $line == *│* ]]; then
    out=${line##*│}
    out=${out#"${out%%[![:space:]]*}"}
  fi
  # Nothing on the new side: a removed line, whose text is on the old one.
  # Taken between the two gutters rather than after the last, or the line
  # number comes back with it.
  if [[ -z ${out//[[:space:]]/} && $line == *┊* ]]; then
    out=${line#*┊}
    out=${out%%│*}
    out=${out#"${out%%[![:space:]]*}"}
  fi
  # Neither gutter: a commit header, its message, a rule. Taken whole.
  if [[ -z ${out//[[:space:]]/} && $line != *┊* && $line != *│* ]]; then
    out=${line#"${line%%[![:space:]]*}"}
  fi
  printf '%s' "${out%"${out##*[![:space:]]}"}"
}

# Opens an editor on a scratch file headed by the anchor, and queues whatever
# was written. The header is commented so it can be left in place while writing
# and stripped afterwards, the way a commit message template works. An empty
# file cancels, which is how :q! gets out.
add_comment() {
  local dpane=$1 store=$2 tmp body
  anchor_rows "$dpane" || return 0
  if ! anchor_text "$dpane" "$ANCHOR_FIRST_ROW" "$ANCHOR_LAST_ROW" "$ANCHOR_HIST"; then
    tmux display-message 'review: nothing there to comment on'
    return 0
  fi
  tmp=$(mktemp "${TMPDIR:-/tmp}/review-comment.XXXXXX") || return 0
  # The same header the agent will be given, so that what is being commented
  # on is in front of the reader while they write the comment.
  {
    printf '\n#\n'
    [[ -n $ANCHOR_COMMIT ]] && printf '# commit %s\n' "$ANCHOR_COMMIT"
    if [[ -n $ANCHOR_FILE ]]; then
      printf '# %s' "$ANCHOR_FILE"
      if [[ -n $ANCHOR_FIRST ]]; then
        printf ':%s' "$ANCHOR_FIRST"
        [[ $ANCHOR_FIRST == "$ANCHOR_LAST" ]] || printf -- '-%s' "$ANCHOR_LAST"
      fi
      printf '\n'
    fi
    [[ -n $ANCHOR_BLOCK ]] && printf '%s\n' "${ANCHOR_BLOCK//$'\n'/$'\n'}" | sed 's/^/# > /'
    printf '#\n# Lines beginning with # are dropped. Save nothing to cancel.\n'
  } >"$tmp"

  tmux display-popup -E -w 80% -h 60% -T ' comment ' \
    "\${EDITOR:-vi} $(printf '%q' "$tmp")"

  body=$(sed -e '/^#/d' -e 's/[[:space:]]*$//' "$tmp")
  # Leading and trailing blank lines, which the template and the editor both
  # leave behind.
  while [[ $body == $'\n'* ]]; do body=${body#$'\n'}; done
  while [[ $body == *$'\n' ]]; do body=${body%$'\n'}; done
  /bin/rm -f "$tmp"
  if [[ -z $body ]]; then
    tmux display-message 'review: comment discarded'
    return 0
  fi
  comment_add "$store" "$ANCHOR_COMMIT" "$ANCHOR_FILE" "$ANCHOR_FIRST" \
    "$ANCHOR_LAST" "$ANCHOR_BLOCK" "$body"
  comments=$(comment_count "$store")
  tmux display-message "review: $comments queued for ${agent_label_cur:-no agent}"
  return 0
}

# Hands the queue to the chosen agent and empties it. The pane is checked first:
# the agent may well have exited since it was picked, and pasting into whatever
# replaced it would be worse than saying so.
send_comments() {
  local win=$1 store=$2 range=$3 text n
  if [[ -z $agent_pane_cur ]]; then
    tmux display-message 'review: pick an agent first -- k to the agent row, then enter'
    return 0
  fi
  if ! tmux display-message -p -t "$agent_pane_cur" '#{pane_id}' >/dev/null 2>&1; then
    tmux display-message "review: ${agent_label_cur:-that agent} is gone -- pick another"
    return 0
  fi
  n=$(comment_count "$store")
  if ! text=$(comment_prompt "$store" "$range" "${PWD##*/}"); then
    tmux display-message 'review: nothing queued to send'
    return 0
  fi
  if ! comment_send "$agent_pane_cur" "$text"; then
    tmux display-message 'review: could not paste into that pane'
    return 0
  fi
  /bin/rm -f "$store"
  comments=0
  tmux display-message "review: $n sent to $agent_label_cur -- press enter there to run it"
  return 0
}

# Where a review's queued comments live.
#
# Keyed by the repository and the range rather than by the window. A window id
# belongs to one server and is recycled, so a queue keyed on one is unreachable
# the moment the window closes -- which is exactly when comments that were never
# sent still matter. Keyed this way, reopening the same review finds whatever
# was left queued, and two ranges of one repository stay two queues.
#
# In a directory of our own under TMPDIR: identifiable, out of the repo, and
# swept by the system's temp cleanup rather than kept for good. TMPDIR carries
# a trailing slash on macOS, hence the trim -- the doubled slash it produced was
# harmless, but it made every path printed from here look wrong.
comment_file() {
  local repo=$1 range=$2 dir key
  dir=${TMPDIR:-/tmp}
  dir=${dir%/}
  mkdir -p "$dir/tmux-review" 2>/dev/null && dir=$dir/tmux-review
  # Both parts: the same range of two checkouts is not one review, and two
  # ranges of one checkout are not either. The tail is kept when the name will
  # not fit, because the range and the repository's own name are at that end --
  # the path leading to it is the part that can be dropped.
  key=${repo}@${range}
  key=${key//[^A-Za-z0-9@._-]/_}
  ((${#key} > 180)) && key=${key: -180}
  printf '%s/comments-%s.txt' "$dir" "$key"
}

# One queued comment per record. The fields cannot contain the separators: a
# path and a line number never do, and the excerpt and the body are the last
# two, so a stray one in prose would only ever split the body from itself.
# The commit leads and the body trails: the body is whatever was typed into an
# editor and is the only field that could hold a separator, so it is the one
# that must be last, where read gives it everything remaining.
comment_add() {
  local store=$1 commit=$2 file=$3 first=$4 last=$5 block=$6 body=$7
  printf '%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1e' \
    "$commit" "$file" "$first" "$last" "$block" "$body" >>"$store"
}

comment_count() {
  local store=$1
  [[ -s $store ]] || { printf 0; return 0; }
  local n
  n=$(tr -cd $'\x1e' <"$store" | wc -c)
  printf '%s' "${n// /}"
}

# The prompt the agent receives. Written as a review rather than a request so
# the agent has the range, the file and the line in front of it and does not
# have to ask which diff this was about.
comment_prompt() {
  local store=$1 range=$2 repo=$3 commit file first last block body n=0 out='' head
  # An empty queue is refused here rather than at the read below. Pressing send
  # with nothing queued is an ordinary thing to do, and a queue that was never
  # written has no file at all -- so the redirect fails and bash prints its own
  # "No such file or directory" into the reader's pane before the caller gets a
  # chance to say what actually happened.
  [[ -s $store ]] || return 1
  out+="Code review comments on ${range}"
  [[ -n $repo ]] && out+=" in ${repo}"
  out+=$'.\n\n'
  while IFS=$'\x1f' read -r -d $'\x1e' commit file first last block body; do
    [[ -n $commit || -n $file || -n $block ]] || continue
    n=$((n + 1))
    # Commit, then the file if the selection was inside one, then the lines of
    # it the selection covered. A commit message has no file and no lines.
    head=''
    [[ -n $commit ]] && head="commit $commit"
    if [[ -n $file ]]; then
      [[ -n $head ]] && head+=" · "
      head+="$file"
      if [[ -n $first ]]; then
        head+=":$first"
        [[ $first == "$last" ]] || head+="-$last"
      fi
    fi
    out+="${n}. ${head}"$'\n'
    # Every line of the block is quoted, not just the first.
    [[ -n $block ]] && out+="   > ${block//$'\n'/$'\n'   > }"$'\n'
    # Every line of the body carries the indent, not just the first: a comment
    # that runs to a second paragraph should still read as one item.
    out+="   ${body//$'\n'/$'\n'   }"$'\n\n'
  done <"$store"
  ((n)) || return 1
  printf '%s' "$out"
}

# Hands the prompt to the agent without sending it. paste-buffer -p wraps it in
# the bracketed-paste the TUIs ask for, so a multi-line comment arrives as one
# paste rather than as a line that submits at the first newline. No Enter: the
# reader gets to see what is about to be asked before it is asked.
comment_send() {
  local pane=$1 text=$2
  tmux set-buffer -b review-comments -- "$text" || return 1
  tmux paste-buffer -p -b review-comments -t "$pane" || return 1
  return 0
}

# The agent sessions a comment could be sent to: every pane anywhere on this
# server that is running one, newest state first read straight off the window.
#
# The pane's own command decides it, not @agent_state: that option is written
# by the agent's hooks and outlives the agent, so a window whose agent has since
# exited still advertises a state. Claude Code installs each release as
# ~/.local/share/claude/versions/<version> and execs it directly, so its
# process name is the version string -- hence the numeric pattern, the same one
# agent-status.sh matches on.
#
# One invocation for the whole server; this runs when the picker is opened, not
# on the tick.
load_agent_sessions() {
  local skip_window=${1-} line pane cmd win sess idx name state cwd kind
  agent_pane=()
  agent_label=()
  agent_kind=()
  agent_state=()
  agent_cwd=()
  agent_session=()
  while IFS=$'\x1f' read -r pane cmd win sess idx name state cwd; do
    [[ -n $pane ]] || continue
    [[ -n $skip_window && $win == "$skip_window" ]] && continue
    case $cmd in
      codex) kind=codex ;;
      claude | [0-9]*.[0-9]*.[0-9]*) kind=claude ;;
      *) continue ;;
    esac
    agent_pane+=("$pane")
    agent_kind+=("$kind")
    agent_state+=("${state:-idle}")
    agent_cwd+=("$cwd")
    agent_session+=("$sess")
    agent_label+=("$sess:$idx  $name")
  done < <(tmux list-panes -a -F \
    '#{pane_id}'$'\x1f''#{pane_current_command}'$'\x1f''#{window_id}'$'\x1f''#{session_name}'$'\x1f''#{window_index}'$'\x1f''#{window_name}'$'\x1f''#{@agent_state}'$'\x1f''#{pane_current_path}' \
    2>/dev/null || true)
  return 0
}

# The agent this review is probably for. Two signals, and the stronger one is
# the tmux session: open puts the review window in the session it was asked
# from, so an agent in that session is a sibling of the work being reviewed.
# The weaker one is the directory, which still separates two worktrees of the
# same repository where a commit range would not.
#
# Never picks between equals. Two agents in the session, or two in the
# directory, and it leaves the row alone -- being asked to choose is a smaller
# cost than sending a review to the wrong agent.
#
# Answers the index of the agent to use, or nothing.
guess_agent() {
  local session=$1 cwd=$2 i sess dir tier len best=-1 best_tier=0 best_len=-2 count=0
  for i in "${!agent_pane[@]}"; do
    # Scored on the two signals separately and then combined, so that an agent
    # matching both outranks one matching either. Zero on both is no relation
    # at all and not a candidate.
    sess=0
    [[ -n $session && ${agent_session[i]} == "$session" ]] && sess=1
    dir=0
    if [[ ${agent_cwd[i]} == "$cwd" ]]; then
      dir=2
    elif [[ $cwd == "${agent_cwd[i]}"/* || ${agent_cwd[i]} == "$cwd"/* ]]; then
      # A worktree, or prefix+g pressed somewhere under the repository root.
      dir=1
    fi
    tier=$((sess * 3 + dir))
    ((tier)) || continue
    # The deeper directory wins a tie: an agent in a worktree under this
    # repository answers work inside that worktree better than one at the root
    # above it. Only where the directory said nothing -- a match on the session
    # alone -- is there nothing to break the tie with, and a tie is left alone.
    len=-1
    ((dir)) && len=${#agent_cwd[i]}
    if ((tier > best_tier || (tier == best_tier && len > best_len))); then
      best_tier=$tier
      best_len=$len
      best=$i
      count=1
    elif ((tier == best_tier && len == best_len)); then
      count=$((count + 1))
    fi
  done
  ((count == 1)) || return 1
  REPLY=$best
  return 0
}

# Runs once, and only over a row nobody has chosen for. Behind the first frame:
# listing every pane in the server is a round trip, and this is a convenience,
# not something the reader is waiting on.
preselect_agent() {
  local win=$1 session=$2 i glyph
  preselect_done=1
  [[ -z $agent_pane_cur ]] || return 0
  load_agent_sessions "$win"
  ((${#agent_pane[@]})) || return 0
  guess_agent "$session" "$PWD" || return 0
  i=$REPLY
  case ${agent_kind[i]} in
    codex) glyph='󰻟' ;;
    *) glyph='󰚩' ;;
  esac
  agent_pane_cur=${agent_pane[i]}
  agent_label_cur="$glyph  ${agent_label[i]}"
  # Marked as a guess, and drawn like one, so that s never sends somewhere the
  # reader did not look at. Choosing from the picker clears it.
  agent_guessed=1
  shown_session=-1
  tmux set-option -w -t "$win" @review_agent_pane "$agent_pane_cur" ';' \
    set-option -w -t "$win" @review_agent_label "$agent_label_cur" ';' \
    set-option -w -t "$win" @review_agent_guessed 1
  return 0
}

# The line number delta printed for a row, preferring the new file's over the
# old one's: a comment is about the change, and the new side is what the reader
# and the agent both have on disk. Empty for anything that is not a line of the
# diff -- a header, a rule, or the continuation of a wrapped line, which carries
# no number of its own.
#
# The row is split on the left gutter first so that a digit in the left column's
# own text cannot be mistaken for the right column's number.
gutter_line() {
  local row=$1 right
  REPLY=''
  [[ $row == *┊* ]] || return 1
  right=${row#*┊}
  if [[ $right =~ [[:space:]]([0-9]{1,7})│ ]]; then
    REPLY=${BASH_REMATCH[1]}
    return 0
  fi
  if [[ $row =~ ^[[:space:]]*([0-9]{1,7})┊ ]]; then
    REPLY=${BASH_REMATCH[1]}
    return 0
  fi
  return 1
}

# The file a scrollback row belongs to: the last file header at or above it.
# file_rows and file_names are filled by map_rows, in order, so this walks back
# from the end rather than searching.
file_at() {
  local row=$1 i
  REPLY=''
  REPLY_ROW=-1
  for ((i = ${#file_rows[@]} - 1; i >= 0; i--)); do
    if ((file_rows[i] <= row)); then
      REPLY=${file_names[i]}
      REPLY_ROW=${file_rows[i]}
      return 0
    fi
  done
  return 1
}

# The commit a scrollback row belongs to: the last commit header at or above
# it. Answers its row in REPLY and its sha in REPLY_SHA. row_of is keyed the
# other way round, by sha, so this walks it rather than indexing it.
commit_at() {
  local row=$1 i best=-1 sha=''
  # Nothing mapped yet, so nothing to be inside of.
  ((${#shas[@]})) || return 1
  for i in "${!shas[@]}"; do
    [[ -v row_of[${shas[i]}] ]] || continue
    if ((row_of[${shas[i]}] <= row && row_of[${shas[i]}] > best)); then
      best=${row_of[${shas[i]}]}
      sha=${shas[i]}
    fi
  done
  ((best >= 0)) || return 1
  REPLY=$best
  REPLY_SHA=$sha
  return 0
}

map_rows() {
  local pane=$1 line n text sha commits='' files='' stops=''

  row_of=()
  file_rows=()
  file_names=()
  # One grep, straight off the capture. The dump used to be read into a shell
  # variable and then grepped twice over it, which on a diff of twenty thousand
  # rows meant holding a megabyte and a half in the shell and walking it three
  # times -- and this runs while the reader is looking at the placeholder.
  # Matching both kinds of header together and telling them apart here also
  # yields the merged list in row order, so the sort the jump keys used to need
  # is gone with it.
  while IFS= read -r line; do
    n=$((${line%%:*} - 1))
    text=${line#*:}
    if [[ $text == 'commit '* ]]; then
      sha=${text#commit }
      row_of[${sha%% *}]=$n
      commits+="$n "
    else
      files+="$n "
      file_rows+=("$n")
      # "<indent><label glyph> path" -- drop the indent, then the glyph, and
      # what is left is the path.
      text=${text#"${text%%[![:space:]]*}"}
      text=${text#* }
      file_names+=("${text%"${text##*[![:space:]]}"}")
    fi
    # Published so the jump keys need no parsing of their own: a jump that
    # re-greps a 6000-line scrollback and shells out to git config costs most
    # of a second, which is far too slow for a keypress. n and N stop at either
    # kind, which is what delta's own navigate did, so the two are merged.
    stops+="$n "
  done < <(tmux capture-pane -p -S - -E - -t "$pane" 2>/dev/null |
    grep -nE "^commit [0-9a-f]{7,}|$file_re" || true)

  local -a pub=()
  if [[ $commits != "$pub_commits" ]]; then
    pub+=(set-option -p -t "$pane" @review_commit_rows "${commits% }" ';')
    pub_commits=$commits
  fi
  if [[ $files != "$pub_files" ]]; then
    pub+=(set-option -p -t "$pane" @review_file_rows "${files% }" ';')
    pub_files=$files
  fi
  if [[ $stops != "$pub_stops" ]]; then
    pub+=(set-option -p -t "$pane" @review_stop_rows "${stops% }" ';')
    pub_stops=$stops
  fi
  # One invocation for all three, minus the trailing separator.
  ((${#pub[@]})) && tmux "${pub[@]::${#pub[@]}-1}"

  ((${#row_of[@]} == ${#shas[@]})) && mapped=1
  return 0
}

# Takes the width the content wants whenever the window changes size. tmux
# redistributes on resize with no regard for what is in a pane: shrinking a
# 477-column window to 200 left this one a single column wide. Answers false
# when it asked for a resize, so the caller starts a fresh tick against the
# geometry that follows.
#
# Compared against the pane's own width rather than the last request, because
# tmux redistributes on every resize and the width has to be re-claimed each
# time even when nothing about the content changed.
claim_width() {
  local pane=$1 window=$2 current=$3 ideal
  ((window != window_seen)) || return 0
  window_seen=$window

  columns_for "$window"
  ideal=$REPLY
  ((ideal != current)) || return 0
  tmux resize-pane -x "$ideal" -t "${TMUX_PANE:-$pane}"
  return 1
}

# What the range line offers when it is opened. Each item is a kind, a label, a
# second column and a payload, held in four parallel arrays; the kind is what
# apply_pick dispatches on. Separators are items too, so the list can be grouped
# without the renderer having to know where the groups are.
#
# Built on demand rather than at startup: branches and stashes change under a
# long-lived review, and this costs two git calls only when it is asked for.
load_pick_items() {
  local range=$1 name subject
  pick_kind=()
  pick_label=()
  pick_extra=()
  pick_payload=()

  pick_add() {
    pick_kind+=("$1")
    pick_label+=("$2")
    pick_extra+=("$3")
    pick_payload+=("$4")
  }

  pick_add range 'outstanding' "$range" ''
  pick_add prompt-count 'last n commits' 'asks' ''
  pick_add prompt-range 'a range' 'asks' ''
  pick_add sep '' '' ''
  pick_add wip 'uncommitted' 'working tree' ''
  pick_add staged 'staged' 'index' ''

  local -a branches=()
  while IFS= read -r name; do
    [[ -n $name ]] && branches+=("$name")
  done < <(git for-each-ref --sort=-committerdate --format='%(refname:short)' \
    refs/heads refs/remotes 2>/dev/null | grep -v '^origin$' | head -12)
  if ((${#branches[@]})); then
    pick_add sep '' '' ''
    for name in "${branches[@]}"; do
      pick_add range "$name" 'since' "$name"
    done
  fi

  local -a stashes=()
  while IFS= read -r name; do
    [[ -n $name ]] && stashes+=("$name")
  done < <(git stash list --format='%gd%x1f%s' 2>/dev/null | head -12)
  if ((${#stashes[@]})); then
    pick_add sep '' '' ''
    for name in "${stashes[@]}"; do
      subject=${name#*$'\x1f'}
      name=${name%%$'\x1f'*}
      pick_add stash "$name" "$subject" "$name"
    done
  fi
  unset -f pick_add
}

# The agents on offer, as picker items. The review's own window is left out --
# there is no agent in it, and offering it would only invite sending a review
# to the pane that is displaying it.
load_pick_sessions() {
  local win=$1 i glyph
  pick_kind=()
  pick_label=()
  pick_extra=()
  pick_payload=()

  load_agent_sessions "$win"
  if ((${#agent_pane[@]} == 0)); then
    pick_kind+=(none)
    pick_label+=('no agent is running')
    pick_extra+=('')
    pick_payload+=('')
    return 0
  fi

  for i in "${!agent_pane[@]}"; do
    case ${agent_kind[i]} in
      codex) glyph='󰻟' ;;
      *) glyph='󰚩' ;;
    esac
    pick_kind+=(session)
    # Two spaces after the glyph, not one: it takes two cells, so a single
    # space is swallowed by it and the label reads as butted up against it.
    pick_label+=("$glyph  ${agent_label[i]}")
    pick_extra+=("${agent_state[i]}")
    # The pane is what a comment is pasted into; the label is what the row shows.
    pick_payload+=("${agent_pane[i]}"$'\x1f'"$glyph  ${agent_label[i]}")
  done
  return 0
}

# Remembers the agent on the window rather than in this process, so it survives
# a retarget -- which replaces the sidebar with a new one aimed elsewhere.
apply_pick_session() {
  local win=$1 i=$2
  [[ ${pick_kind[i]} == session ]] || return 0
  agent_pane_cur=${pick_payload[i]%%$'\x1f'*}
  agent_label_cur=${pick_payload[i]#*$'\x1f'}
  agent_guessed=0
  tmux set-option -w -t "$win" @review_agent_pane "$agent_pane_cur" ';' \
    set-option -w -t "$win" @review_agent_label "$agent_label_cur" ';' \
    set-option -w -t "$win" @review_agent_guessed ''
  return 0
}

# The first selectable item at or after index, walking in the given direction.
# Separators are skipped rather than being unselectable-but-landable-on.
# Answers in REPLY, like its neighbours: this is on the picker's key path.
pick_seek() {
  local i=$1 step=$2
  while ((i >= 0 && i < ${#pick_kind[@]})) && [[ ${pick_kind[i]} == sep ]]; do
    i=$((i + step))
  done
  ((i < 0)) && i=0
  ((i >= ${#pick_kind[@]})) && i=$((${#pick_kind[@]} - 1))
  REPLY=$i
  return 0
}

render_picker() {
  local width=$1 height=$2 cur=$3 i out='' rule label extra
  rule="$dim $rule_dashes$reset"
  out+=$'\e[H\e[2J'
  needs_clear=0

  fit 'review' $((width - 1))
  out+="$accent $REPLY$reset"$'\e[K\n'
  fit 'enter chooses, esc goes back' $((width - 1))
  out+="$dim $REPLY$reset"$'\e[K\n'
  out+="$rule"$'\e[K\n'

  # The second column is right-aligned against the far edge, so the labels stay
  # a readable block however long the branch names are.
  local label_w=$((width - 22))
  ((label_w < 8)) && label_w=8
  for i in "${!pick_kind[@]}"; do
    if [[ ${pick_kind[i]} == sep ]]; then
      out+="$rule"$'\e[K\n'
      continue
    fi
    fit "${pick_label[i]}" "$label_w"
    label=$REPLY
    fit "${pick_extra[i]}" 18
    extra=$REPLY
    if ((i == cur)); then
      out+="$active $label $extra$reset"$'\e[K\n'
    else
      out+=" $c_subject$label$reset $dim$extra$reset"$'\e[K\n'
    fi
  done
  out+=$'\e[J'
  printf '%s' "$out"
}

# Acts on the chosen item. A commit range replaces this window; anything that is
# not a range -- the working tree, the index, a stash -- has no commits to list,
# so it goes to a popup rather than a window with an empty sidebar.
apply_pick() {
  local pane=$1 win=$2 i=$3 kind=${pick_kind[$3]} payload=${pick_payload[$3]}
  local cwd
  cwd=$(tmux display-message -p -t "$pane" '#{pane_current_path}')

  case $kind in
    range)
      retarget "$win" "$payload"
      ;;
    wip | staged)
      tmux display-popup -E -w 90% -h 90% -d "$cwd" "$git_review --$kind"
      ;;
    stash)
      tmux display-popup -E -w 90% -h 90% -d "$cwd" \
        "$git_review --stash $(printf '%q' "$payload")"
      ;;
    prompt-count)
      tmux command-prompt -p 'review the last n commits:' -I '1' \
        "run-shell \"$self retarget $win %%\""
      ;;
    prompt-range)
      tmux command-prompt -p 'review:' -I 'origin/HEAD' \
        "run-shell \"$self retarget $win %%\""
      ;;
  esac
}

# Replaces a review window with one aimed somewhere else, keeping the window q
# should return to. The kill comes last: it takes this process with it.
retarget() {
  local win=$1 target=$2 origin back
  origin=$(tmux show-options -w -t "$win" -qv @review_diff_pane 2>/dev/null) || return 0
  [[ -n $origin ]] || return 0
  back=$(tmux show-options -w -t "$win" -qv @review_return 2>/dev/null) || back=''
  open "$origin" "$target" "$back" || return 0
  tmux kill-window -t "$win"
}

# One frame of the placeholder, then the tick's wait. Reads and advances the
# caller's spin, and forces the next list frame to redraw from scratch.
# The commit list, drawn before the row map behind its highlight exists.
# Everything it shows is already in hand -- only which commit the reader is
# inside has to wait for the map, so it is shown against the first, which is
# where the diff pane parks itself. This replaces several seconds of spinner
# held over a list that was complete the whole time.
hold_list() {
  if ((shown != 0)); then
    render 0 "$width" "$height" diff "$on_range" "$searching" "$on_session"
    ((shown == -2)) && trace list-drawn
    shown=0
  fi
  if IFS= read -rsn1 -t 0.25 _; then
    spin=0
  fi
  return 0
}

hold_placeholder() {
  render_loading "$width" "$height" "$spin"
  spin=$((spin + 1))
  shown=-2
  # A key arriving is the diff pane saying it has finished, so the next turn
  # round the loop asks tmux rather than waiting out the throttle. An `if`
  # rather than `&&`, which under set -e would take the whole loop down on the
  # timeout that is the normal case.
  if IFS= read -rsn1 -t 0.25 _; then
    spin=0
  fi
  return 0
}

render() {
  local cur=$1 width=$2 height=$3 focus=$4 on_range=${5:-0} searching=${6:-0}
  local on_session=${7:-0}
  # Read from the sidebar's loop when there is one, defaulted so this function
  # can be called on its own -- which is how it is tested.
  local agent_label_cur=${agent_label_cur-} agent_glyph_cur=${agent_glyph_cur-󰚩}
  local comments=${comments-0}
  local i out='' rule stat visible first last rowpad
  rule="$dim $rule_dashes$reset"

  # Three header rows, three rules, the stat and the one key row leave this much
  # for the list; the selection is kept centred once there are more commits than
  # fit.
  visible=$((height - 8))
  ((visible < 1)) && visible=1
  first=0
  if ((${#shas[@]} > visible)); then
    first=$((cur - visible / 2))
    ((first < 0)) && first=0
    ((first > ${#shas[@]} - visible)) && first=$((${#shas[@]} - visible))
  fi
  last=$((first + visible - 1))
  ((last >= ${#shas[@]})) && last=$((${#shas[@]} - 1))

  out+=$'\e[H'
  if ((needs_clear)); then
    out+=$'\e[2J'
    needs_clear=0
  fi
  # The range and the key hint are the only rows whose length is not derived
  # from the pane width, so they are the two that have to be cut to it -- a row
  # that wraps costs a line and scrolls the top of the list away.
  # The range line is a row of the list: moving up off the first commit selects
  # it, and that is the only place enter means anything.
  fit "$range" $((width - 1))
  if ((on_range)); then
    out+="$active $REPLY$reset"$'\e[K\n'
  else
    out+="$accent $REPLY$reset"$'\e[K\n'
  fi

  # Where a comment would go. Sits under the range because it is the other thing
  # this review is aimed at, and is selected the same way -- by walking up off
  # the first commit -- so enter opens its picker just as it does the range's.
  # The label already carries the harness glyph, from the picker that set it.
  local agent_row
  if [[ -n $agent_label_cur ]]; then
    agent_row="$agent_label_cur"
  else
    agent_row="$agent_glyph_cur  no agent selected"
  fi
  ((comments)) && agent_row+="  · $comments queued"
  fit "$agent_row" $((width - 1))
  if ((on_session)); then
    out+="$active $REPLY$reset"$'\e[K\n'
  elif [[ -n $agent_label_cur ]] && ((${agent_guessed:-0} == 0)); then
    out+=" $c_author$REPLY$reset"$'\e[K\n'
  else
    # A guess is drawn in the same dim the empty row uses, so the row never
    # reads as a decision the reader made. Choosing it from the picker is what
    # brings it up to the chosen colour.
    out+=" $dim$REPLY$reset"$'\e[K\n'
  fi

  out+="$dim ${#shas[@]} commit$( ((${#shas[@]} == 1)) || printf s)"
  ((${#shas[@]} > visible)) && out+="  $((first + 1))-$((last + 1))"
  out+="$reset"$'\e[K\n'
  out+="$rule"$'\e[K\n'

  for ((i = first; i <= last; i++)); do
    if ((i == cur && !on_range)); then
      # One colour across the selected row. The per-field palette that reads
      # well on the page loses too much contrast against the accent background
      # -- the same trap the robot glyph hit when it read as red on purple.
      dwidth "${rows_plain[i]}"
      rowpad=''
      ((width > REPLY)) && printf -v rowpad '%*s' $((width - REPLY)) ''
      out+="$active${rows_plain[i]}$rowpad$reset"$'\e[K\n'
    else
      out+="${rows_col[i]}"$'\e[K\n'
    fi
  done

  out+="$rule"$'\e[K\n'
  stat=${stat_of[${shas[cur]}]:-}
  if [[ $stat =~ ([0-9]+)\ insertion ]]; then
    out+=" $added+${BASH_REMATCH[1]}$reset"
  fi
  if [[ $stat =~ ([0-9]+)\ deletion ]]; then
    out+=" $removed-${BASH_REMATCH[1]}$reset"
  fi
  if [[ $stat =~ ([0-9]+)\ file ]]; then
    out+=" ${dim}· ${BASH_REMATCH[1]} file$( ((BASH_REMATCH[1] == 1)) || printf s)$reset"
  fi
  out+=$'\e[K\n'
  out+="$rule"$'\e[K\n'
  # The legend picks a form that fits rather than being cut, because a row that
  # wraps costs a line and the layout is sized to fill the pane exactly. For the
  # same reason there is no newline after the last row -- printing one on the
  # bottom row scrolls the range line off the top.
  # Only the focused pane's keys. Both rows at once was a row of the list spent
  # on keys that do nothing where the reader is.
  if ((on_range)); then
    render_legend "$width" range legend_range_tiers
  elif ((on_session)); then
    render_legend "$width" agent legend_session_tiers
  elif [[ $focus == list ]]; then
    render_legend "$width" list legend_list_tiers
  elif ((searching)); then
    render_legend "$width" diff legend_diff_search_tiers
  else
    render_legend "$width" diff legend_diff_tiers
  fi
  out+=" $REPLY"$'\e[K\e[J'
  printf '%s' "$out"
}

# Absolute selection. The scrollback row of every commit is already known, so
# the view goes straight there. Reads shas, row_of, pane, hist and cy from the
# sidebar loop that calls it.
# Paint a selection before making the move that causes it. Drawing the list is
# local and costs nothing; moving the diff pane is a round trip. Painting only
# once that came back is what made j and k feel a keypress behind -- the
# highlight now moves on the key and the diff catches up.
#
# A no-op outside the sidebar's loop: nav drives the same jump from a process
# that has no list to paint and none of the loop's state to paint it from.
paint_index() {
  local i=$1 focus=diff
  ((${width:-0} > 0 && ${height:-0} > 0)) || return 0
  ((i >= 0 && i < ${#shas[@]})) || return 0
  ((${diff_active:-1})) || focus=list
  render "$i" "$width" "$height" "$focus" \
    "${on_range:-0}" "${searching:-0}" "${on_session:-0}"
  shown=$i
  shown_focus=$focus
  return 0
}

# The move the keys have asked for and that has not been sent yet. Sent once,
# when the reader stops: read_key coming back with nothing is a quarter of a
# second without a keypress, which is exactly the pause to send on.
#
# Never while a previous move is still unconfirmed -- place works from the
# cursor position last reported, and that report is the thing outstanding.
flush_pending() {
  local pane=$1
  ((pending_row >= 0)) || return 0
  ((expect_row < 0)) || return 0
  place "$pane" "$hist" "$cy" "$pending_row"
  expect_row=$pending_row
  expect_turns=0
  pending_row=-1
  return 0
}

select_index() {
  local i=$1
  ((i < 0)) && i=0
  ((i >= ${#shas[@]})) && i=$((${#shas[@]} - 1))
  [[ -v row_of[${shas[i]}] ]] || return 0
  paint_index "$i"
  # Not moved here. The move is held until the reader pauses -- see
  # flush_pending -- so that holding j costs one round trip rather than one
  # per key, and the highlight never waits on the pane to keep up.
  pending_row=${row_of[${shas[i]}]}
  return 0
}

# Puts scrollback row <target> under the cursor without moving the cursor off
# its screen row, which is what makes a jump land where the reader was looking.
#
# goto-line n is really "set scroll_position to n", and it leaves copy_cursor_y
# alone. It is also far cheaper than scrolling, whose repeat count is paid per
# row: 130ms for a 129-row scroll-down against 15ms for a goto-line.
place() {
  local pane=$1 hist=$2 cy=$3 target=$4
  local n=$((hist + cy - target))
  ((n > hist)) && n=$hist
  ((n < 0)) && n=0

  # Non-zero only when the view ran out of history at one end and could not be
  # placed as asked, so the cursor has to cover what is left. Both commands go
  # in one tmux invocation, because a second client call costs more than the
  # work it carries.
  local residual=$((target - (hist - n) - cy))
  if ((residual > 0)); then
    tmux send-keys -X -t "$pane" goto-line "$n" ';' \
      send-keys -X -N "$residual" -t "$pane" cursor-down
  elif ((residual < 0)); then
    tmux send-keys -X -t "$pane" goto-line "$n" ';' \
      send-keys -X -N "$((-residual))" -t "$pane" cursor-up
  else
    tmux send-keys -X -t "$pane" goto-line "$n"
  fi
  return 0
}

# Replaces delta's `navigate`, which cannot work here: delta implements n/N by
# handing less a search pattern, and tmux's own copy-mode search is no
# substitute -- it fails to find delta's file labels at all, and not because of
# the regex, since search-forward-text misses them too. Moving the view by an
# exact row offset works regardless, and gets commit stops for free.
#
# The stop point lands on the screen row the cursor was already on, so a jump
# from the top of the view puts the next file at the top and a jump from ten
# rows down puts it ten rows down. That is why this scrolls rather than moving
# the cursor: scroll-up/scroll-down shift the view and leave copy_cursor_y
# alone, whereas cursor-down drags the cursor to the bottom edge and buries the
# header there with the whole file below the fold.
#
# Every input arrives in argv because tmux format-expands a run-shell command
# before running it, which saves this a display-message round trip -- most of
# what a keypress used to cost. What remains is one send-keys.
jump() {
  local pane=$1 dir=$2 hist=$3 scroll=$4 cy=$5
  shift 5
  # The rows arrive as the remaining arguments rather than one quoted string:
  # a tmux binding that has to quote a format inside a run-shell inside an
  # if-shell is three levels of escaping waiting to go wrong.
  local rows="$*"
  [[ -n $scroll && -n $cy && -n $rows ]] || return 0

  local pos=$((hist - scroll + cy)) target
  # Step from where the keys have asked to be, not from where the pane has got
  # to. A move that is queued, or sent and not yet confirmed, both leave the
  # reported cursor behind the reader -- and a second j computed off that
  # recomputes the same target, so the keypress is simply lost.
  ((${at_row:--1} >= 0)) && pos=$at_row
  pick_target "$dir" "$pos" "$rows"
  target=$REPLY
  [[ -n $target ]] || return 0

  # Only in the sidebar's loop; nav has no list to paint and no loop to hold
  # the move for, so it moves the pane itself.
  if ((${width:-0} > 0)); then
    current_index "$target"
    paint_index "$REPLY"
    pending_row=$target
    return 0
  fi
  place "$pane" "$hist" "$cy" "$target"
  return 0
}

# Which stop row a jump lands on: the nearest one past the cursor in the
# direction asked for, or an end of the list. Answers empty when there is none,
# which is how a jump at the last stop becomes a no-op.
pick_target() {
  local dir=$1 pos=$2 rows=$3 r target=''
  case $dir in
    next) for r in $rows; do ((r > pos)) && { target=$r; break; }; done ;;
    prev) for r in $rows; do ((r < pos)) && target=$r; done ;;
    first) target=${rows%% *} ;;
    last) target=${rows##* } ;;
  esac
  REPLY=$target
  return 0
}

# jump for callers that only know the window -- the which-key menu, whose
# commands run against whichever pane happens to be active. It reads the diff
# pane's state itself rather than having the caller expand it, so the same entry
# works with either pane focused.
# Hands a key to the list's loop from outside the review, which is how the
# which-key menu reaches the same actions the keys do. Everything to do with
# comments lives in that loop -- the queue, the chosen agent -- so there is one
# way in rather than two implementations.
keypress() {
  local win=$1 key=$2 dpane list
  dpane=$(tmux show-options -w -t "$win" -qv @review_diff_pane 2>/dev/null) || return 0
  [[ -n $dpane ]] || return 0
  # The list is the window's other pane. Found rather than stored, because the
  # diff pane is the one thing every mode here already knows.
  list=$(tmux list-panes -t "$win" -F '#{pane_id}' 2>/dev/null | grep -vFx "$dpane" | head -1)
  [[ -n $list ]] || return 0
  tmux send-keys -t "$list" "$key"
  return 0
}

nav() {
  local win=$1 dir=$2 kind=$3 pane raw in_mode hist scroll cy rows
  pane=$(tmux show-options -w -t "$win" -qv @review_diff_pane 2>/dev/null) || return 0
  [[ -n $pane ]] || return 0
  # \x1f for the same reason as the sidebar's tick: a pane that is not in
  # copy-mode reports scroll_position and copy_cursor_y as empty, and a tab
  # separator would drop both fields and shift the rows list into cy.
  raw=$(tmux display-message -p -t "$pane" \
    '#{pane_in_mode}'$'\x1f'"$hist_base"$'\x1f''#{scroll_position}'$'\x1f''#{copy_cursor_y}'$'\x1f'"#{@review_${kind}_rows}" \
    2>/dev/null) || return 0
  IFS=$'\x1f' read -r in_mode hist scroll cy rows <<<"$raw"
  [[ $in_mode == 1 ]] || return 0
  # shellcheck disable=SC2086  # rows are separate arguments, as above
  jump "$pane" "$dir" "$hist" "$scroll" "$cy" $rows
}

usage() {
  # printf, not echo: echo leaves the \n as two literal characters here.
  printf '%s\n' \
    "usage: ${0##*/} open <pane> [<range>] | diff <range> |" \
    "       sidebar <pane> <range> [<window width> <window height>] |" \
    "       quit <target> | nav <window> next|prev|first|last stop|file|commit |" \
    "       jump <pane> next|prev|first|last <hist> <scroll> <cy> <row>... |" \
    "       key <window> <key> | retarget <window> <target>" >&2
  exit 64
}

main() {
  case ${1-} in
    open)    shift; open "$1" "${2-}" "${3-}" ;;
    diff)    shift; diff_pane_cmd "$1" "${2-}" ;;
    sidebar) shift; sidebar "$1" "$2" "${3-}" "${4-}" ;;
    jump)    shift; jump "$@" ;;
    nav)     shift; nav "$1" "$2" "$3" ;;
    key)     shift; keypress "$1" "$2" ;;
    quit)    shift; quit "$1" ;;
    retarget) shift; retarget "$1" "${2-}" ;;
    *)       usage ;;
  esac
}

# Dispatch only when run. The tests source this file to reach the functions
# that need no tmux, and sourcing must not run anything.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
