#!/usr/bin/env bash
# The numbers and colours the review window is drawn with. Sourced by
# scripts/review.sh; kept apart from it so the two things anyone actually wants
# to change are not buried in two thousand lines of drawing code.
#
# Plain shell variables rather than tmux options on purpose. Every option read
# is a round trip to the server, and on the machine this was tuned on that is
# most of a second per review -- the cost this plugin spent a week removing.
# Change them here and reload; there is nothing to set in .tmux.conf.
#
# Every name below is read by review.sh, which sources this file, so to a
# linter reading it alone they all look unused.
# shellcheck disable=SC2034

# The list takes a share of the window rather than being sized to the commits
# it holds. Sized to content it could only be worked out by whoever had the
# commit log, which meant the diff pane waiting on the list before it could
# tell delta how wide to render -- a synchronisation point between two
# processes for a number that is now arithmetic on the window width.
#
# What gives instead is the subject, which fit cuts with an ellipsis. Nothing
# is lost by that: the diff pane prints each commit's whole message above its
# diff, so the full subject is a keypress away.
sidebar_pct=35
# Past this a wider terminal is better spent on the diff; delta is side by side
# and takes all the room it is given.
sidebar_max=80
sidebar_min=34
# What the diff is left with, so the list cannot grow until delta has no room to
# show two columns.
diff_min=100

# The pane above the list: the range, the agent a comment would go to, and the
# count of what is being reviewed. Its own pane rather than three rows of the
# list, so that scrolling a long review never carries them off the top and the
# list is only ever commits.
#
# Four rows: what is being reviewed and where a comment would go, which belong
# together, then a blank line and the figures, which are a different kind of
# thing. Plus the border between the two panes, which together is what the list
# is short of the height tmux reports for the window.
header_rows=4
header_offset=$((header_rows + 1))

# The comments pane, split off the right of the diff: how wide it is drawn
# when the reader is reading it rather than glancing at the marks.
#
# These cells come from the commit list, not from the diff, and only for as
# long as the pane is open. A diff pane narrowed below the width its content
# was rendered at folds every full row onto a second line, and rows are what
# the whole plugin follows the reader by -- so the diff's width is settled
# before delta runs and never moved again. The list can afford what the diff
# cannot: what it gives up is subject, which fit already cuts, and the whole
# message is printed above the diff a keypress away.
#
# Which means this is not free at every size. Handing these over must leave the
# list sidebar_min, or the pane stays at the marks and the key says why; see
# gutter_can_expand. At 285 columns the list goes to 41 and back.
#
# Forty is a sentence at a time. Wider and the list pays for room the comments
# do not use; narrower and every comment is three rows of two words.
gutter_cells=40

# And how wide it sits when it is not expanded. Once anything is queued the pane
# is always there, narrowed to a marker beside each line that carries a comment
# -- enough to see that there is one, and where, without giving up the width to
# read it.
#
# One, which is all the mark is. Writing the last cell of a row does leave the
# cursor at the right margin, but the newline that follows only moves it down --
# the pending wrap is resolved by the next printable character, and there is
# never one. Checked on a throwaway server: a one-column pane with every cell of
# every row written, three frames over, keeps an empty history.
#
# This column, and the border beside it, are the only cells the diff ever gives
# up -- taken before delta runs, and kept whether or not anything is queued.
# Everything between this and gutter_cells is borrowed from the commit list at
# the moment the pane is opened and handed back when it closes, by restating the
# whole window layout at once rather than dragging a border. See gutter_sync.
gutter_thin=1

# How many cells the churn bar is drawn in when there is room for it. Ten is
# enough to read a ratio off and short enough to leave the figures beside it.
change_bar_cells=10

# How many rows of the pane a comment is given. One for a comment that is
# merely queued -- enough to say it is there and roughly what it says, cut with
# an ellipsis -- and five for the one being read, which is as much as can be
# spared before the comments start hiding each other. A comment longer than its
# allowance is cut, never dropped: the queue still holds it and s still sends
# it, so showing less than all of it must not look like holding less than all
# of it.
comment_rows_read=5
comment_rows_rest=1

# The mark drawn beside a line that carries a comment.
#
# Painted rather than drawn: even a full block carries the font's own padding,
# and at one column wide the mark is the whole pane, so that padding is most of
# what there is to see. A space with a background colour fills the cell exactly,
# whatever the font does. The glyph below is the uncoloured stand-in, which is
# what the tests measure and what a caller without colour would get.
mark_glyph='█'

# And the comment the reader is standing on, once the pane is widened enough to
# read the bodies. A Nerd Font speech balloon, drawn in the mark's own cell
# rather than beside it: one cell, measured, so the row it heads starts its
# text in the same column as every other row in the pane.
comment_glyph=$'\uf075'

# Tokyo Night Storm, the same values .tmux.conf uses. The commit list is
# coloured field for field like the glog alias -- red sha, green (relative
# date), bold blue <author> -- with Storm's palette standing in for git's
# named colours.
reset=$'\e[0m'
accent=$'\e[1;38;2;122;162;247m'
dim=$'\e[38;2;86;95;137m'
c_sha=$'\e[38;2;247;118;142m'
c_subject=$'\e[38;2;192;202;245m'
c_date=$'\e[38;2;158;206;106m'
c_author=$'\e[1;38;2;122;162;247m'
active=$'\e[1;38;2;192;202;245m\e[48;2;61;89;161m'
added=$'\e[38;2;158;206;106m'
removed=$'\e[38;2;247;118;142m'
# tmux/scripts/repo-icon.sh's colour for .git, so the placeholder's glyph
# matches the one the status line already shows for a repository.
c_git=$'\e[38;2;245;77;39m'

# The backgrounds the mark is painted with: a comment, the one being read, and
# -- at the pane's edges -- what is off it.
#
# The one being read is amber, which is the one colour in Storm's palette this
# plugin uses nowhere else. The commit list marks its current row in blue, and
# with the comments pane open there are two "here you are" marks on screen at
# once; telling them apart by shape alone was not enough, so they do not share
# a colour either.
mark_bg=$'\e[48;2;122;162;247m'
mark_bg_read=$'\e[48;2;224;175;104m'
# What is off screen is an arrow at the edge it lies past, rather than a mark
# of its own: collapsed, the pane is one column wide and every cell in it is
# already a comment, so another painted cell there was being counted as one.
# Measured at one cell each, which is what the collapsed pane has to give.
off_above_glyph=$'\u2191'
off_below_glyph=$'\u2193'
mark_bg_off=$'\e[48;2;86;95;137m'
# The count of what is off screen, at the foot of the pane. White, not dimmed:
# it is the only thing that says a comment exists somewhere the reader cannot
# see, and in the dim it was being missed.
c_off=$'\e[1;38;2;255;255;255m'
# The balloon at the head of the comment, drawn rather than painted: its row
# carries no bar behind it, so the glyph reads as itself and not as a notch cut
# out of the amber. The same amber as a foreground, on the pane's own ground.
c_read=$'\e[1;38;2;224;175;104m'
