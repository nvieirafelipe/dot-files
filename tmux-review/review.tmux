#!/usr/bin/env bash
set -euo pipefail

# Entry point. tmux runs this once, when the configuration is loaded, and it
# does nothing but bind keys -- everything else happens in scripts/review.sh
# when one of them is pressed.
#
# Load it after tmux-yank: the copy-mode-vi table is rewritten as plugins load,
# so Enter bound before that is overwritten by them. Under tpm that means
# listing this plugin last; sourced directly, it means putting the run-shell
# after the tpm block, which is what .tmux.conf does.

plugin_dir=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)
scripts=$plugin_dir/scripts

# shellcheck source-path=SCRIPTDIR source=scripts/helpers.sh
source "$scripts/helpers.sh"

# The two keys worth moving. Read once, when the configuration is loaded --
# not on the path a reader waits on, which is why these are options and the
# widths in variables.sh are not.
open_key=$(get_tmux_option '@review-key' 'g')
wip_key=$(get_tmux_option '@review-wip-key' 'G')

# Every guarded binding tests the same two things: that this window is a review
# at all, and that the pane is in copy-mode rather than view-mode. The
# copy-mode-vi table is shared with view-mode -- which is what tmux shows
# command output in -- and an unguarded q there closed the review window
# instead of the key list it was asked to close.
#
# in_review is that pair, and it is the whole test for a key that acts on this
# pane and no other.
in_review='#{&&:#{@review},#{==:#{pane_mode},copy-mode}}'

# A key that is handed to another pane needs one test more, and it is what keeps
# a routed key from being routed back into itself. The corner tokens name a
# *visible* pane: when the diff is zoomed tmux counts only the zoomed pane as
# visible, so the target resolves to the pane the key was just pressed in.
# send-keys then replays the key into the binding that sent it, the guard is
# still true, and it routes again -- a recursion with no base case. Each hop
# queues a command and expands this format, so the server stops serving and
# grows until it is killed; nothing short of SIGKILL reaches it, because it
# never returns to its event loop to read one. The same applies to a key pressed
# on either of the two left panes, which mouse scroll can put in copy-mode, and
# to a review left with a single pane.
#
# pane_at_left is 0 only while some other pane is to the left to route to, which
# is exactly when routing means anything -- so it covers all three at once. It
# is still the whole test with the header pane there: that pane and the list are
# both at the left, so neither routes, and the diff -- the only one that does --
# is not.
#
# Only the routing keys carry it. Enter stays on in_review: it copies in place
# rather than routing, so it is not in the loop, and refusing it while the diff
# is zoomed would drop the pane out of copy-mode and end the review -- which is
# the one thing its own binding exists to prevent.
routes_left="#{&&:$in_review,#{==:#{pane_at_left},0}}"

# A review whose diff is zoomed has nowhere to route to until it is unzoomed.
# The keys that carry no fallback of their own unzoom instead of doing nothing,
# so that a zoomed review answers the key rather than swallowing it.
zoomed_review="#{&&:$in_review,#{window_zoomed_flag}}"

# Collected and sent in one invocation. Bound one call at a time this is a
# dozen execs every time the configuration is reloaded, and on a machine whose
# endpoint agent inspects each one that is measurable at every tmux start. A
# bare ';' argument is what separates two commands within the one call.
cmds=()
bind() { cmds+=(bind-key "$@" ';'); }

# Opens a review window: the diff on the right, a narrow commit list on the
# left that highlights whichever commit the diff cursor is sitting in. In the
# background because the script waits for delta to finish writing before it
# parks the cursor, and tmux would be blocked for that whole time otherwise.
bind "$open_key" run-shell -b "$scripts/review.sh open #{pane_id}"

# The working tree has no commits to list, so it stays a popup over the current
# pane -- nothing to split, nothing to restore, q dismisses. The path is
# absolute on purpose: the popup shell is non-interactive, so a PATH entry
# exported from .zshrc is not guaranteed to be there (the same trap
# agent-focus.sh hit under Notification Center).
bind "$wip_key" display-popup -E -w 90% -h 90% -d '#{pane_current_path}' \
  "$plugin_dir/bin/git-review --wip"

