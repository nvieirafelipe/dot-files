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

# How many cells the churn bar is drawn in when there is room for it. Ten is
# enough to read a ratio off and short enough to leave the figures beside it.
change_bar_cells=10

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