# delta's `navigate` (n/N between stop points) only works under less, so it is
# gone in the review window. These put it back: n and N step to the next stop of
# either kind, exactly as delta did, and ]/[ and }/{ narrow that to files or
# commits. tmux's own copy-mode search cannot stand in: it fails to find delta's
# file labels at all -- not a regex problem, search-forward-text misses them
# too, because they are private-use codepoints.
#
# Each one hands the key to the pane on the left, which is the commit list, and
# its loop does the work. That loop is already running and already knows where
# the cursor is, so nothing has to be forked or looked up: routing the key this
# way cost a third of what running the script per keypress did.
#
# A corner token rather than a stored pane id, because send-keys does not
# expand formats in -t. {bottom-left} rather than {left}: the left column is a
# header pane above the commit list, and the list is the lower of the two by
# construction -- open() splits the header off first -- so the corner names it
# and never the header.
bind -T copy-mode-vi ']' if-shell -F "$routes_left" "send-keys -t '{bottom-left}' ']'"
bind -T copy-mode-vi '[' if-shell -F "$routes_left" "send-keys -t '{bottom-left}' '['"
bind -T copy-mode-vi '}' if-shell -F "$routes_left" "send-keys -t '{bottom-left}' '}'"
bind -T copy-mode-vi '{' if-shell -F "$routes_left" "send-keys -t '{bottom-left}' '{'"

# c writes a comment about the line under the cursor -- or about the visual
# selection, if one is up -- and s hands everything queued to the agent chosen
# on the sidebar's second row. Routed to the list's loop like the jumps above,
# because that is where the queue and the chosen agent live. Neither key means
# anything else in copy-mode-vi, so there is nothing to fall back to. a picks
# which agent the comments go to, without having to walk the selection up to the
# row that names it.
bind -T copy-mode-vi c if-shell -F "$routes_left" "send-keys -t '{bottom-left}' c" \
  "if-shell -F '$zoomed_review' 'resize-pane -Z'"
bind -T copy-mode-vi s if-shell -F "$routes_left" "send-keys -t '{bottom-left}' s" \
  "if-shell -F '$zoomed_review' 'resize-pane -Z'"
bind -T copy-mode-vi a if-shell -F "$routes_left" "send-keys -t '{bottom-left}' a" \
  "if-shell -F '$zoomed_review' 'resize-pane -Z'"

# n and N have to keep meaning search-again everywhere else, so they fall back
# to it. if-shell -F spawns nothing, so search outside a review stays instant.
#
# Inside a review they mean the next diff stop -- until / or ? has been used,
# after which they mean the next match, the way they do in vim and in less.
# pane_search_string is the signal: it cannot be cleared once set, but it is
# per-pane and every review opens a fresh one, so it starts empty and only holds
# for the review the search was made in. ][ and }{ still step files and commits,
# so searching costs no navigation.
search_again="if-shell -F '#{!=:#{pane_search_string},}'"
bind -T copy-mode-vi n if-shell -F "$routes_left" \
  "$search_again 'send-keys -X search-again' \"send-keys -t '{bottom-left}' n\"" \
  'send-keys -X search-again'
bind -T copy-mode-vi N if-shell -F "$routes_left" \
  "$search_again 'send-keys -X search-reverse' \"send-keys -t '{bottom-left}' N\"" \
  'send-keys -X search-reverse'

# q closes the review window and goes back to where it was opened from, but only
# from a diff it is actually scrolling -- in view-mode it has to stay cancel, or
# closing the which-key key list would take the review with it. Handed to the
# list's loop like the jumps above, which closes the window from there.
bind -T copy-mode-vi q if-shell -F "$routes_left" \
  "send-keys -t '{bottom-left}' q" \
  'send-keys -X cancel'

# y, ! and the mouse drag are tmux-yank's, and @yank_action in .tmux.conf
# already takes the cancel off them. Enter is tmux's own default binding and
# still carries it, so it is the one key left that would drop a review out of
# copy-mode -- which would end it, because the jump keys are guarded on the mode
# and the sidebar follows the reader through copy_cursor_y.
bind -T copy-mode-vi Enter if-shell -F "$in_review" \
  'send-keys -X copy-pipe' \
  'send-keys -X copy-pipe-and-cancel'

# The trailing separator would have tmux parse an empty command after the last.
unset 'cmds[-1]'
tmux "${cmds[@]}"
