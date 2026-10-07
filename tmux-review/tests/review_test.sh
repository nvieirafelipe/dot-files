#!/usr/bin/env bash
# Tests for scripts/review.sh and bin/git-review.
#
# Run: tests/review_test.sh, or run_tests from the plugin root.
#
# Only the parts that need no tmux server are exercised directly; the rest is
# covered by a smoke test over the dispatcher and by git-review against a
# throwaway repository. review.sh dispatches only when run, not when sourced,
# which is what makes this possible.
#
# The fixture variables are read by the functions under test rather than by this
# file, and the colours and tier arrays belong to the script it sources; the
# stubs are reached indirectly. SC2218 because a section that stubs a function
# puts that definition after the sections which call the real one, which reads
# from here as a function used before it is defined.
# shellcheck disable=SC2034,SC2154,SC1091,SC2317,SC2218

set -uo pipefail

# -P so this works when run through the symlink install.sh puts in
# ~/.tmux/plugins: the script under test is always the one in the checkout this
# file belongs to, not whatever the link was followed from.
here=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)
plugin=$(cd "$here/.." && pwd)
repo=$(cd "$plugin/.." && pwd)
passed=0
failed=0
skipped=0

# Whether to run the live sections. They stand real tmux servers up, open real
# reviews and take minutes; everything else needs nothing and runs in seconds.
# Both by default, so run_tests is unchanged.
#
# Apart from being quicker to iterate on, this is what lets the live sections'
# worth be measured: run_coverage --scope unit is what the tests reach without
# them, and the difference from a full run is what they add. There is no scope
# that runs the live sections alone -- it would mean gating every other section
# in the file to answer a question the subtraction already answers.
scope=${REVIEW_TEST_SCOPE:-all}
case $scope in
  all | unit) ;;
  *) printf 'REVIEW_TEST_SCOPE must be all or unit\n' >&2; exit 64 ;;
esac
want_live() { [[ $scope == all ]]; }

ok() {
  passed=$((passed + 1))
  printf '  \e[32m✓\e[0m %s\n' "$1"
}

no() {
  failed=$((failed + 1))
  printf '  \e[31m✗\e[0m %s\n' "$1"
  printf '      expected: %s\n' "${2-}"
  printf '      actual:   %s\n' "${3-}"
}

# A test the machine could not be put in a position to run: no pty to attach a
# client to, a server that would not start. Counted and printed, never passed
# over in silence -- a suite that quietly stops running the thing it was written
# for reads exactly like one where that thing still works. It is not a failure
# either: the plugin is not what went wrong, and a red suite that means "this
# machine is busy" is one nobody reads twice.
skip() {
  skipped=$((skipped + 1))
  printf '  \e[33m~\e[0m %s\n' "$1"
  printf '      skipped: %s\n' "${2-}"
}

assert_eq() {
  local label=$1 want=$2 got=$3
  if [[ $want == "$got" ]]; then
    ok "$label"
  else
    no "$label" "$want" "$got"
  fi
}

assert_match() {
  local label=$1 pattern=$2 got=$3
  if [[ $got =~ $pattern ]]; then
    ok "$label"
  else
    no "$label" "matching $pattern" "$got"
  fi
}

# For conditions that read better inline than as an expected/actual pair. The
# status is passed in rather than the condition itself, so a failing assertion
# cannot be mistaken for a failing helper -- which is what `cond && ok || no`
# risks, since it runs `no` when `ok` fails too.
assert_ok() {
  local status=$1 label=$2
  if ((status == 0)); then
    ok "$label"
  else
    no "$label" "${3-true}" "${4-false}"
  fi
}

section() { printf '\n\e[1m%s\e[0m\n' "$1"; }

# Colour escapes make assertions unreadable; the layout is what matters here.
strip() { sed -e $'s/\e\\[[0-9;]*[A-Za-z]//g'; }

# shellcheck source-path=SCRIPTDIR source=../scripts/review.sh
source "$plugin/scripts/review.sh"
# review.sh sets -e for its own sake; the runner has to survive a failing
# assertion and report it.
set +e

# Puts back every function a section stubbed.
#
# unset -f does not uncover a shadowed function, it deletes the one that is
# there, so a section that stubbed and unset left the rest of the file with no
# such function at all. Restoring from `declare -f` through eval has the same
# shape but loses the mapping back to review.sh -- the definition then belongs
# to the eval, so the coverage run reports the real one as never reached even
# while the tests exercise it. Sourcing the file again is the only restore that
# keeps both. Nothing at its top level does anything but define and assign.
restore_review() {
  # shellcheck source-path=SCRIPTDIR source=../scripts/review.sh
  source "$plugin/scripts/review.sh"
  set +e
}

# The renderers read the diffstat cache by sha. Undeclared, bash would take the
# sha for an arithmetic subscript and set -u would object to it.
declare -A stat_of=()
tmp_counts=$(mktemp)

section 'dwidth: a glyph is one cell'
dwidth 'abc'; assert_eq 'ascii is one cell a character' 3 "$REPLY"
dwidth 'héllo'; assert_eq 'an accent is still one cell' 5 "$REPLY"
# One, not two. These glyphs are drawn inside a single cell and tmux advances
# the cursor by one for each. The live section at the foot of this file measures
# that against a real server rather than restating the number here.
dwidth '󰚩'; assert_eq 'a nerd glyph is one' 1 "$REPLY"
dwidth ' ab'; assert_eq 'and counts alongside the rest' 4 "$REPLY"
dwidth ''; assert_eq 'empty is nothing' 0 "$REPLY"

section 'reserve_for: the comments pane is paid for before delta runs'
r() { reserve_for "$1"; printf '%s %s' "$REPLY" "$REPLY_GUTTER"; }
# Only the marks and their border, which is two columns of the two hundred and
# four -- not the forty the pane is read at. Those are taken from the commit
# list at the moment it is widened, so the diff never pays for them.
assert_eq 'a wide diff keeps all but the marks' '202 40' "$(r 204)"
# Exactly at the floor: diff_min is what is left, so the reserve still stands.
assert_eq 'and keeps giving them down to the floor' '100 40' "$(r 102)"
# One column short of it. Taking the reserve here would leave delta too little
# to show two columns, which is worse than having no comments pane.
assert_eq 'a column below the floor takes nothing' '101 0' "$(r 101)"
assert_eq 'and a narrow window keeps the whole diff' '80 0' "$(r 80)"
unset -f r

section 'review_layout: the window written the way select-layout reads it'
# The three strings below are not constructed here -- they were read off a real
# tmux server built into the review's shape with display-message -p
# '#{window_layout}', and pasted in. A layout tmux did not write is worth
# nothing as an expectation: the checksum is the whole point, and a checksum
# agreeing with itself proves only that this file can add.
layout_csum '285x78,0,0{80x78,0,0[80x4,0,0,1,80x73,0,5,2],204x78,81,0,0}'
assert_eq 'the checksum is tmux own, reimplemented' '9702' "$REPLY"
review_layout 285 78 80 204 0 %1 %2 %0 %3
assert_eq 'a window with no comments pane' \
  '9702,285x78,0,0{80x78,0,0[80x4,0,0,1,80x73,0,5,2],204x78,81,0,0}' "$REPLY"
review_layout 285 78 80 202 1 %1 %2 %0 %3
assert_eq 'the marks take two columns off the diff' \
  '400a,285x78,0,0{80x78,0,0[80x4,0,0,1,80x73,0,5,2],202x78,81,0,0,1x78,284,0,3}' "$REPLY"
# The one that matters: the diff is the same 202 it was, and the thirty-nine
# came out of the list. Checked against tmux by applying it, in the live
# section below.
review_layout 285 78 41 202 40 %1 %2 %0 %3
assert_eq 'and reading them is paid for by the list, not the diff' \
  '7dc3,285x78,0,0{41x78,0,0[41x4,0,0,1,41x73,0,5,2],202x78,42,0,0,40x78,245,0,3}' "$REPLY"

section 'sidebar_max_for: how wide the list may be drawn before the diff folds'
# With no comments pane the diff pane holds two columns it is not drawing on --
# the pair reserved for the marks -- so the list may take those two and no more.
sidebar_max_for 285 0
assert_eq 'the two columns held back for the marks, and nothing else' 82 "$REPLY"
# Once the marks are up the diff pane is exactly its content, so there is
# nothing spare left to take.
sidebar_max_for 285 1
assert_eq 'with the marks up there is nothing spare at all' 80 "$REPLY"
# Expanded, the list has already handed over thirty-nine and cannot take them
# back while the comment is still being read.
sidebar_max_for 285 40
assert_eq 'and while a comment is open it is what the layout left it' 41 "$REPLY"
# A narrow window still leaves a little: 120 gives the list 34, delta 83, and
# the border one, so two columns are spare.
sidebar_max_for 120 0
assert_eq 'a narrow window leaves what little it has' 36 "$REPLY"

section 'diff_pinned_for: the width the diff is held at for good'
diff_pinned_for 285
assert_eq 'the window less the list, the marks and two borders' 202 "$REPLY"
# Independent of how wide the comments pane is at the time, which is what lets
# the layout state it rather than work it out from what is left over.
diff_pinned_for 200
assert_eq 'and it follows the window down' $((200 - 70 - 3)) "$REPLY"

section 'columns_for: a share of the window, then the clamps'
# Depends on the window alone -- which is what lets open settle the layout
# before either pane exists, and the commits be measured by nobody.
columns_for 200
assert_eq 'a share of the window' $((200 * sidebar_pct / 100)) "$REPLY"
columns_for 160
assert_eq 'and it follows the window down' $((160 * sidebar_pct / 100)) "$REPLY"
columns_for 1000
assert_eq 'capped, so a wide terminal goes to the diff' "$sidebar_max" "$REPLY"
columns_for 140
assert_eq 'bounded so the diff keeps diff_min' $((140 - diff_min - 1)) "$REPLY"
columns_for 100
assert_eq 'never below sidebar_min' "$sidebar_min" "$REPLY"
columns_for 0
assert_eq 'a window with no width still answers the floor' "$sidebar_min" "$REPLY"

section 'fit: pads and truncates by column'
fit 'abc' 6; assert_eq 'pads to width' 'abc   ' "$REPLY"
fit 'abcdef' 4; assert_eq 'truncates with an ellipsis' 'abc…' "$REPLY"
fit 'abc def' 5; assert_eq 'trims space before the ellipsis' 'abc… ' "$REPLY"
fit 'héllo wörld' 8; assert_eq 'counts characters, not bytes' 8 "${#REPLY}"
fit 'abc' 0; assert_eq 'zero width is empty' '' "$REPLY"
fit '' 3; assert_eq 'empty input still pads' '   ' "$REPLY"
fit '󰚩 ok' 8; dwidth "$REPLY"
assert_eq 'a glyph row is padded to its column width' 8 "$REPLY"
fit '󰚩󰚩󰚩󰚩' 5; dwidth "$REPLY"
assert_eq 'and truncated by column, not by character' 5 "$REPLY"

section 'render_legend: takes the widest form that fits'
render_legend 101 diff legend_diff_tiers
assert_eq 'widest diff form at 101' \
  'diff  jk line  n/N any  ][ file  }{ commit  =<> fold  c comment  s send' "$(strip <<<"$REPLY")"
render_legend 30 diff legend_diff_tiers
assert_eq 'narrowest diff form at 30' 'diff  n/N any  c comment' "$(strip <<<"$REPLY")"
render_legend 101 agent legend_session_tiers
# Only what the header pane answers to. c and s are the list's and the diff's;
# listing them on a legend shown while the reader is somewhere they do nothing
# is worse than listing nothing.
assert_match 'the agent row names the keys of the pane it belongs to' \
  'enter pick the agent.*k range.*q close' "$(strip <<<"$REPLY")"
assert_eq 'and not the comment keys, which are not up there' 0 \
  "$(strip <<<"$REPLY" | grep -c 'c comment')"
render_legend 101 list legend_list_tiers
assert_match 'list form names the page and end keys' 'PgUp/PgDn page.*gg/G first/last' "$(strip <<<"$REPLY")"
# A group is split on its last = rather than its first: the fold keys are = < >,
# and split on the first the key came out empty and the label kept the rest.
eq_tiers=('==toggle|=<>=fold|c=comment')
render_legend 80 x eq_tiers
assert_eq 'a key that is itself an equals sign keeps its name' \
  'x  = toggle  =<> fold  c comment' "$REPLY_PLAIN"
unset eq_tiers
render_legend 120 list legend_list_tiers
assert_match 'the list offers the fold keys when there is room' '=<> fold' "$REPLY_PLAIN"
render_legend 120 list legend_list_c_tiers
assert_match 'and so it does with something queued' '=<> fold' "$REPLY_PLAIN"
render_legend 120 diff legend_diff_c_tiers
assert_match 'and so does the diff' '=<> fold' "$REPLY_PLAIN"
render_legend 120 diff legend_diff_search_tiers
assert_match 'searching or not' '=<> fold' "$REPLY_PLAIN"
render_legend 200 diff legend_diff_tiers
# A substring test, not a pattern: the escapes are full of regex metacharacters.
coloured=0; [[ $REPLY == *"$c_subject"jk"$reset"* ]] || coloured=1
assert_ok "$coloured" 'keys are coloured'
dimmed=0; [[ $REPLY == *"$dim"line"$reset"* ]] || dimmed=1
assert_ok "$dimmed" 'labels are dim'
# A legend that overflows wraps, and a wrapped row costs a line the layout has
# already given away -- so this is checked for both rows at every plausible
# width, not just at the ones the tiers were written for.
# REPLY_PLAIN rather than stripping the escapes back out: 200 widths across
# three sets is 600 iterations, and a sed for each of them made the suite crawl.
for tiers in legend_diff_tiers legend_list_tiers legend_range_tiers; do
  wrapped=0
  for w in $(seq 8 200); do
    render_legend "$w" xx "$tiers"
    ((${#REPLY_PLAIN} <= w - 1)) || { wrapped=$w; break; }
  done
  assert_eq "$tiers fits every width from 8 to 200" 0 "$wrapped"
done

section 'pick_target: the next stop in the direction asked for'
rows='2 40 90 150'
pick_target next 0 "$rows"
assert_eq 'next from before the first' 2 "$REPLY"
pick_target next 2 "$rows"
assert_eq 'next skips the row it is on' 40 "$REPLY"
pick_target next 41 "$rows"
assert_eq 'next from between two stops' 90 "$REPLY"
pick_target next 150 "$rows"
assert_eq 'next past the last is empty' '' "$REPLY"
pick_target prev 150 "$rows"
assert_eq 'prev from the last' 90 "$REPLY"
pick_target prev 89 "$rows"
assert_eq 'prev from inside a section' 40 "$REPLY"
pick_target prev 2 "$rows"
assert_eq 'prev before the first is empty' '' "$REPLY"
pick_target first 99 "$rows"
assert_eq 'first' 2 "$REPLY"
pick_target last 0 "$rows"
assert_eq 'last' 150 "$REPLY"
pick_target next 0 '7'
assert_eq 'a single stop still answers' 7 "$REPLY"
pick_target next 0 ''
assert_eq 'no stops at all is empty' '' "$REPLY"

section 'current_index: the commit whose header is last at or above the cursor'
shas=(c0 c1 c2)
declare -A row_of=([c0]=2 [c1]=50 [c2]=90)
current_index 0
assert_eq 'above the first header still selects the first' 0 "$REPLY"
current_index 2
assert_eq 'on the first header' 0 "$REPLY"
current_index 49
assert_eq 'inside the first section' 0 "$REPLY"
current_index 50
assert_eq 'on the second header' 1 "$REPLY"
current_index 4000
assert_eq 'inside the last section' 2 "$REPLY"
current_index -1
assert_eq 'no position selects the newest' 2 "$REPLY"
row_of=([c1]=50)
current_index 60
assert_eq 'a partial map skips commits without a row' 1 "$REPLY"
row_of=()
current_index 60
assert_eq 'an empty map selects the newest' 2 "$REPLY"
unset row_of

section 'read_key: one keypress, resolved to a name'
# It answers in REPLY rather than on stdout: read through $(...) it forked once
# a tick, pressed or not. The subshell here is the test's, not the loop's.
# %b so the escape sequences in the cases below arrive as the bytes a terminal
# would send, not as backslash-e.
key_of() { printf '%b' "$1" | { read_key || true; printf '%s' "$REPLY"; }; }
assert_eq 'j'            j         "$(key_of 'j')"
assert_eq 'k'            k         "$(key_of 'k')"
assert_eq 'n'            n         "$(key_of 'n')"
assert_eq 'N'            N         "$(key_of 'N')"
assert_eq 'q'            q         "$(key_of 'q')"
assert_eq 'close bracket' ']'      "$(key_of ']')"
assert_eq 'open bracket'  '['      "$(key_of '[')"
assert_eq 'G is the last commit' last "$(key_of 'G')"
assert_eq 'gg is the first commit' first "$(key_of 'gg')"
assert_eq 'a lone g does nothing' '' "$(key_of 'g')"
assert_eq 'up arrow'     k         "$(key_of '\e[A')"
assert_eq 'down arrow'   j         "$(key_of '\e[B')"
assert_eq 'page up'      page_up   "$(key_of '\e[5~')"
assert_eq 'page down'    page_down "$(key_of '\e[6~')"
assert_eq 'home as 1~'   first     "$(key_of '\e[1~')"
assert_eq 'end as 4~'    last      "$(key_of '\e[4~')"
assert_eq 'home as SS3 H' first    "$(key_of '\eOH')"
assert_eq 'end as SS3 F'  last     "$(key_of '\eOF')"
assert_eq 'a bare escape asks to go back' cancel "$(key_of '\e')"
assert_eq 'carriage return is enter' enter "$(key_of '\r')"
assert_eq 'a newline is enter too' enter "$(key_of '\n')"
# z is the key this plugin wakes a pane with, so it has to survive read_key --
# the header pane redraws on it. It means nothing in the list's own loop.
assert_eq 'the wake key comes through' z "$(key_of 'z')"
assert_eq 'an unbound letter is nothing' '' "$(key_of 'Z')"
assert_eq 'an unknown sequence is nothing' '' "$(key_of '\e[Z')"
read_key </dev/null
assert_eq 'no input at all reports the tick' 1 "$?"
unset -f key_of

section 'the header pane: the range, the agent and what the range comes to'
range='base..HEAD'
shas=(c0 c1 c2)
subs=(s0 s1 s2)
whens=('1 hour ago' '1 hour ago' '1 hour ago')
authors=(A A A)
needs_clear=0
build_rows 60
git() { :; }

change_ins='' change_del=''
hdr=$(render_header 60 | strip)
assert_match 'the range is the first row' 'base\.\.HEAD' "$hdr"
assert_match 'where a comment would go is the second' 'no agent selected' "$hdr"
assert_match 'and what is being reviewed the third' '3 commits' "$hdr"
assert_eq 'four rows, which is the height the pane is given' 4 "$(grep -c '' <<<"$hdr")"
assert_eq 'the blank one sits between the agent and the figures' '' \
  "$(sed -n '3p' <<<"$hdr")"

# The figures for the whole range, which is what this pane is for -- the list's
# own footer counts the commit under the cursor, in the same +/- shorthand, so
# this row is deliberately a different shape: the count, then the churn as a
# bar, then the totals.
change_ins=120 change_del=45
hdr=$(render_header 60 | strip)
assert_match 'the bar leads, then the totals, then the count' \
  '█+  \+120 -45  3 commits' "$hdr"
assert_eq 'insertions are drawn in the added colour' 1 \
  "$(render_header 60 | grep -cF -- "$added+120")"
assert_eq 'deletions in the removed one' 1 \
  "$(render_header 60 | grep -cF -- "$removed-45")"
change_del=''
assert_match 'a range that only adds says only that' '█+  \+120  3 commits$' \
  "$(render_header 60 | strip)"
change_ins='' change_del=45
assert_match 'and one that only deletes, the other way about' '█+  -45  3 commits$' \
  "$(render_header 60 | strip)"
change_ins='' change_del=''
assert_eq 'before the shortstat lands there are no figures at all' 0 \
  "$(render_header 60 | strip | grep -c '+')"
assert_match 'which leaves the count on its own' '3 commits' "$(render_header 60 | strip)"

# The bar is the churn split green to red, and neither end is rounded away.
change_bar 120 45 10
assert_eq 'ten cells, whatever the ratio' 10 "${#REPLY_PLAIN}"
assert_eq 'seven of them green at roughly three to one' 1 \
  "$(grep -cF -- "${added}███████$reset" <<<"$REPLY_COL")"
change_bar 1000 1 10
assert_eq 'a single deleted line still keeps a cell' 1 \
  "$(grep -cF -- "${removed}█$reset" <<<"$REPLY_COL")"
change_bar 1 1000 10
assert_eq 'and a single added one too' 1 \
  "$(grep -cF -- "${added}█$reset" <<<"$REPLY_COL")"
change_bar 0 300 10
assert_eq 'a range that only deletes is all red' 1 \
  "$(grep -cF -- "${removed}██████████$reset" <<<"$REPLY_COL")"
change_bar 0 0 10
assert_eq 'nothing changed draws no bar' '' "$REPLY_PLAIN"

# The bar is the first thing dropped when the pane is too narrow for it.
change_ins=120 change_del=45
assert_eq 'a narrow pane keeps the figures and loses the bar' 0 \
  "$(render_header 26 | strip | grep -c '█')"
assert_match 'which are what it is there to say' '\+120 -45  3 commits' \
  "$(render_header 26 | strip)"
change_ins='' change_del=''

# Which part of a long review is on screen, passed in by whoever drew the list.
change_ins=120 change_del=45
assert_match 'the slice is named when the list overflows' '3 commits  2-9' \
  "$(render_header 60 0 0 1 8 | strip)"
change_ins='' change_del=''
assert_eq 'and not when it all fits' 0 "$(render_header 60 0 0 -1 -1 | strip | grep -c -- '-')"

sel=$(render_header 60 1 0 | grep -F -- "$active" | strip)
assert_match 'the range row is highlighted when it is selected' 'base\.\.HEAD' "$sel"
assert_eq 'and it is the only one' 1 "$(render_header 60 1 0 | grep -cF -- "$active")"
sel=$(render_header 60 0 1 | grep -F -- "$active" | strip)
assert_match 'the agent row when that one is' 'no agent selected' "$sel"
assert_eq 'never both' 1 "$(render_header 60 0 1 | grep -cF -- "$active")"
assert_eq 'and neither when the reader is in the list' 0 \
  "$(render_header 60 0 0 | grep -cF -- "$active")"

# paint_header is what decides whether any of that is worth writing. It is
# called every turn round the loop, so the answer is usually no.
#
# Two files, as there are two in a review: the pane's tty, which it writes a
# frame to, and the state file it leaves all three frames in for the header
# pane to move its own highlight with.
hdr_out=$(mktemp)
hdr_file=$(mktemp)
hdr_tty=$hdr_out
shown_header=''
needs_header_clear=1
width=60 height=0 on_range=0 on_session=0 comments=0
paint_header 60
assert_match 'the first call paints' 'base\.\.HEAD' "$(strip <"$hdr_out")"
assert_eq 'and leaves all three frames where the header can reach them' 2 \
  "$(tr -cd '\036' <"$hdr_file" | wc -c | tr -d ' ')"
: >"$hdr_out"
paint_header 60
assert_eq 'the next call, with nothing changed, does not' '' "$(<"$hdr_out")"
comments=2
paint_header 60
assert_match 'a comment queued is a change worth painting' '2 queued' "$(strip <"$hdr_out")"

# One painter at a time. While the reader is up there the header pane has a
# cursor of its own and moves it on the keypress; this loop is a tick behind,
# so painting from here would put the highlight back where it had been.
: >"$hdr_out"
hdr_poke=''
tmux() { hdr_poke+="[$*]"; return 0; }
hdr_pane='%2'
on_session=1
paint_header 60
assert_eq 'with the reader up there it paints nothing itself' '' "$(<"$hdr_out")"
assert_match 'and asks that pane to redraw instead, since the row is its own' \
  'send-keys -t %2 z' "$hdr_poke"
assert_match 'the frames are still left for it to redraw from' 'base\.\.HEAD' \
  "$(strip <"$hdr_file")"
on_session=0
paint_header 60
assert_match 'once the reader leaves it draws the pane again' 'base\.\.HEAD' \
  "$(strip <"$hdr_out")"
assert_eq 'with nothing highlighted, because nothing up there is selected' 0 \
  "$(grep -cF -- "$active" "$hdr_out")"
unset -f tmux
unset hdr_pane hdr_poke

# The frames the header moves between: one per row that can be selected, and
# none of them ending in a newline -- printed on the bottom row of a pane that
# is exactly as tall as the frame, that would scroll the range line off it.
for sel in none range agent; do
  frame=$(paint_sel "$hdr_file" "$sel")
  assert_eq "the $sel frame is the whole pane" 4 "$(grep -c '' <<<"$frame")"
  assert_eq "and the $sel frame ends without a newline" "${frame%$'\n'}" "$frame"
done
assert_eq 'nothing is highlighted on the none frame' 0 \
  "$(paint_sel "$hdr_file" none | grep -cF -- "$active")"
assert_eq 'the range frame lights its first row' 1 \
  "$(paint_sel "$hdr_file" range | sed -n 1p | grep -cF -- "$active")"
assert_eq 'and the agent frame its second' 1 \
  "$(paint_sel "$hdr_file" agent | sed -n 2p | grep -cF -- "$active")"
assert_eq 'a state file that is not there paints nothing' '' \
  "$(paint_sel "$hdr_file.gone" range)"

: >"$hdr_out"
# With a height and a selection it names the slice on screen, which is the one
# thing on the header that the list decides.
height=5
paint_header 60 0
assert_match 'the slice comes from the list it is drawn above' '3 commits  1-1' \
  "$(strip <"$hdr_out")"
height=0
: >"$hdr_out"
hdr_tty=''
paint_header 60
assert_eq 'a loop with nowhere to paint writes nothing at all' '' "$(<"$hdr_out")"
hdr_tty=$hdr_out
paint_header 0
assert_eq 'and neither does one that does not know its width yet' '' "$(<"$hdr_out")"
rm -f "$hdr_out" "$hdr_file"
unset hdr_tty hdr_file shown_header needs_header_clear width height
on_range=0; on_session=0; comments=0

# The list pane keeps the legend, and shows no selection of its own while one
# of the header rows has it.
rendered=$(render 0 60 20 list 1 | strip)
assert_match 'the range legend is shown instead of the list one' 'range  enter pick' "$rendered"
assert_eq 'and the list legend is not' 0 "$(grep -c 'list  jk commit' <<<"$rendered")"
# The list keeps its own cursor whatever the pane above is doing: they are two
# panes with two cursors, and the commit under the diff is still the commit
# under the diff.
sel=$(render 0 60 20 list 1 | grep -F -- "$active" | strip)
assert_match 'the commit stays highlighted while the range row is selected' 'c0' "$sel"
assert_eq 'and it is still the only highlight in this pane' 1 \
  "$(render 0 60 20 list 1 | grep -cF -- "$active")"
sel=$(render 0 60 20 list 0 | grep -F -- "$active" | strip)
assert_match 'the first commit is highlighted with nothing selected above' 'c0' "$sel"
assert_eq 'and no range row is drawn in this pane at all' 0 \
  "$(render 0 60 20 list 0 | strip | grep -c 'base\.\.HEAD')"

# The list cannot be walked up out of. The range and the agent are another
# pane, reached the way any pane is; every key here steps the diff or the list
# and nothing else.
select_index() { stub_index=$1; }
jump() { stub_jump="$*"; }
height=20
pub_commits='2 40'; pub_files='5 9'; pub_stops='2 5 9 40'
stub_index=''; stub_jump=''

on_range=0; on_session=0
steer p k 0 100 100 0
assert_eq 'k on the first commit selects nothing above it' '0 0' "$on_range $on_session"
assert_match 'it asks the diff for the previous commit, as it does anywhere else' \
  'prev' "$stub_jump"
stub_jump=''
steer p k 2 100 100 0
assert_eq 'and from further down, the same' '0 0' "$on_range $on_session"
assert_match 'the diff moves' 'prev' "$stub_jump"
stub_jump=''
steer p j 0 100 100 0
assert_match 'j is the next commit, never a row above' 'next' "$stub_jump"
assert_eq 'and touches neither header row' '0 0' "$on_range $on_session"

# The header's own rows are decided in the header pane and read off the window,
# so steer leaves them alone even when they are set.
on_range=1; on_session=0
stub_jump=''
steer p k 0 100 100 0
assert_eq 'a selection up there is not for steer to clear' 1 "$on_range"
on_range=0; on_session=1
steer p n 0 100 100 0
assert_eq 'nor the agent row' 1 "$on_session"
on_range=0; on_session=0

unset -f git
restore_review
unset stub_index stub_jump

section 'the diffstat is read once, for the whole range'
declare -a c_shas=() c_subs=() c_whens=() c_authors=()
# Two passes, not one: the fields go out to the diff pane as the width it has
# to size delta to, and the diffstat is read behind that rather than in front
# of it.
(
  shas=(); subs=(); whens=(); authors=(); declare -A stat_of=()
  load_commits 'HEAD~3..HEAD'
  load_stats 'HEAD~3..HEAD'
  printf '%s\n' "${#shas[@]}" "${#stat_of[@]}"
) > "$tmp_counts" 2>/dev/null || true
read -r n_commits n_stats < <(tr '\n' ' ' < "$tmp_counts")
assert_eq 'three commits were read' 3 "${n_commits:-0}"
assert_eq 'and a diffstat for each of them' 3 "${n_stats:-0}"

section 'the range line: no list movement leads anywhere from it'
select_index() { stub_index=$1; }
jump() { stub_jump="$*"; }
height=20
pub_commits='2 40'; pub_files='5 9'; pub_stops='2 5 9 40'
# Every list key goes on meaning what it means, whatever is selected in the
# pane above: that selection is another pane's cursor and steer never reads it.
for key in first last page_up page_down k; do
  on_range=1; stub_index=''; stub_jump=''
  steer p "$key" 0 100 100 0
  assert_eq "$key still drives the list with the range row selected" 1 \
    "$([[ -n $stub_index$stub_jump ]] && echo 1 || echo 0)"
  assert_eq "and $key leaves that selection alone" 1 "$on_range"
done
restore_review

section 'the picker: what it offers and how it moves'
declare -a pick_kind pick_label pick_extra pick_payload
pick_cwd=$PWD
pick_repo=$(mktemp -d)
(
  cd "$pick_repo" || exit 1
  git init -q -b docs .
  git config user.email t@example.com
  git config user.name Test
  # The user's own config signs every commit; this identity has no key.
  git config commit.gpgsign false
  for n in 1 2 3; do echo "$n" > "doc$n"; git add "doc$n"; git commit -qm "doc $n"; done
) >/dev/null 2>&1
# Every column of every item, an item a line, so a whole picker is compared at
# once rather than the parts of it a test remembered to look at.
picked() {
  local i
  for i in "${!pick_kind[@]}"; do
    printf '%s|%s|%s|%s\n' "${pick_kind[i]}" "${pick_label[i]}" "${pick_extra[i]}" \
      "${pick_payload[i]}"
  done
}
pick_in_repo() { cd "$pick_repo" || return; load_pick_items "$1"; cd "$pick_cwd" || :; }

# Clean, one branch, no remote: the repository this was written for. The only
# branch is the one being reviewed and the tree has nothing in it, so there is
# nothing to offer beyond the range itself and the two ways to type another.
pick_in_repo 'HEAD'
assert_eq 'a clean repository with one branch offers only what resolves' \
  'range|outstanding|HEAD|
prompt-count|last n commits|1-3|3
prompt-range|a range|asks|HEAD' "$(picked)"

# A branch behind HEAD has commits since it and one ahead has none. A change to
# a tracked file is uncommitted, and a staged one is in the index as well.
(
  cd "$pick_repo" || exit 1
  git branch older HEAD~1
  git checkout -q -b ahead && echo 4 > doc4 && git add doc4 && git commit -qm 'doc 4'
  git checkout -q docs
  echo changed > doc1
  echo staged > doc2 && git add doc2
  echo untracked > loose
) >/dev/null 2>&1
pick_in_repo 'HEAD'
assert_eq 'what has something in it is offered, and only that' \
  'range|outstanding|HEAD|
prompt-count|last n commits|1-3|3
prompt-range|a range|asks|HEAD
sep|||
wip|uncommitted|working tree|
staged|staged|index|
sep|||
range|older|since|older' "$(picked)"
assert_eq 'the arrays stay the same length' \
  "${#pick_kind[@]} ${#pick_kind[@]} ${#pick_kind[@]}" \
  "${#pick_label[@]} ${#pick_extra[@]} ${#pick_payload[@]}"

# Unstaged alone is the working tree and not the index. An untracked file is
# neither, because the working tree review is git diff HEAD and never shows one.
git -C "$pick_repo" reset -q doc2 >/dev/null 2>&1
pick_in_repo 'HEAD'
assert_eq 'a change that is not staged offers no index' \
  'range prompt-count prompt-range sep wip sep range' "${pick_kind[*]}"
git -C "$pick_repo" checkout -q -- doc1 doc2 >/dev/null 2>&1
pick_in_repo 'HEAD'
assert_eq 'an untracked file offers no working tree' \
  'range prompt-count prompt-range sep range' "${pick_kind[*]}"
rm -rf "$pick_repo"
unset -f picked pick_in_repo
unset pick_cwd pick_repo

# Separators are items, so that the list can be grouped without the renderer
# knowing where the groups are -- which means seeking has to step over them.
pick_kind=(range sep range sep sep range)
pick_seek 1 1
assert_eq 'seeking forward from a separator' 2 "$REPLY"
pick_seek 3 1
assert_eq 'seeking forward over two separators' 5 "$REPLY"
pick_seek 3 -1
assert_eq 'seeking back from a separator' 2 "$REPLY"
pick_seek 0 1
assert_eq 'seeking stays put on a real item' 0 "$REPLY"
pick_seek 9 1
assert_eq 'seeking past the end clamps' 5 "$REPLY"
pick_seek -3 -1
assert_eq 'seeking past the start clamps' 0 "$REPLY"

pick_kind=(range prompt-count sep wip)
pick_label=(outstanding 'last n commits' '' uncommitted)
pick_extra=('base..HEAD' asks '' 'working tree')
pick_payload=('' '' '' '')
out=$(render_picker 60 20 0 | strip)
assert_match 'the picker says what it is' 'review' "$out"
assert_match 'and how to use it' 'enter chooses' "$out"
assert_match 'the first item is listed' 'outstanding' "$out"
assert_match 'the second column is listed' 'base\.\.HEAD' "$out"
assert_match 'a separator draws a rule' '───' "$out"
# -F: the escape that marks the selected row is full of regex metacharacters.
sel=$(render_picker 60 20 0 | grep -cF -- "$active")
assert_eq 'exactly one row is selected' 1 "$sel"
sel=$(render_picker 60 20 3 | grep -cF -- "$active")
assert_eq 'still exactly one when the selection moves' 1 "$sel"
first=$(render_picker 60 20 0 | grep -F -- "$active" | strip)
last=$(render_picker 60 20 3 | grep -F -- "$active" | strip)
assert_match 'the first item is selected at index 0' 'outstanding' "$first"
assert_match 'the last item is selected at its index' 'uncommitted' "$last"
unset pick_kind pick_label pick_extra pick_payload

section 'build_rows: fixed columns, subject gives way first'
shas=(aaaaaaa bbbbbbb)
subs=('a short subject' 'a subject long enough that it will certainly have to be cut down')
whens=('2 hours ago' '25 minutes ago')
authors=('Ada Lovelace' 'Grace Hopper')
build_rows 76
assert_eq 'one row per commit' 2 "${#rows_plain[@]}"
assert_eq 'rows are exactly the pane width' 76 "${#rows_plain[0]}"
assert_eq 'every row is the same width' 76 "${#rows_plain[1]}"
assert_match 'sha then subject' '^ aaaaaaa  a short subject ' "${rows_plain[0]}"
assert_match 'long subject is cut with an ellipsis' '…' "${rows_plain[1]}"
assert_match 'date in parentheses' '\(2 hours ago\)' "${rows_plain[0]}"
assert_match 'author in angle brackets' '<Ada Lovelace>' "${rows_plain[0]}"
assert_match 'date column is aligned' '\(25 minutes ago\)' "${rows_plain[1]}"
build_rows 40
assert_eq 'narrower pane still fills exactly' 40 "${#rows_plain[0]}"
assert_match 'author survives a narrow pane' '<' "${rows_plain[0]}"

# git abbreviates to whatever is unique in the repository. Fixed at seven, one
# that needs nine built every row two columns over the pane width, and the tail
# of the author field folded onto a line of its own.
shas=(aaaaaaaaa bbbbbbbbb)
build_rows 76
assert_eq 'a nine-column sha still fills exactly' 76 "${#rows_plain[0]}"
assert_match 'and is not cut back to seven' '^ aaaaaaaaa  ' "${rows_plain[0]}"
assert_eq 'the measured width is what the diff pane is sized from' 9 "$want_sha"
shas=(aaaaaaa bbbbbbb)
build_rows 76

section 'render: the viewport follows the selection'
range='base..HEAD'
shas=(c0 c1 c2 c3 c4 c5 c6 c7 c8 c9)
subs=(s0 s1 s2 s3 s4 s5 s6 s7 s8 s9)
whens=('1 hour ago' '1 hour ago' '1 hour ago' '1 hour ago' '1 hour ago'
       '1 hour ago' '1 hour ago' '1 hour ago' '1 hour ago' '1 hour ago')
authors=(A A A A A A A A A A)
needs_clear=0
build_rows 60
# git show is stubbed: the footer's diffstat is not what these assert on.
git() { :; }
# height 12 leaves eight rows for the list: two rules, the stat and one key
# row. The range, the agent and the count are the header pane's, so they take
# none of this one -- which is four more rows of commits than the same height
# used to show.
out=$(render 0 60 12 diff | strip)
assert_match 'starts at the first commit' 'c0' "$out"
assert_eq 'last visible row is the eighth' 1 "$(grep -c ' c7 ' <<<"$out")"
assert_eq 'the ninth is off screen' 0 "$(grep -c ' c8 ' <<<"$out")"
assert_eq 'nothing above the list is drawn here any more' 0 \
  "$(grep -cE 'base\.\.HEAD|no agent selected|10 commits' <<<"$out")"
out=$(render 9 60 12 diff | strip)
assert_eq 'the first is off screen once the selection is at the end' 0 \
  "$(grep -c ' c0 ' <<<"$out")"
assert_match 'and the last is on it' 'c9' "$out"

# The slice the header names comes from the same arithmetic the list draws
# with, so the two cannot disagree about what is on screen.
list_rows 12
assert_eq 'eight rows of commits at that height' 8 "$REPLY"
list_slice 0 8
assert_eq 'at the top the slice starts at the first commit' '0 7 1' \
  "$SLICE_FIRST $SLICE_LAST $SLICE_PARTIAL"
list_slice 9 8
assert_eq 'at the end it clamps' '2 9 1' "$SLICE_FIRST $SLICE_LAST $SLICE_PARTIAL"
list_slice 5 8
assert_eq 'and in the middle it centres' '1 8 1' "$SLICE_FIRST $SLICE_LAST $SLICE_PARTIAL"
list_slice 0 20
assert_eq 'a list that fits is not a slice at all' '0 9 0' \
  "$SLICE_FIRST $SLICE_LAST $SLICE_PARTIAL"

section 'gutter_key: every key handed to the list, none answered here'
sent=''
tmux() { sent+="[$*]"; return 0; }
gutter_key %9 j
assert_eq 'j goes over as it was pressed' '[send-keys -t %9 j]' "$sent"
sent=''; gutter_key %9 first
assert_eq 'a name read_key resolved becomes a key tmux can send' \
  '[send-keys -t %9 Home]' "$sent"
sent=''; gutter_key %9 page_down
assert_eq 'and so does a page key' '[send-keys -t %9 PageDown]' "$sent"
sent=''; gutter_key %9 C
assert_eq 'C goes over too, which closes this very pane' '[send-keys -t %9 C]' "$sent"
sent=''; gutter_key %9 R
assert_eq 'and so does the key that empties the queue' '[send-keys -t %9 R]' "$sent"
sent=''; gutter_key %9 '='
assert_eq 'the fold keys go over, since the diff they act on is beside it' \
  '[send-keys -t %9 =]' "$sent"
sent=''; gutter_key %9 '<'
assert_eq 'all three of them' '[send-keys -t %9 <]' "$sent"
sent=''; gutter_key %9 '>'
assert_eq 'all three, not two' '[send-keys -t %9 >]' "$sent"
sent=''; gutter_key %9 cancel
assert_eq 'a bare escape is not a key the list knows' '' "$sent"
sent=''; gutter_key %9 z
assert_eq 'and neither is the wake key, which means nothing here' '' "$sent"
unset -f tmux
unset sent

section 'gutter_want: nothing, the marks, or the whole pane'
comments=0
gutter_reserved=40
gutter_expanded=0
gutter_want 285
assert_eq 'an empty queue wants no pane at all' 0 "$REPLY"
comments=2
gutter_want 285
assert_eq 'something queued wants the column of marks' 1 "$REPLY"
gutter_expanded=1
gutter_want 285
assert_eq 'and expanded wants every cell held back for it' 40 "$REPLY"
# Expanding is paid for by the commit list, so a window whose list cannot
# spare the difference does not get to expand. At 200 the list is 70, and
# giving up thirty-nine would leave 31 -- under sidebar_min, which is where the
# list stops being able to say which commit is which.
gutter_want 200
assert_eq 'a list that cannot afford it stays at the marks' 1 "$REPLY"
# The narrowest window that can afford it: at 209 the list is 73, and 73 less
# the thirty-nine is exactly sidebar_min. One column narrower and it is not.
gutter_want 209
assert_eq 'the narrowest window that can afford it does expand' 40 "$REPLY"
gutter_want 208
assert_eq 'and one column under that cannot' 1 "$REPLY"
# Refused, not deferred: collapsed is a state the caller can be left in, and
# the reader pressed a key that did nothing rather than one that half-worked.
gutter_expanded=0
gutter_want 200
assert_eq 'collapsed at that width is the marks either way' 1 "$REPLY"
# A window too narrow for the reserve has none to give, however much is queued.
gutter_reserved=0
gutter_want 285
assert_eq 'with nothing reserved there is nothing to want' 0 "$REPLY"
unset comments gutter_reserved gutter_expanded

section 'gutter_can_expand: whether the commit list can pay for it'
# The same rule as gutter_want above, in the one place both its callers read it
# from: the key that opens the pane has to say no out loud, and gutter_want has
# to hold the pane at the marks if it was opened anyway. Two copies of an
# arithmetic like this drift, and the shape they drift into is a pane that
# reports itself open and is not.
gutter_reserved=40
gutter_can_expand 285
assert_eq 'a wide window can' 0 "$?"
gutter_can_expand 209
assert_eq 'and so can the narrowest that leaves the list sidebar_min' 0 "$?"
gutter_can_expand 208
assert_eq 'one column under that cannot' 1 "$?"
gutter_can_expand 200
assert_eq 'nor can a window narrower still' 1 "$?"
# Nothing was reserved, so there is nothing to expand into at any width.
gutter_reserved=0
gutter_can_expand 285
assert_eq 'and with nothing reserved there is nothing to expand' 1 "$?"
unset gutter_reserved

section 'gutter_sync: split, resized, or taken away'
# Logged to a file, not an array: the split runs inside a process substitution,
# which is a subshell, and anything it appends to a variable is gone with it.
tmux_log=$(mktemp)
calls() { cat "$tmux_log"; }
# layout_now is what the stub server believes its window looks like, which
# gutter_sync checks before it restates it.
layout_now=''
tmux() {
  printf '[%s]' "$*" >>"$tmux_log"
  [[ $1 == split-window ]] && printf '%%9 /dev/ttys9'
  [[ $1 == display-message && $* == *window_layout* ]] && printf '%s' "$layout_now"
  return 0
}
self=/plugin/review.sh
gutter_pane=''
gutter_tty=''
gutter_w=0
gutter_resized=0
shown_gutter='x'
shown_gutter_at='y'
gutter_sig='old'
needs_gutter_clear=0
gutter_sync %7 0
assert_eq 'nothing wanted and nothing there asks tmux nothing' '' "$(calls)"
: >"$tmux_log"
gutter_sync %7 1
assert_eq 'the pane is split when one is wanted' '%9' "$gutter_pane"
assert_eq 'its tty comes back with it' '/dev/ttys9' "$gutter_tty"
assert_eq 'and the width it was given is remembered' 1 "$gutter_w"
assert_match 'off the diff, where the reserved cells are' \
  'split-window -h -d -l 1 -t %7' "$(calls)"
assert_match 'running the gutter against the diff pane' 'review\.sh gutter %7' "$(calls)"
# The diff just changed width without its content moving, which the tick has to
# be able to tell from a resize that did move it.
assert_eq 'the diff resize is declared, so the row map survives it' 1 "$gutter_resized"
assert_eq 'the frame remembered from last time is dropped' '' "$shown_gutter"
assert_eq 'and so are the anchors, which are derived afresh' '' "$gutter_sig"
: >"$tmux_log"
gutter_resized=0
gutter_sync %7 1
assert_eq 'asking again for the width it already has does nothing' '' "$(calls)"
assert_eq 'and claims no resize' 0 "$gutter_resized"
# Widening is not a resize. Those cells belong to the commit list, and
# resize-pane can only take them from the pane next door -- which is the diff.
# The whole layout is restated instead, with the diff written down at the 202
# it already is. Panes named to match the layouts above: %0 diff, %1 header,
# %2 list, %3 the comments pane.
: >"$tmux_log"
gutter_pane=%3
gutter_w=1
gutter_resized=0
layout_now='400a,285x78,0,0{80x78,0,0[80x4,0,0,1,80x73,0,5,2],202x78,81,0,0,1x78,284,0,3}'
gutter_list_back=''
gutter_focus_back=''
gutter_sync %0 40 285 78 %1 %2 80 %0
# Compared literally, not matched: a layout is mostly brackets and braces,
# and every one of them means something else to a regular expression.
assert_eq 'the window is restated, not one border moved' 1 \
  "$(calls | grep -cF 'select-layout -t %0 7dc3,285x78,0,0{41x78,0,0[41x4,0,0,1,41x73,0,5,2],202x78,42,0,0,40x78,245,0,3}')"
assert_eq 'no border is moved on its own' 0 \
  "$(calls | grep -c 'resize-pane')"
# Opening it is a request to read what is in it, so that is where the reader is
# put. Sent with the clears rather than on its own: this path already costs a
# fork and does not need a second.
assert_eq 'and the reader is moved into the pane they opened' 1 \
  "$(calls | grep -cF 'select-pane -t %3')"
assert_eq 'and the pane they came from is kept, to go back to' '%0' "$gutter_focus_back"
assert_match 'and the pane own rows are dropped with it' 'clear-history -t %3' "$(calls)"
assert_eq 'recorded at the new width' 40 "$gutter_w"
# And no resize is declared, which is the opposite of the two paths above.
# gutter_resized says the diff has changed width without its content moving, so
# that the tick keeps the row map instead of spending a second rebuilding it.
# The tick clears it by noticing the width change it describes -- and this path
# does not change the diff's width at all. Setting it here would leave it
# standing until some later resize that really did reflow the diff, and that one
# would then keep a map that no longer describes it.
assert_eq 'and no resize is claimed, because the diff did not move' 0 \
  "$gutter_resized"

# The same widening, from a border the reader has dragged. The geometry being
# left is the one tmux reports rather than the one the list's share implies,
# which is the whole of what was wrong: the two agreed only while the list sat
# on its share, so from the first drag the restatement was refused and the pane
# stopped opening at all. The width it opens to is the same 41 either way --
# with the pane up the list has that much room and no more, wherever it stood.
: >"$tmux_log"
gutter_w=1
gutter_resized=0
gutter_list_back=''
layout_now='7ce9,285x78,0,0{60x78,0,0[60x4,0,0,1,60x73,0,5,2],222x78,61,0,0,1x78,284,0,3}'
gutter_sync %0 40 285 78 %1 %2 60 %2
assert_eq 'a dragged border is restated from where it actually is' 1 \
  "$(calls | grep -cF 'select-layout -t %0 7dc3,285x78,0,0{41x78,0,0[41x4,0,0,1,41x73,0,5,2],202x78,42,0,0,40x78,245,0,3}')"
assert_eq 'and where it stood is kept, because it is owed back' 60 "$gutter_list_back"
assert_eq 'and so is the list it was opened from' '%2' "$gutter_focus_back"

# Collapsing pays it back. The border returns to the 60 the reader dragged to
# and not the 80 its share would choose, and the diff keeps the 222 that leaves
# it -- more than the 202 it rendered at, which folds nothing.
: >"$tmux_log"
gutter_w=40
gutter_resized=0
layout_now='7dc3,285x78,0,0{41x78,0,0[41x4,0,0,1,41x73,0,5,2],202x78,42,0,0,40x78,245,0,3}'
gutter_sync %0 1 285 78 %1 %2 41 %3
assert_eq 'collapsing puts the border back where it was dragged' 1 \
  "$(calls | grep -cF 'select-layout -t %0 7ce9,285x78,0,0{60x78,0,0[60x4,0,0,1,60x73,0,5,2],222x78,61,0,0,1x78,284,0,3}')"
assert_eq 'and forgets it, having spent it' '' "$gutter_list_back"
assert_eq 'the pane recorded at the marks again' 1 "$gutter_w"
# And the reader goes back to the pane the toggle was reached from, which here
# was the commit list and not the diff. Standing in the comments pane at the
# time makes no difference: what is remembered is where it was opened from.
assert_eq 'and the reader is put back in the list they opened it from' 1 \
  "$(calls | grep -cF 'select-pane -t %2')"
assert_eq 'and forgets that too' '' "$gutter_focus_back"

# With nothing remembered -- the pane was opened before this loop was watching,
# or the reader was standing in the marks when they pressed C -- the diff is
# the answer, because it is the pane the comments are painted against.
: >"$tmux_log"
gutter_w=40
gutter_list_back=''
gutter_focus_back=''
layout_now='7dc3,285x78,0,0{41x78,0,0[41x4,0,0,1,41x73,0,5,2],202x78,42,0,0,40x78,245,0,3}'
gutter_sync %0 1 285 78 %1 %2 41 %3
assert_eq 'with nowhere remembered, the reader goes to the diff' 1 \
  "$(calls | grep -cF 'select-pane -t %0')"

# And a reader standing in the marks when they open it is not sent back there.
: >"$tmux_log"
gutter_w=1
gutter_focus_back=''
layout_now='400a,285x78,0,0{80x78,0,0[80x4,0,0,1,80x73,0,5,2],202x78,81,0,0,1x78,284,0,3}'
gutter_sync %0 40 285 78 %1 %2 80 %3
assert_eq 'opening it from the marks remembers the diff, not the marks' '%0' \
  "$gutter_focus_back"

# The layout is asserted rather than negotiated, so it is only ever applied to
# the window it was written for. A window that is some other shape -- the
# reader split a pane of their own, or zoomed one -- is left alone, and the
# comment simply does not widen.
: >"$tmux_log"
gutter_w=1
gutter_resized=0
layout_now='beef,285x78,0,0{142x78,0,0,1,142x78,143,0,0}'
gutter_sync %0 40 285 78 %1 %2 80
assert_eq 'a window of another shape is not rearranged' 0 \
  "$(calls | grep -c 'select-layout')"
# Nor is the reader moved. Nothing happened, so there is nowhere new to be.
assert_eq 'and the reader is left standing where they were' 0 \
  "$(calls | grep -c 'select-pane')"
assert_eq 'and the pane keeps the width it had' 1 "$gutter_w"
assert_eq 'with no resize claimed, so the row map stands' 0 "$gutter_resized"

# Without the window and the panes to write a layout from there is nothing to
# restate, and resize-pane would take the difference out of the diff.
: >"$tmux_log"
layout_now='400a,285x78,0,0{80x78,0,0[80x4,0,0,1,80x73,0,5,2],202x78,81,0,0,1x78,284,0,3}'
gutter_sync %0 40
assert_eq 'and with nothing to write a layout from, nothing happens' 0 \
  "$(calls | grep -c 'select-layout')"
assert_eq 'the pane still keeping its width' 1 "$gutter_w"

: >"$tmux_log"
gutter_pane=%9
gutter_w=40
gutter_sync %7 0
assert_eq 'nothing wanted takes it away' '' "$gutter_pane"
assert_match 'by killing the pane' 'kill-pane -t %9' "$(calls)"
assert_eq 'and forgets how wide it was' 0 "$gutter_w"
/bin/rm -f "$tmux_log"
unset -f tmux calls
unset tmux_log gutter_pane gutter_tty gutter_w gutter_resized shown_gutter layout_now
unset gutter_list_back gutter_focus_back
unset shown_gutter_at gutter_sig needs_gutter_clear self

section 'gutter_step: through the queue, over what could not be anchored'
cm_row=('' 10 40 '' 90)
gutter_cur=-1
# Called directly, never through $(...): the index it moves is the caller's,
# and a subshell would move a copy and throw it away. The row it steps from is
# the diff's, so the first press works with nothing yet visited.
gutter_step next 0
assert_eq 'from the top, the first comment below it' 1 "$gutter_cur"
gutter_step next 10
assert_eq 'then the next one past that' 2 "$gutter_cur"
gutter_step next 40
assert_eq 'the unplaced one in between is skipped' 4 "$gutter_cur"
gutter_step next 90
step_status=$?
assert_eq 'past the last there is nowhere to go' 1 "$step_status"
assert_eq 'which leaves the reader where they were' 4 "$gutter_cur"
gutter_step prev 90
assert_eq 'back the same way' 2 "$gutter_cur"
gutter_step prev 40
assert_eq 'to the first' 1 "$gutter_cur"
gutter_step prev 10
step_status=$?
assert_eq 'and no further' 1 "$step_status"
# Scrolled somewhere between two of them, the step is still relative to there
# rather than to whichever was visited last.
gutter_step next 50
assert_eq 'a step from the middle finds the one below' 4 "$gutter_cur"
gutter_step prev 50
assert_eq 'and back the one above' 2 "$gutter_cur"
# The row the reader is standing on counts. A comment is written on the line
# they are on, so with a strict comparison the comment just written was the one
# comment j could not reach -- and until it is reached there is nothing for e or
# d to act on, which is how "d then y deletes nothing" was really reached.
cm_row=('' 10 40 '' 90)
gutter_cur=-1
gutter_step next 10
assert_eq 'standing on a comment, j lands on it rather than past it' 1 "$gutter_cur"
gutter_cur=-1
gutter_step prev 40
assert_eq 'and k the same way' 2 "$gutter_cur"
gutter_cur=-1
gutter_step next 11
assert_eq 'a row with no comment on it still finds the next one' 2 "$gutter_cur"

section 'gutter_edge: the ends of the queue, and the only way to an unplaced one'
# A comment with no row is stepped over by j and k, which move by position and
# have none to use. comment_after sorts those to the front, so the front of the
# queue is where they are -- and gg is what goes there. Without this they could
# be read and sent but never opened or taken back, and R was the only way out.
cm_row=('' 10 40 '' 90)
gutter_cur=-1
gutter_edge first
assert_eq 'gg goes to the front of the queue' 0 "$gutter_cur"
assert_eq 'which is a comment j would step over' '' "${cm_row[gutter_cur]}"
gutter_edge last
assert_eq 'and G to the back of it' 4 "$gutter_cur"
# From an unplaced one, stepping carries on by position from the diff, because
# there is no row of its own to carry on from.
gutter_cur=0
gutter_step next 0
assert_eq 'a step from it finds the first placed comment below the reader' 1 "$gutter_cur"
# An empty queue has no ends to go to, and says so rather than moving.
cm_row=()
gutter_cur=-1
gutter_edge first
assert_eq 'an empty queue has no front to go to' 1 "$?"
assert_eq 'and the reader is left where they were' -1 "$gutter_cur"
cm_row=('' 10 40 '' 90)
gutter_cur=-1

# Two on one row cannot be told apart by position, so a step taken while
# standing on one of them goes to the next in the queue instead.
cm_row=(683 683 900)
gutter_cur=0
gutter_step next 683
assert_eq 'the second of a pair sharing a row is reachable' 1 "$gutter_cur"
gutter_step next 683
assert_eq 'and the step past them carries on by row' 2 "$gutter_cur"
gutter_step prev 900
assert_eq 'back to the later of the pair' 1 "$gutter_cur"
gutter_step prev 683
assert_eq 'and the earlier one' 0 "$gutter_cur"
gutter_step prev 683
step_status=$?
assert_eq 'with nothing before it' 1 "$step_status"
unset step_status
unset cm_row gutter_cur

section 'render: C is offered only once something is queued'
# The fixtures the render tests above set up are still in scope.
out=$(render 0 60 12 diff 0 0 0 0 | strip)
assert_eq 'an empty queue does not advertise the comments pane' 0 \
  "$(grep -c ' C ' <<<"$out")"
out=$(render 0 60 12 diff 0 0 0 1 | strip)
assert_match 'with one queued the key is listed' 'C comments' "$out"
out=$(render 0 60 12 list 0 0 0 1 | strip)
assert_match 'and on the list as well' 'C comments' "$out"
out=$(render 0 60 12 gutter 0 0 0 1 | strip)
assert_match 'standing in the pane, j and k mean comments' 'jk comment' "$out"
assert_match 'and C is offered there too' 'C comments' "$out"
# R answers from every pane, so every pane's legend offers it -- including the
# header's two rows, which have nothing else to do with the queue.
out=$(render 0 70 12 diff 1 0 0 1 | strip)
assert_match 'the range row offers it once something is queued' 'R clear' "$out"
out=$(render 0 70 12 diff 1 0 0 0 | strip)
assert_eq 'and does not before then' 0 "$(grep -c 'R clear' <<<"$out")"
out=$(render 0 70 12 diff 0 0 1 1 | strip)
assert_match 'the agent row offers it too' 'R clear' "$out"
out=$(render 0 70 12 diff 0 0 1 0 | strip)
assert_eq 'and not before then either' 0 "$(grep -c 'R clear' <<<"$out")"
# Narrow enough that most of the keys have gone, and it is still there.
out=$(render 0 34 12 list 0 0 0 1 | strip)
assert_match 'a narrow list keeps it when the rest gives way' 'R clear' "$out"
out=$(render 0 90 12 list 0 0 0 1 | strip)
assert_match 'a wide list offers the key that empties the queue' 'R clear' "$out"
assert_match 'and spells the toggle out when there is room' 'C toggle comments' "$out"
unset out

section 'render: only the focused pane has its keys listed'
out=$(render 0 60 20 diff | strip)
assert_match 'the diff keys are shown when the diff has focus' 'diff  jk line' "$out"
assert_eq 'and the list keys are not' 0 "$(grep -c 'list  jk commit' <<<"$out")"
out=$(render 0 60 20 list | strip)
assert_match 'the list keys are shown when the list has focus' 'list  jk commit' "$out"
assert_eq 'and the diff keys are not' 0 "$(grep -c 'diff  jk line' <<<"$out")"
assert_eq 'either way it is one row' 1 \
  "$(render 0 60 20 list | strip | grep -c -E '^ (diff|list)  ')"

section 'comment_file: a queue outlives the window it was written in'
# A real TMPDIR, so the directory it makes and the sweep that eventually takes
# it are the same ones the reader gets.
cf_a=$(comment_file /Users/me/work/dot-files 'origin/master..HEAD')
cf_b=$(comment_file /Users/me/work/dot-files 'HEAD~3..HEAD')
cf_c=$(comment_file /Users/me/other/dot-files 'origin/master..HEAD')
assert_eq 'the same repository and range name the same queue' "$cf_a" \
  "$(comment_file /Users/me/work/dot-files 'origin/master..HEAD')"
assert_eq 'a different range is a different queue' 1 \
  "$([[ $cf_a != "$cf_b" ]] && printf 1 || printf 0)"
assert_eq 'and so is the same range in another checkout' 1 \
  "$([[ $cf_a != "$cf_c" ]] && printf 1 || printf 0)"
assert_match 'it lives in a directory of its own under TMPDIR' \
  '/tmux-review/comments-' "$cf_a"
assert_eq 'which exists by the time the path is handed out' 1 \
  "$([[ -d ${cf_a%/*} ]] && printf 1 || printf 0)"
assert_eq 'no separator is doubled, whatever TMPDIR ends in' 0 \
  "$(grep -c '//' <<<"$cf_a")"
assert_eq 'nothing in the name needs quoting' 0 \
  "$(grep -c '[^A-Za-z0-9@._/-]' <<<"${cf_a##*/}")"
# A path long enough to overrun a filename keeps the end, where the range and
# the repository's own name are.
cf_long=$(comment_file "/$(printf 'deep/%.0s' {1..60})myrepo" 'origin/master..HEAD')
# Length of the name alone: ${#x##*/} is not a thing bash will parse, so the
# basename is taken first.
cf_name=${cf_long##*/}
assert_eq 'a path too long to be a filename is trimmed, not rejected' 1 \
  "$([[ ${#cf_name} -le 200 ]] && printf 1 || printf 0)"
assert_match 'and the range survives the trim' 'origin_master\.\.HEAD' "$cf_long"
assert_match 'as does the name of the repository' 'myrepo' "$cf_long"
unset cf_a cf_b cf_c cf_long cf_name

section 'the comment queue'
store=$(comment_file /tmp/test-repo 'base..HEAD')
/bin/rm -f "$store"
assert_eq 'a queue that does not exist yet is empty' 0 "$(comment_count "$store")"
assert_eq 'nothing to send is refused rather than sent blank' 1 \
  "$(comment_prompt "$store" range repo >/dev/null 2>&1; printf '%s' $?)"
# The refusal is the whole of it: a queue that was never written has no file,
# and reading one put bash's own error in the reader's pane.
assert_eq 'and says nothing on the way out' '' \
  "$(comment_prompt "$store" range repo 2>&1 >/dev/null)"
comment_add "$store" 40c21a5 tmux/scripts/review.sh 512 512 'if ((on_range)); then' \
  'the guard runs after this, so a stale range reaches select_index'
comment_add "$store" 7bc56c5 bin/git-review 40 44 $'base_branch() {\n  git symbolic-ref' \
  $'two things:\n- origin/HEAD is not always present\n- the fallback order matters'
# A commit's message has no file and no lines of one.
comment_add "$store" c34d0a5 '' '' '' $'Show LLM agent status in the tmux tab name\n\n9 files changed' \
  'why is the stat in the subject?'
assert_eq 'each comment is one record' 3 "$(comment_count "$store")"
out=$(comment_prompt "$store" 'origin/master..HEAD' dot-files)
assert_match 'the range is named' 'origin/master\.\.HEAD' "$out"
assert_match 'the commit leads the citation' 'commit 40c21a5 · tmux/scripts/review\.sh:512' "$out"
assert_match 'a span is cited as a range' 'git-review:40-44' "$out"
assert_match 'the block under review is quoted' '> if \(\(on_range\)\); then' "$out"
assert_match 'every line of it, not just the first' '> {3}git symbolic-ref' "$out"
assert_match 'a commit with no file is cited by the commit alone' '3\. commit c34d0a5' "$out"
assert_eq 'and names no file' 0 "$(grep -c 'c34d0a5 ·' <<<"$out")"
assert_match 'the body follows it' 'stale range reaches select_index' "$out"
assert_match 'a body continuing onto another line keeps the indent' \
  '   - origin/HEAD is not always present' "$out"
assert_match 'and so does the line after that' \
  '   - the fallback order matters' "$out"
assert_eq 'the queue survives being read' 3 "$(comment_count "$store")"
/bin/rm -f "$store"
unset out store

section 'comment_load: the queue, as parallel arrays'
store=$(comment_file /tmp/test-repo 'gutter..HEAD')
/bin/rm -f "$store"
comment_load "$store"
assert_eq 'a queue that was never written loads empty' 0 "${#cm_commit[@]}"
comment_add "$store" aaa1111 bin/git-review 24 24 '  local x' 'name this'
comment_add "$store" bbb2222 '' '' '' 'Subject line' 'and this'
comment_load "$store"
assert_eq 'both records' 2 "${#cm_commit[@]}"
assert_eq 'the commit of the first' aaa1111 "${cm_commit[0]}"
assert_eq 'the file of the first' bin/git-review "${cm_file[0]}"
assert_eq 'the line of the first' 24 "${cm_first[0]}"
assert_eq 'the body of the first' 'name this' "${cm_body[0]}"
assert_eq 'a commit comment carries no file' '' "${cm_file[1]}"
assert_eq 'every record starts unplaced' '' "${cm_row[1]}"
/bin/rm -f "$store"
unset store

section 'comment_file_span: the right header, for the right commit'
# One path, touched by two commits: delta writes a header for each, and only
# the one below the comment's own commit is that comment's.
declare -A row_of=([aaa1111]=0 [bbb2222]=50)
file_rows=(4 12 54 61)
file_names=(bin/git-review scripts/review.sh bin/git-review README.md)
sp() { comment_file_span "$1" "$2" && printf '%s..%s' "$REPLY" "$REPLY_END"; }
assert_eq 'the first commit takes the first header' '4..11' "$(sp aaa1111 bin/git-review)"
assert_eq 'the second commit takes the second' '54..60' "$(sp bbb2222 bin/git-review)"
assert_eq 'the span ends where the next file begins' '12..53' "$(sp aaa1111 scripts/review.sh)"
assert_eq 'the last file runs to the end of the scrollback' '61..-1' "$(sp bbb2222 README.md)"
assert_eq 'a file that is not there has no span' '' "$(sp aaa1111 nope.txt)"
assert_eq 'and neither has no file at all' '' "$(sp aaa1111 '')"
# An unknown commit is not a reason to refuse: the queue outlives the window,
# and a range that has been rebased under it still names the file.
assert_eq 'an unknown commit falls back to the first header' '4..11' "$(sp ffffff bin/git-review)"
unset -f sp
unset row_of file_rows file_names

section 'comment_anchor: the line, then the file, then the commit'
declare -A row_of=([aaa1111]=0 [bbb2222]=50)
file_rows=(4 20)
file_names=(bin/git-review README.md)
# Two rows both answering 24: one removed line carrying the old number, one
# added line carrying the new. The number alone cannot tell them apart.
# The capture starts at the file header itself, so the header is the first row
# of the dump and the rows below it are the file's diff.
grid=$' \ue702 bin/git-review
  10┊usage() {                    10│usage() {
  24┊  --range    print the range     │
    ┊                             23│  local y
    ┊                             24│  local x
  30┊done                         31│done'
# Recorded to a file, not a variable: the capture runs inside a command
# substitution, which is a subshell, and anything it assigns is gone with it.
cap_log=$(mktemp)
tmux() {
  if [[ $1 == capture-pane ]]; then
    printf '%s' "$*" >"$cap_log"
    printf '%s\n' "$grid"
    return 0
  fi
  return 0
}
a() { comment_anchor "$@" && printf '%s' "$REPLY"; }
# The grid above starts at row 5, the row after the file header at 4.
assert_eq 'the added line wins when the block is its text' 8 \
  "$(a %1 100 aaa1111 bin/git-review 24 '  local x')"
assert_eq 'the removed line wins when the block is that instead' 6 \
  "$(a %1 100 aaa1111 bin/git-review 24 '  --range    print the range')"
# Nothing to break the tie: the first row bearing the number, which is what a
# comment written against a line since re-rendered should still land on.
assert_eq 'with no block it is the first row bearing the number' 6 \
  "$(a %1 100 aaa1111 bin/git-review 24 '')"
assert_eq 'a block that matches nothing falls back the same way' 6 \
  "$(a %1 100 aaa1111 bin/git-review 24 'gone in a rebase')"
# The block leads with a blank row when the selection began on a rule.
assert_eq 'a leading blank line in the block is skipped' 8 \
  "$(a %1 100 aaa1111 bin/git-review 24 $'\n  local x')"
assert_eq 'a line that is not in the file falls back to its header' 4 \
  "$(a %1 100 aaa1111 bin/git-review 999 'nothing')"
assert_eq 'no line at all is the file header' 4 \
  "$(a %1 100 aaa1111 bin/git-review '' '')"
assert_eq 'no file at all is the commit header' 50 \
  "$(a %1 100 bbb2222 '' '' '')"
assert_eq 'and a record naming neither is unplaced' '' \
  "$(a %1 100 '' '' '' 'orphaned')"
# capture-pane counts back from the live grid, the way anchor_text does.
comment_anchor %1 100 aaa1111 bin/git-review 24 '  local x' >/dev/null
assert_match 'the span is asked for in capture-pane coordinates' \
  '\-S -96 -E -81' "$(cat "$cap_log")"
/bin/rm -f "$cap_log"
unset -f tmux a
unset row_of file_rows file_names grid cap_log

section 'wrap_body: words kept whole, paragraphs kept apart'
w() { wrap_body "$1" "$2"; printf '%s\n' "${WRAPPED[@]}"; }
assert_eq 'a short body is one row' 'name this' "$(w 'name this' 20)"
assert_eq 'a long one breaks between words' $'the guard runs\nafter this, so a\nstale range' \
  "$(w 'the guard runs after this, so a stale range' 16)"
assert_eq 'a paragraph break is kept' $'one\n\ntwo' "$(w $'one\n\ntwo' 20)"
# Cut by fit at the draw, not hyphenated here: half a path reads as a path.
assert_eq 'a word longer than the row is left whole' 'supercalifragilistic' \
  "$(w 'supercalifragilistic' 8)"
assert_eq 'an empty body is one empty row' '' "$(w '' 20)"
unset -f w

section 'comment_rows: every comment placed, then sorted up the diff'
declare -A row_of=([aaa1111]=0 [bbb2222]=50)
file_rows=(4)
file_names=(bin/git-review)
tmux() { return 0; }
# Written in the order the reader wrote them, which is not the order they
# appear in the diff.
cm_commit=(bbb2222 aaa1111 zzz9999)
cm_file=('' bin/git-review '')
cm_first=('' '' '')
cm_last=('' '' '')
cm_block=('' '' '')
cm_body=('on the commit' 'on the file' 'orphaned')
cm_row=('' '' '')
comment_rows %1 100
assert_eq 'the unplaced one sorts to the front' '' "${cm_row[0]}"
assert_eq 'and keeps its own body' 'orphaned' "${cm_body[0]}"
assert_eq 'then the file header at 4' 4 "${cm_row[1]}"
assert_eq 'whose body came with it' 'on the file' "${cm_body[1]}"
assert_eq 'then the commit header at 50' 50 "${cm_row[2]}"
assert_eq 'whose body came with it too' 'on the commit' "${cm_body[2]}"
unset -f tmux
unset row_of file_rows file_names

section 'comment_write: the queue back to the file it was read from'
# The round trip is the whole of edit and delete: both change the arrays and
# then write them, so anything the write loses is lost from the queue itself.
cw_store=$(mktemp "${TMPDIR:-/tmp}/review-cw.XXXXXX")
comment_add "$cw_store" 'abc1234' 'lib/a.ex' 10 12 'defp a do' 'the first'
comment_add "$cw_store" 'def5678' 'lib/b.ex' 3 3 'defp b do' 'the second'
comment_add "$cw_store" 'aaa9999' 'lib/c.ex' 7 9 'defp c do' 'the third'
comment_load "$cw_store"
assert_eq 'three records were read back' 3 "${#cm_body[@]}"

# A body with a newline and a pipe in it: the pipe is the legend's separator
# and the newline is what an editor leaves behind, and neither is the record's.
cm_body[1]=$'edited | with a pipe\nand a second line'
comment_write "$cw_store"
comment_load "$cw_store"
assert_eq 'the edited body survives the round trip' \
  $'edited | with a pipe\nand a second line' "${cm_body[1]}"
assert_eq 'and its neighbours are untouched' 'the first|the third' \
  "${cm_body[0]}|${cm_body[2]}"
assert_eq 'the anchors come back with them' 'def5678|lib/b.ex|3|3' \
  "${cm_commit[1]}|${cm_file[1]}|${cm_first[1]}|${cm_last[1]}"
assert_eq 'and the excerpt too' 'defp b do' "${cm_block[1]}"
assert_eq 'the count is still three' 3 "$(comment_count "$cw_store")"

# Dropping the first, the way delete_comment does.
cm_commit=("${cm_commit[@]:1}"); cm_file=("${cm_file[@]:1}")
cm_first=("${cm_first[@]:1}"); cm_last=("${cm_last[@]:1}")
cm_block=("${cm_block[@]:1}"); cm_body=("${cm_body[@]:1}")
cm_row=("${cm_row[@]:1}")
comment_write "$cw_store"
comment_load "$cw_store"
assert_eq 'two are left after a delete' 2 "${#cm_body[@]}"
assert_eq 'and the right one went' $'edited | with a pipe\nand a second line' "${cm_body[0]}"
assert_eq 'the count followed it down' 2 "$(comment_count "$cw_store")"

# Emptied, there is no file at all -- which is what the pane reads to know it
# has nothing to show, and what clear_comments leaves behind.
cm_commit=(); cm_file=(); cm_first=(); cm_last=(); cm_block=(); cm_body=(); cm_row=()
comment_write "$cw_store"
assert_eq 'an emptied queue leaves no file' 0 "$([[ -e $cw_store ]] && echo 1 || echo 0)"
assert_eq 'and no scratch file beside it' 0 \
  "$([[ -e $cw_store.tmp ]] && echo 1 || echo 0)"
assert_eq 'and counts nothing' 0 "$(comment_count "$cw_store")"
/bin/rm -f "$cw_store"
unset cw_store

section 'legend: the comment keys appear once one is being read'
# e and d act on the comment under the reader, so they are offered when there
# is one and not before. The tiers are separate arrays rather than a group
# spliced in, because which groups give way first when the pane is narrow is
# the whole point of a tier.
# render_legend writes a group as its keys, a space and its label -- the = is
# the separator in the tier and never reaches the row -- so these look for what
# is drawn and not for what was written.
render_legend 120 comments legend_gutter_tiers
assert_eq 'with none being read, edit is not offered' 0 \
  "$(printf '%s' "$REPLY_PLAIN" | grep -c 'e edit')"
assert_eq 'nor delete' 0 "$(printf '%s' "$REPLY_PLAIN" | grep -c 'd delete')"
assert_match 'but stepping through them is' 'jk comment' "$REPLY_PLAIN"
render_legend 120 comments legend_gutter_sel_tiers
assert_match 'standing on one, edit is offered' 'e edit' "$REPLY_PLAIN"
assert_match 'and delete' 'd delete' "$REPLY_PLAIN"
assert_match 'without losing the keys that were there before' 'R clear' "$REPLY_PLAIN"
# Narrow enough that most of it has to go: the two keys the reader stepped onto
# the comment for are the last to.
render_legend 22 comments legend_gutter_sel_tiers
assert_match 'and they outlast the rest when the pane is narrow' 'e edit' "$REPLY_PLAIN"

section 'read_key: the keys that reach the loop at all'
# A key that is not in this list resolves to nothing, and the loop that read it
# drops it. That is not a quiet failure: it is a key that looks bound and does
# nothing. y was missing, so the question d asks in the comments pane could not
# be answered from the pane the reader was standing in -- it timed out and kept
# the comment every time.
for rk_key in e d c s a C R j k q y Y '=' '<' '>'; do
  printf '%s' "$rk_key" | { read_key 0.05; printf '%s' "$REPLY"; } > "$tmp_counts"
  assert_eq "read_key passes $rk_key through" "$rk_key" "$(/bin/cat "$tmp_counts")"
done
unset rk_key

section 'the answer to a question reaches the pane that asked it'
# R and d are answered by a raw read on the list's own stdin, so the keystroke
# has to be sent there from wherever the reader is standing. Every pane that
# offers either key has to forward the answer, or the question cannot be
# answered from the pane that offered it.
rk_sent=''
tmux() { rk_sent="${*: -1}"; }
gutter_key fakelist d; assert_eq 'the comments pane forwards d' d "$rk_sent"
gutter_key fakelist R; assert_eq 'and R' R "$rk_sent"
gutter_key fakelist y; assert_eq 'and the y that answers them' y "$rk_sent"
gutter_key fakelist Y; assert_eq 'with Y meaning the same thing' y "$rk_sent"
rk_sent=''
gutter_key fakelist x; assert_eq 'while a key it does not know is not sent on' '' "$rk_sent"
sel=range
header_key fakewin fakepane R; assert_eq 'the header forwards R' R "$rk_sent"
header_key fakewin fakepane y; assert_eq 'and the y that answers it' y "$rk_sent"
unset -f tmux
unset rk_sent sel

section 'render_gutter: a comment on the row its line is on'
# 20 columns, 8 rows: seven for comments and the foot for what is off screen.
cm_row=(102 105)
cm_body=('first' 'second')
render_gutter 20 8 100
mapfile -t g < <(printf '%s' "$REPLY_PLAIN")
assert_eq 'one row per row of the pane' 8 "${#g[@]}"
assert_eq 'the row above the first comment is blank' '' "$(printf '%s' "${g[1]}" | tr -d ' ')"
assert_match 'the first comment is on its own row' '^█ first' "${g[2]}"
assert_match 'and the second on its own' '^█ second' "${g[5]}"
assert_eq 'the foot is empty when nothing is off screen' '' \
  "$(printf '%s' "${g[7]}" | tr -d ' ')"
# The bottom row is one cell short of the width on purpose: writing the last
# cell of the last row wraps the cursor and scrolls the pane.
assert_eq 'every row fits the pane' 1 \
  "$(m=1; for l in "${g[@]}"; do dwidth "$l"; ((REPLY > 19)) && m=0; done; printf '%s' "$m")"
dwidth "${g[7]}"
assert_eq 'and the last is a cell shorter still' 18 "$REPLY"
assert_eq 'no trailing newline to scroll on' 0 \
  "$(printf '%s' "$REPLY_PLAIN" | tail -c1 | grep -c '^$')"

section 'render_gutter: the earlier comment gives way, never the later'
# Two rows apart, with a body that wants four. Pushing the second down would
# align it to a line that is not its own, so the first is cut instead.
#
# Queued, it is cut to its one row whatever room happens to be under it. Read,
# it may take five -- but not the row the later comment is anchored to, which
# is the rule this section is here for.
cm_row=(102 104)
cm_body=('one two three four five six seven eight' 'later')
render_gutter 20 8 100
mapfile -t g < <(printf '%s' "$REPLY_PLAIN")
assert_match 'the first comment starts where it belongs' '^█ one two' "${g[2]}"
assert_match 'which says it was cut' '…' "${g[2]}"
assert_eq 'and takes no second row while it is only queued' '' \
  "$(printf '%s' "${g[3]}" | tr -d ' ')"
assert_match 'the later comment is still on its own row' '^█ later' "${g[4]}"

# Read, it is the exception: it runs to its full five rows over whatever is
# beneath it. Packed a row apart, every comment was one cut line and the pane
# could not be read at all. What it covers comes back when the reader steps
# off, and it took a keypress to cover it in the first place.
gutter_cur=0
render_gutter 20 8 100
mapfile -t g < <(printf '%s' "$REPLY_PLAIN")
assert_match 'read, it runs on past its first row' '^█ one two' "${g[2]}"
assert_match 'and carries the balloon at the right' "${comment_glyph}\$" "${g[2]}"
assert_match 'barring every row it takes' '^█ ' "${g[3]}"
assert_match 'running on rather than being cut' '^█ seven eight' "${g[4]}"
assert_eq 'and covering the comment that was on that row' 0 \
  "$(printf '%s' "$REPLY_PLAIN" | grep -c 'later')"
# Stepping off gives the covered rows straight back.
gutter_cur=-1
render_gutter 20 8 100
mapfile -t g < <(printf '%s' "$REPLY_PLAIN")
assert_match 'stepped off, the covered comment is back on its row' '^█ later' "${g[4]}"
assert_match 'and the one that was read is cut again' '…' "${g[2]}"

section 'render_gutter: what is off screen, and what cannot be placed'
cm_row=('' 90 102 300)
cm_body=('orphan' 'above' 'here' 'below')
render_gutter 20 8 100
mapfile -t g < <(printf '%s' "$REPLY_PLAIN")
assert_match 'a comment with no row is drawn at the top' '^█ orphan' "${g[0]}"
assert_match 'one in view is on its row' '^█ here' "${g[2]}"
assert_match 'the foot counts the one above' '↑1' "${g[7]}"
assert_match 'and the one below' '↓1' "${g[7]}"
# A pane too narrow to hold anything still has to answer, rather than taking
# the sidebar down with an arithmetic error.
render_gutter 2 3 100
assert_eq 'a pane with no room for a body still renders' 3 \
  "$(printf '%s' "$REPLY_PLAIN" | grep -c '')"
unset g
unset cm_row cm_body

section 'render_gutter: the one being read is marked, and the rest give way'
cm_row=(102 105)
cm_body=('first' 'second')
# Nothing stepped onto yet, so there is no one comment the others are not.
gutter_cur=-1
render_gutter 20 8 100
mapfile -t g < <(printf '%s' "$REPLY_PLAIN")
assert_match 'with nothing focused both carry the mark' '^█ first' "${g[2]}"
assert_match 'and so does the other' '^█ second' "${g[5]}"
col_of() { printf '%s' "$REPLY" | sed -n "$1p"; }
gutter_cur=1
render_gutter 20 8 100
mapfile -t g < <(printf '%s' "$REPLY_PLAIN")
# One cell either way -- the balloon is drawn in the mark's own cell rather
# than beside it -- so the text starts in the same column whichever is drawn.
assert_match 'the one being read is barred like the rest' '^█ second' "${g[5]}"
assert_match 'and carries the balloon at the right of its row' "${comment_glyph}\$" "${g[5]}"
assert_match 'the other keeps its mark' '^█ first' "${g[2]}"
# The bar is what tells it from the commit list's own current row, which is
# marked in blue: this one is amber, and runs the whole height of the comment.
# The balloon sits at the right of its first row rather than at the head of
# the bar -- beside the bar it read as a notch cut out of the amber rather
# than as a mark of its own.
cm_body=('first' 'a body long enough to take a second row of its own here')
gutter_cur=1
render_gutter 26 8 100
mapfile -t g2 < <(printf '%s' "$REPLY_PLAIN")
assert_match 'the bar carries on down the comment' '^█ ' "${g2[6]}"
assert_eq 'where an unread one would have a rule instead' 0 \
  "$(printf '%s' "${g2[6]}" | grep -c '│')"
assert_eq 'the bar is painted on its first row as well' 1 \
  "$(printf '%s' "$REPLY" | sed -n '6p' | grep -c '48;2;224;175;104')"
assert_eq 'and on the row under it, so it runs the whole height' 1 \
  "$(printf '%s' "$REPLY" | sed -n '7p' | grep -c '48;2;224;175;104')"
assert_match 'with the balloon drawn in the amber at the right' '38;2;224;175;104' \
  "$(printf '%s' "$REPLY" | sed -n '6p')"
assert_eq 'while the unread one stays blue' 1 \
  "$(printf '%s' "$REPLY" | sed -n '3p' | grep -c '48;2;122;162;247')"
cm_body=('first' 'second')
unset g2
assert_eq 'and both rows are the same width' \
  "$(dwidth "${g[2]}"; printf '%s' "$REPLY")" \
  "$(dwidth "${g[5]}"; printf '%s' "$REPLY")"
# The one being read keeps its colour; the rest are dimmed, which is what makes
# stepping through the queue visible in the pane and not only in the diff.
render_gutter 20 8 100
# Matched on the colour's own numbers rather than on the escape built out of
# the variable: a regex assembled from a string full of brackets is a test of
# the assembling.
assert_match 'the one being read is drawn in the reading colour' \
  '38;2;192;202;245' "$(col_of 6)"
assert_match 'and the others are dimmed' '38;2;86;95;137' "$(col_of 3)"
assert_eq 'which is not the colour the focused one is in' 0 \
  "$(col_of 3 | grep -c '38;2;192;202;245')"
# One cell has only brightness to say it with, so the mark itself does not
# change -- a column one cell wide cannot afford a second glyph.
gutter_cur=1
render_gutter 1 8 100
mapfile -t g < <(printf '%s' "$REPLY_PLAIN")
assert_eq 'collapsed, the focused row is still one cell' '█' "${g[5]}"
assert_eq 'and so is the unfocused one' '█' "${g[2]}"
assert_eq 'every row of a one-column pane is one column' 1 \
  "$(m=1; while IFS= read -r l; do dwidth "$l"; ((REPLY > 1)) && m=0; done \
     < <(printf '%s' "$REPLY_PLAIN"); printf '%s' "$m")"
unset -f col_of
unset g cm_row cm_body gutter_cur

section 'render_gutter: collapsed, what is off screen is an arrow'
# One column has no room for a count, so the direction is all it says. An arrow
# rather than another painted mark: every cell of this pane is a mark already,
# and one more at the edge was being read as a comment on that line.
cm_row=(50 102 500)
cm_body=('above' 'here' 'below')
gutter_cur=-1
render_gutter 1 8 100
mapfile -t g4 < <(printf '%s' "$REPLY_PLAIN")
assert_eq 'the top row points at what is above it' "$off_above_glyph" "${g4[0]}"
assert_eq 'the foot points at what is below' "$off_below_glyph" "${g4[7]}"
assert_eq 'and the comment in view keeps its own mark' '█' "${g4[2]}"
assert_eq 'with no count anywhere in the column' 0 \
  "$(printf '%s' "$REPLY_PLAIN" | grep -c '[0-9]')"
assert_eq 'every row of it is still one column' 1 \
  "$(m=1; while IFS= read -r l; do dwidth "$l"; ((REPLY > 1)) && m=0; done \
     < <(printf '%s' "$REPLY_PLAIN"); printf '%s' "$m")"
assert_match 'the arrows are drawn in the off-screen colour' '38;2;255;255;255' \
  "$(printf '%s' "$REPLY" | sed -n '1p')"

# Nothing off screen either way, so neither edge says anything.
cm_row=(102)
cm_body=('here')
render_gutter 1 8 100
mapfile -t g4 < <(printf '%s' "$REPLY_PLAIN")
assert_eq 'with nothing above, the top row is blank' '' "$(printf '%s' "${g4[0]}" | tr -d ' ')"
assert_eq 'and with nothing below, so is the foot' '' "$(printf '%s' "${g4[7]}" | tr -d ' ')"

# A comment on the top row outranks the hint: a real mark says more than it.
cm_row=(50 100)
cm_body=('above' 'on the first row')
render_gutter 1 8 100
mapfile -t g4 < <(printf '%s' "$REPLY_PLAIN")
assert_eq 'a comment on the top row keeps it' '█' "${g4[0]}"
unset g4

section 'render_gutter: the bar runs the whole height, the balloon sits right'
# Five rows at most, every one of them barred, and the balloon on the first of
# them at the right-hand end. The balloon's cell is reserved on every row, so
# the wrap does not move between a comment being read and the same comment
# queued.
cm_row=(102)
cm_body=('a body long enough that it must wrap onto three separate rows of this pane before it ends')
gutter_cur=0
render_gutter 40 10 100
mapfile -t g3 < <(printf '%s' "$REPLY_PLAIN")
assert_match 'the first row is barred like the rest' '^█ ' "${g3[2]}"
assert_match 'and carries the balloon at its right' "${comment_glyph}\$" "${g3[2]}"
assert_match 'the row under it is barred too' '^█ ' "${g3[3]}"
assert_eq 'and carries no balloon of its own' 0 \
  "$(printf '%s' "${g3[3]}" | grep -c "$comment_glyph")"
assert_match 'as is the row below that' '^█ ' "${g3[4]}"

# Capped at five however much room is under it.
cm_row=(102)
cm_body=("$(printf 'word%s ' {1..90})")
gutter_cur=0
render_gutter 40 16 100
mapfile -t g3 < <(printf '%s' "$REPLY_PLAIN")
assert_match 'the fifth row is the last one drawn' '^█ ' "${g3[6]}"
assert_match 'and says it was cut' '…' "${g3[6]}"
assert_eq 'the sixth is empty' '' "$(printf '%s' "${g3[7]}" | tr -d ' ')"

# Queued, it is one row and keeps the reserved cell without drawing in it.
gutter_cur=-1
render_gutter 40 16 100
mapfile -t g3 < <(printf '%s' "$REPLY_PLAIN")
assert_match 'queued, it is one row' '^█ ' "${g3[2]}"
assert_eq 'with no balloon on it' 0 \
  "$(printf '%s' "${g3[2]}" | grep -c "$comment_glyph")"
assert_eq 'and nothing on the row under it' '' "$(printf '%s' "${g3[3]}" | tr -d ' ')"
unset g3

section 'render_gutter: two comments on one row, and which of them shows'
# Two notes about the same line, or two that could only be anchored as far as
# the same file header. The row cannot show both, and dropping the one that
# does not fit would hide a comment the queue still holds and s still sends.
cm_row=(683 683)
cm_body=('first note' 'second note')
gutter_cur=-1
render_gutter 30 6 680
mapfile -t g < <(printf '%s' "$REPLY_PLAIN")
assert_match 'with none being read the first of them shows' '^█ \(1/2\) first note' "${g[3]}"
assert_eq 'and it is the only row drawn' 1   "$(printf '%s' "$REPLY_PLAIN" | grep -c 'note')"
gutter_cur=1
render_gutter 30 6 680
mapfile -t g < <(printf '%s' "$REPLY_PLAIN")
assert_match 'stepping to the second shows that one instead'   '^█ \(2/2\) second note' "${g[3]}"
gutter_cur=0
render_gutter 30 6 680
mapfile -t g < <(printf '%s' "$REPLY_PLAIN")
assert_match 'and back again' '^█ \(1/2\) first note' "${g[3]}"
# One on its own is not counted, because there is nothing to count it against.
cm_row=(683)
cm_body=('alone')
gutter_cur=-1
render_gutter 30 6 680
mapfile -t g < <(printf '%s' "$REPLY_PLAIN")
assert_match 'a comment with the row to itself carries no count' '^█ alone' "${g[3]}"
unset g cm_row cm_body gutter_cur

section 'gutter_line: which line of which file a row is'
g() { gutter_line "$1" && printf '%s' "$REPLY"; }
assert_eq 'an unchanged line reports the new file number' 13 \
  "$(g '  13┊usage() {                                        13│usage() {')"
assert_eq 'an added line has only the new number' 24 \
  "$(g '    ┊                                                 24│  local x')"
assert_eq 'a removed line falls back to the old number' 24 \
  "$(g '  24┊  --range    print the range                       │')"
assert_eq 'the continuation of a wrapped line has none' '' \
  "$(g '    ┊| <n> | <base> | <range>]                          │<ref>')"
assert_eq 'a commit header has none' '' "$(g 'commit 5542b9f')"
assert_eq 'a rule has none' '' "$(g '─────────────────┐')"
assert_eq 'a file header has none' '' "$(g ' bin/git-review')"
# The row is split on the left gutter before the right one is looked for, so a
# box character in the code cannot be taken for the gutter.
assert_eq 'code containing the column glyph still reads correctly' 42 \
  "$(g '  42┊x = a │ b                                        42│x = a │ b')"
unset -f g

section 'file_row_regex: delta indents its file labels'
# The glyphs are taken from the stub rather than written out here: they are
# private-use codepoints, and a test that spells them itself is really testing
# whether this file survived being edited.
mod=$''; add=$''
git() { printf 'delta.file-modified-label %s\ndelta.file-added-label %s\n' "$mod" "$add"; }
re=$(file_row_regex)
unset -f git
matches() { printf '%s\n' "$1" | grep -cE "$re"; }
# The row delta actually writes: one column of indent, then the label.
assert_eq 'an indented modified label matches' 1 "$(matches " $mod tmux/scripts/review.sh")"
assert_eq 'an indented added label matches' 1 "$(matches " $add bin/new-thing")"
assert_eq 'a deeper indent matches too' 1 "$(matches "   $mod bin/git-review")"
assert_eq 'an unindented one still matches' 1 "$(matches "$mod tmux/scripts/review.sh")"
assert_eq 'a diffstat line does not' 0 "$(matches ' bin/git-review | 8 +++++++-')"
assert_eq 'a code row does not' 0 "$(matches '  13┊usage() {')"
# The path is what is left after the indent and the glyph.
name=" $mod tmux/scripts/review.sh"
name=${name#"${name%%[![:space:]]*}"}
name=${name#* }
assert_eq 'the path survives the indent and the glyph' 'tmux/scripts/review.sh' \
  "${name%"${name##*[![:space:]]}"}"
unset -f matches
unset re name mod add

section 'map_rows: one pass locates both kinds of header'
# The glyphs come from the stub, as in the section above: they are private-use
# codepoints, and a test that spells them out is testing its own encoding.
mod=$'\ue702'; add=$'\U000f0752'
git() { printf 'delta.file-modified-label %s\ndelta.file-added-label %s\n' "$mod" "$add"; }
file_re=$(file_row_regex)
unset -f git
# capture-pane answers with a diff; every other tmux call is swallowed, because
# what map_rows publishes is asserted through pub_* rather than off a server.
tmux() {
  [[ $1 == capture-pane ]] || return 0
  printf '%s\n' \
    'commit 21db538 (HEAD -> topic)' \
    '' \
    " $mod tmux/scripts/review.sh " \
    '  13┊usage() {' \
    " $add bin/new-thing" \
    'commit 612c33e'
}
declare -A row_of=()
declare -a file_rows=() file_names=()
# The sections below read the ten-commit fixture set above, so it is put back
# once this one is done with its own two.
declare -a saved_shas=("${shas[@]}")
shas=(21db538 612c33e)
mapped=0
pub_commits=''
pub_files=''
pub_stops=''
map_rows '%1'
unset -f tmux
assert_eq 'both commit headers are found' '0 5 ' "$pub_commits"
assert_eq 'both file headers are found' '2 4 ' "$pub_files"
assert_eq 'and the merged list comes out in row order' '0 2 4 5 ' "$pub_stops"
assert_eq 'the sha is read off the commit row' 0 "${row_of[21db538]}"
assert_eq 'and so is the second' 5 "${row_of[612c33e]}"
assert_eq 'the path survives the indent, the glyph and a trailing space' \
  'tmux/scripts/review.sh' "${file_names[0]}"
assert_eq 'the second path is read too' 'bin/new-thing' "${file_names[1]}"
assert_eq 'a code row carrying a gutter is not a header' 2 "${#file_rows[@]}"
assert_eq 'every commit found is what finishes the map' 1 "$mapped"
shas=("${saved_shas[@]}")
unset file_re mod add saved_shas
unset -v row_of

# The two commits the fold sections share, as delta writes them into the pane.
# The escapes are left where delta puts them -- between a line number and its
# gutter, between a box's rule and its corner -- because the renderer has to see
# through them to find anything, and a fixture without them would not ask it to.
# The labels come from a stub, as in the map_rows section above.
fx_mod=$''; fx_add=$'\U000f0752'
git() { printf 'delta.file-modified-label %s\ndelta.file-added-label %s\n' "$fx_mod" "$fx_add"; }
fx_re=$(file_row_regex)
unset -f git
fx_rule=$'\e[34m────────────────────\e[0m'
fx=(
  $'\e[33mcommit 21db538\e[m\e[33m (\e[m\e[1;36mHEAD -> \e[m\e[1;32mtopic\e[m\e[33m)\e[m'
  'Author: A <a@example.com>'
  'Date:   1 hour ago'
  ''
  '    Fold the diff'
  '    '
  '    Body line.'
  '---'
  $' bin/a | 3 \e[32m++\e[m\e[31m-\e[m'
  ' bin/b | Bin 0 -> 2 bytes'
  ' 2 files changed, 2 insertions(+), 1 deletion(-)'
  ''
  ''
  $'\e[34m'"$fx_mod"$' bin/a\e[0m'
  "$fx_rule"
  ''
  $'\e[34m─────\e[0m\e[34m┐\e[0m'
  $'\e[34m•\e[0m \e[34m1\e[0m: \e[34m│\e[0m'
  $'\e[34m─────\e[0m\e[34m┘\e[0m'
  $'\e[34m\e[38;2;145;76;84m   1\e[34m┊\e[0mone   \e[34m\e[38;2;68;157;171m   1\e[34m│\e[0mone'
  $'\e[34m\e[38;2;145;76;84m   2\e[34m┊\e[0mtwo   \e[34m\e[38;2;68;157;171m   2\e[34m│\e[0mdeux'
  $'\e[34m\e[38;2;145;76;84m    \e[34m┊\e[0m      \e[34m\e[38;2;68;157;171m   3\e[34m│\e[0mtrois'
  ''
  $'\e[34m─────────\e[0m\e[34m┐\e[0m'
  $'\e[34m•\e[0m \e[34m9\e[0m: fn \e[34m│\e[0m'
  $'\e[34m─────────\e[0m\e[34m┘\e[0m'
  $'\e[34m\e[38;2;145;76;84m   9\e[34m┊\e[0mnine  \e[34m\e[38;2;68;157;171m   9\e[34m│\e[0mnine'
  ''
  $'\e[34m'"$fx_add"$' bin/b (binary file)\e[0m'
  "$fx_rule"
  ''
  $'\e[33mcommit 612c33e\e[m'
  'Author: B <b@example.com>'
  'Date:   2 hours ago'
  ''
  '    Second'
  '---'
  $' c | 1 \e[32m+\e[m'
  ' 1 file changed, 1 insertion(+)'
  ''
  ''
  $'\e[34m'"$fx_add"$' c\e[0m'
  "$fx_rule"
  ''
  $'\e[34m─────\e[0m\e[34m┐\e[0m'
  $'\e[34m•\e[0m \e[34m1\e[0m: \e[34m│\e[0m'
  $'\e[34m─────\e[0m\e[34m┘\e[0m'
  $'\e[34m\e[38;2;145;76;84m    \e[34m┊\e[0m      \e[34m\e[38;2;68;157;171m   1\e[34m│\e[0mc'
)
fx_cache=$(mktemp)
fx_out=$(mktemp)
printf '%s\n' "${fx[@]}" >"$fx_cache"
# The same rows as the pane shows them, which is what the expectations below
# are written in. Built once: a sed per row per assertion would be most of the
# time this section takes.
fx_plain=()
while IFS= read -r fx_row; do fx_plain+=("$fx_row"); done < <(strip <"$fx_cache")
# Rows a to b of the fixture, as the pane shows them.
fx_rows() { printf '%s\n' "${fx_plain[@]:$1:$(($2 - $1 + 1))}"; }
fx_fold() { fold_render "$fx_cache" "$1" "${2:-160}" "$fx_re" | strip; }

section 'render_file: the render a review folds from, keyed by its server and diff pane'
# Pane ids are unique within a server and nowhere else: two servers each have a
# %1, and a review closing on one took the render of a review open on the other
# with it. The server's pid is the second field of TMUX, which tmux sets for
# every process it starts.
assert_match 'beside the header frames, named for the server and the pane' \
  'tmux-review/render-4242-_7\.txt$' "$(TMUX=/tmp/tmux-1/default,4242,0 render_file %7)"
assert_match 'and for the pane alone where there is no server to name' \
  'tmux-review/render-_7\.txt$' "$(unset TMUX; render_file %7)"

section 'fold_render: with nothing collapsed, the pane exactly as delta wrote it'
fold_render "$fx_cache" '' 160 "$fx_re" >"$fx_out"
cmp -s "$fx_cache" "$fx_out"
assert_ok $? 'byte for byte, escapes and all'
fold_render "$fx_cache" 'feedbac/9' 160 "$fx_re" >"$fx_out"
cmp -s "$fx_cache" "$fx_out"
assert_ok $? 'and an id that names nothing in the range changes nothing'
# The clear that goes ahead of a rewrite and the token after it are written by
# the render itself, so that it can go straight to the pane: tmux parses the
# rows while the rest are still being rendered, rather than after all of them.
fx_want=$(mktemp)
fold_render "$fx_cache" '' 160 "$fx_re" AHEAD- -AFTER >"$fx_out"
{ printf 'AHEAD-'; /bin/cat "$fx_cache"; printf -- '-AFTER'; } >"$fx_want"
cmp -s "$fx_want" "$fx_out"
assert_ok $? 'what goes ahead of the render and after it is written with it'
fold_render /no/such/render '' 160 "$fx_re" AHEAD- -AFTER >"$fx_out" 2>/dev/null
assert_eq 'and a render that cannot be read writes neither' 0 "$(wc -c <"$fx_out" | tr -d ' ')"
/bin/rm -f "$fx_want"
unset fx_want

section 'fold_render: a collapsed commit is its row and what it came to'
assert_eq 'the message and every file give way to the subject and the counts' \
  "$(fx_rows 0 0; printf '%s\n' '    ▸ Fold the diff  ·  2 files  +2 -1' ''; fx_rows 31 47)" \
  "$(fx_fold 21db538)"
fold_render "$fx_cache" 21db538 160 "$fx_re" >"$fx_out"
assert_eq 'the row that names it is left as delta wrote it' "${fx[0]}" "$(head -1 "$fx_out")"
assert_eq 'the last commit has no blank under it to keep' \
  "$(fx_rows 0 31; printf '%s\n' '    ▸ Second  ·  1 file  +1')" \
  "$(fx_fold 612c33e)"
fx_nostat=$(mktemp)
grep -v '1 file changed' "$fx_cache" >"$fx_nostat"
assert_eq 'a commit with no diffstat, as a merge has, stands in with its subject' \
  "$(fx_rows 0 31; printf '%s\n' '    ▸ Second')" \
  "$(fold_render "$fx_nostat" 612c33e 160 "$fx_re" | strip)"

section 'fold_render: a collapsed file keeps its header and counts what it hid'
assert_eq 'two hunks and the four lines in them' \
  "$(fx_rows 0 13; printf '%s\n' '   ▸ 2 hunks  ·  4 lines' ''; fx_rows 28 47)" \
  "$(fx_fold 21db538/1)"
assert_eq 'a binary file has nothing in it to count' \
  "$(fx_rows 0 28; printf '%s\n' '   ▸ 0 hunks  ·  0 lines' ''; fx_rows 31 47)" \
  "$(fx_fold 21db538/2)"
assert_eq 'files are counted from their own commit, not from the top of the range' \
  "$(fx_rows 0 41; printf '%s\n' '   ▸ 1 hunk  ·  1 line')" \
  "$(fx_fold 612c33e/1)"

section 'fold_render: a collapsed hunk keeps its box'
assert_eq 'the first hunk, and the three lines in it' \
  "$(fx_rows 0 18; printf '%s\n' '   ▸ 3 lines' ''; fx_rows 23 47)" \
  "$(fx_fold 21db538/1/1)"
assert_eq 'the second, counted from its own file' \
  "$(fx_rows 0 25; printf '%s\n' '   ▸ 1 line' ''; fx_rows 28 47)" \
  "$(fx_fold 21db538/1/2)"

section 'fold_render: what is collapsed inside a collapsed commit waits for it'
assert_eq 'a file collapsed inside a collapsed commit shows only the commit' \
  "$(fx_fold 21db538)" "$(fx_fold '21db538 21db538/1')"
assert_eq 'and several items collapse in the one pass' \
  "$(fx_rows 0 18; printf '%s\n' '   ▸ 3 lines' ''; fx_rows 23 31
     printf '%s\n' '    ▸ Second  ·  1 file  +1')" \
  "$(fx_fold '21db538/1/1 612c33e')"

section 'fold_render: a placeholder never wraps'
assert_eq 'the subject gives way to the width delta rendered at' \
  '    ▸ Fold…  ·  2 files  +2 -1' "$(fx_fold 21db538 30 | sed -n 2p)"
dwidth "$(fx_fold 21db538 30 | sed -n 2p)"
assert_eq 'which leaves the row exactly that wide' 30 "$REPLY"
fx_accent=$(mktemp)
sed 's/Fold the diff/Réécrire le pli/' "$fx_cache" >"$fx_accent"
assert_eq 'and a subject is cut between characters, never inside one' \
  '    ▸ Ré…  ·  2 files  +2 -1' \
  "$(fold_render "$fx_accent" 21db538 28 "$fx_re" | strip | sed -n 2p)"

section 'fold_render: the headers it wrote, the way grep -n reads them off the pane'
# A fold knows where every header went as it writes them, so the map can come
# from the render rather than from a capture of the pane: 130-150ms of a
# 40,000-row range saved after every fold. Written in the very shape map_rows
# reads off a capture -- the row counted from one, a colon, the row's text --
# so the one parser reads both and the two cannot disagree about what a header
# is.
fm_map=$(mktemp)
fm_err=$(mktemp)
fm_grep() { strip | grep -nE "^commit [0-9a-f]{7,}|^(─)+┐|$fx_re"; }
for fm_ids in '' '21db538/1/1' '21db538' '21db538/1 612c33e/1/1'; do
  fold_render "$fx_cache" "$fm_ids" 160 "$fx_re" '' '' "$fm_map" >"$fx_out" 2>/dev/null
  assert_eq "with ${fm_ids:-nothing} collapsed, the headers are where the pane will have them" \
    "$(fm_grep <"$fx_out")" "$(<"$fm_map")"
done
fold_render "$fx_cache" '21db538/1/1' 160 "$fx_re" '' '' "$fm_map" >"$fx_out" 2>"$fm_err"
assert_eq 'and it says how many rows it wrote, which is what proves none of them wrapped' \
  "$(grep -c '' <"$fx_out")" "$(<"$fm_err")"
/bin/rm -f "$fm_err"
unset -f fm_grep
unset fm_ids fm_err

section 'fold_render: a token where the view ends, so the reader need not wait for the rest'
# On a large range most of a fold is tmux parsing rows below the reader, which
# they cannot see. So the render can put a second token after the row the view
# ends on, and say so on stderr the moment it has: the pane can be swapped onto
# what has landed while the rest is still being written behind it.
fv_err=$(mktemp)
fv_want=$(mktemp)
fold_render "$fx_cache" '' 160 "$fx_re" AHEAD- -AFTER "$fm_map" 10 -VIEW- >"$fx_out" 2>"$fv_err"
{ printf 'AHEAD-'; head -10 "$fx_cache"; printf -- '-VIEW-'; tail -n +11 "$fx_cache"
  printf -- '-AFTER'; } >"$fv_want"
cmp -s "$fv_want" "$fx_out"
assert_ok $? 'the token goes after the tenth row, between it and the eleventh'
assert_eq 'and the render says it has passed the view before it says how much it wrote' \
  $'view\n48' "$(<"$fv_err")"
fold_render "$fx_cache" '' 160 "$fx_re" AHEAD- -AFTER "$fm_map" 48 -VIEW- >"$fx_out" 2>"$fv_err"
assert_eq 'a render that ends at the view has nothing behind it, and no token for it' \
  '48' "$(<"$fv_err")"
cmp -s "$fx_out" <({ printf 'AHEAD-'; /bin/cat "$fx_cache"; printf -- '-AFTER'; })
assert_ok $? 'and is written as it would have been without one'
/bin/rm -f "$fv_err" "$fv_want"
unset fv_err fv_want

section 'map_rows: hunk boxes are mapped, and are not stops'
tmux() { [[ $1 == capture-pane ]] && printf '%s\n' "${fx_plain[@]}"; return 0; }
declare -A row_of=()
declare -a file_rows=() file_names=() hunk_rows=()
declare -a saved_shas=("${shas[@]}")
shas=(21db538 612c33e)
mapped=0; pub_commits=''; pub_files=''; pub_stops=''
file_re=$fx_re
map_rows '%1'
unset -f tmux
assert_eq 'every box top is a hunk row' '16 23 44' "${hunk_rows[*]}"
assert_eq 'the files are where they always were' '13 28 41 ' "$pub_files"
assert_eq 'and n and N still stop at commits and files only' '0 13 28 31 41 ' "$pub_stops"

section 'comment_anchor: a comment in something collapsed goes to what is left of it'
# Nothing about a fold tells the comments where to go: the map is built again
# from the new grid, and the anchors are worked out again from the map. These
# are the same fallbacks a rebase relies on -- the line, then the file, then
# the commit -- run against a pane that has been written with a fold in it.
ca_rows=()
ca_tmux() {
  [[ $1 == capture-pane ]] || return 0
  local from=$4 to=$6
  [[ $from == - ]] && from=0
  [[ $to == - ]] && to=$((${#ca_rows[@]} - 1))
  printf '%s\n' "${ca_rows[@]:from:to-from+1}"
}
tmux() { ca_tmux "$@"; }
ca_load() {
  ca_rows=()
  while IFS= read -r fx_row; do ca_rows+=("$fx_row"); done < <(fx_fold "$1")
  mapped=0
  map_rows '%1'
}
ca_load 21db538/1/1
comment_anchor %1 0 21db538 bin/a 2 'two'
assert_eq 'a line folded away with its hunk goes to the header of its file' 13 "$REPLY"
comment_anchor %1 0 21db538 bin/a 9 'nine'
assert_eq 'while a line of the hunk still showing keeps its own row' 24 "$REPLY"
ca_load 21db538
comment_anchor %1 0 21db538 bin/a 2 'two'
assert_eq 'and one folded away with its commit goes to the commit row' 0 "$REPLY"
unset -f tmux ca_tmux ca_load
unset ca_rows

section 'map_rows: the map a fold wrote, the same as the one off the pane'
fold_render "$fx_cache" '21db538/1/1' 160 "$fx_re" '' '' "$fm_map" >"$fx_out" 2>/dev/null
mr_rows=()
while IFS= read -r fx_row; do mr_rows+=("$fx_row"); done < <(strip <"$fx_out")
mr_state() {
  printf '%s|%s|%s|%s|%s' "$(declare -p row_of file_rows file_names hunk_rows)" \
    "$pub_commits" "$pub_files" "$pub_stops" "$mapped"
}
tmux() { [[ $1 == capture-pane ]] && printf '%s\n' "${mr_rows[@]}"; return 0; }
declare -A row_of=()
mapped=0; pub_commits=''; pub_files=''; pub_stops=''
map_rows %1
mr_capture=$(mr_state)
mr_asked=''
tmux() { mr_asked+="[$*]"; return 0; }
declare -A row_of=()
mapped=0; pub_commits=''; pub_files=''; pub_stops=''
map_rows %1 "$fm_map"
assert_eq 'read from what a fold wrote, the map is the one the pane would give' \
  "$mr_capture" "$(mr_state)"
assert_eq 'and the pane is not captured to get it' 0 "$(grep -c capture-pane <<<"$mr_asked")"
unset -f tmux mr_state
unset mr_rows mr_capture mr_asked

section 'map_rows: the rows published down the control client'
# Every map rebuilt is published for the jump keys, and after a fold that is on
# the path to the next key: a tmux of its own for it was 8ms of every fold.
# Down the client the sidebar already holds it is a line written, not waited
# for, and it lands behind whatever went down that client before it.
fold_render "$fx_cache" '' 160 "$fx_re" '' '' "$fm_map" >"$fx_out" 2>/dev/null
mp_w=$(mktemp)
exec {mp_wfd}>"$mp_w"
sub_out=$mp_wfd
sub_in=$mp_wfd
mp_asked=''
tmux() { mp_asked+="[$*]"; return 0; }
declare -A row_of=()
mapped=0; pub_commits=''; pub_files=''; pub_stops=''
map_rows %1 "$fm_map"
exec {mp_wfd}>&-
assert_eq 'the three lists in one line down the control client' \
  'set-option -p -t %1 @review_commit_rows "0 31" ; set-option -p -t %1 @review_file_rows "13 28 41" ; set-option -p -t %1 @review_stop_rows "0 13 28 31 41"' \
  "$(/bin/cat "$mp_w")"
assert_eq 'and no tmux of its own' '' "$mp_asked"
sub_out=-1
sub_in=-1
/bin/rm -f "$mp_w"
unset -f tmux
unset mp_w mp_wfd mp_asked

section 'fold_item_at: the innermost item a row is inside'
declare -A row_of=([21db538]=0 [612c33e]=31)
file_rows=(13 28 41)
hunk_rows=(16 23 44)
it() {
  fold_item_at "$1" || { printf 'nothing'; return; }
  printf '%s %s-%s %s@%s' "$REPLY" "$REPLY_ROW" "$REPLY_END" "${REPLY_UP:--}" "${REPLY_UP_ROW:--}"
}
assert_eq 'the commit row is the commit' '21db538 0-0 -@-' "$(it 0)"
assert_eq 'and so is its message' '21db538 0-0 -@-' "$(it 6)"
assert_eq 'a file header is the file, inside its commit' '21db538/1 13-13 21db538@0' "$(it 13)"
assert_eq 'and so is the rule under it' '21db538/1 13-13 21db538@0' "$(it 15)"
assert_eq 'a hunk is its three box rows, inside its file' \
  '21db538/1/1 16-18 21db538/1@13' "$(it 17)"
assert_eq 'the blank row after a hunk is still that hunk' \
  '21db538/1/1 16-18 21db538/1@13' "$(it 22)"
assert_eq 'hunks are counted from their own file' '21db538/1/2 23-25 21db538/1@13' "$(it 26)"
assert_eq 'a hunk above a file header is the file before it, not this one' \
  '21db538/2 28-28 21db538@0' "$(it 28)"
assert_eq 'the next commit starts again' '612c33e 31-31 -@-' "$(it 31)"
assert_eq 'with its files counted from one' '612c33e/1 41-41 612c33e@31' "$(it 41)"
assert_eq 'and its hunks too' '612c33e/1/1 44-46 612c33e/1@41' "$(it 47)"
assert_eq 'above every commit there is nothing to fold' nothing "$(it -1)"
unset -f it

section 'fold_decide: what each key changes'
declare -A folded=()
d() { fold_decide "$@"; printf '%s %s' "${REPLY:--}" "${REPLY_FOLD:--}"; }
assert_eq '= collapses what is open' '21db538/1/2 1' "$(d '=' 21db538/1/2 21db538/1)"
assert_eq '< collapses what is open' '21db538/1/2 1' "$(d '<' 21db538/1/2 21db538/1)"
assert_eq '> leaves what is open alone' '- -' "$(d '>' 21db538/1/2 21db538/1)"
folded=([21db538/1]=1)
assert_eq '= opens what is collapsed' '21db538/1 0' "$(d '=' 21db538/1 21db538)"
assert_eq '> opens what is collapsed' '21db538/1 0' "$(d '>' 21db538/1 21db538)"
assert_eq '< on what is collapsed already collapses what is around it' \
  '21db538 1' "$(d '<' 21db538/1 21db538)"
folded=([21db538]=1)
assert_eq 'and a collapsed commit has nothing around it' '- -' "$(d '<' 21db538 '')"
folded=()
unset -f d

section 'fold_place: the header where the reader was looking, the cursor on it'
p() { fold_place "$@"; printf '%s %s' "$REPLY" "$REPLY_DOWN"; }
assert_eq 'a header in view keeps the view, and the cursor goes to it' '500 10' \
  "$(p 900 400 410 50)"
assert_eq 'a header above the view comes to the top of it' '520 0' "$(p 900 400 380 50)"
assert_eq 'and one below it the same' '440 0' "$(p 900 400 460 50)"
assert_eq 'the view cannot sit lower than the bottom of what is left' '0 40' \
  "$(p 300 330 340 50)"
assert_eq 'a diff that fits on the screen has no view to move' '0 12' "$(p 0 0 12 50)"
unset -f p

section 'fold_start: the render behind the pane, and what it says as it goes'
fw_tty=$(mktemp)
fw_want=$(mktemp)
fw_map=$(mktemp)
fold_start "$fw_tty" "$fx_cache" '' 160 "$fx_re" tok-1 "$fw_map" 10 tok-1-view
fw_said=''
while fold_next; do fw_said+="[$REPLY]"; done
fold_stop
assert_eq 'it passes the view, then says how many rows it wrote, then nothing more' \
  '[view][48]' "$fw_said"
{ printf '\e[H\e[2J\e[3J'; head -10 "$fx_cache"; printf '\e]2;%s\a' tok-1-view
  tail -n +11 "$fx_cache"; printf '\e]2;%s\a' tok-1; } >"$fw_want"
cmp -s "$fw_want" "$fw_tty"
assert_ok $? 'the screen and the history cleared, the rows, a token at the view and one at the end'
assert_eq 'and leaves where the headers went' 8 "$(grep -c '' <"$fw_map")"
# The pane is cleared by the first bytes written to it, so a render that fails
# must not get that far: what the reader would be left with is an empty diff
# that only q and reopening can bring back.
: >"$fw_tty"
fold_start "$fw_tty" /no/such/render '' 160 "$fx_re" tok-1 "$fw_map" 10 tok-1-view
fw_said=''
while fold_next; do fw_said+="[$REPLY]"; done
fold_stop
assert_eq 'a render that cannot be made says neither view nor a count' 0 \
  "$(grep -cE '\[(view|[0-9]+)\]' <<<"$fw_said")"
assert_eq 'and leaves the pane as it was' 0 "$(wc -c <"$fw_tty" | tr -d ' ')"
/bin/rm -f "$fw_tty" "$fw_want" "$fw_map"
unset fw_tty fw_want fw_map fw_said

section 'fold_wait: the token read back is the render parsed'
# Counted in a file: the stub answers through $(...), and a counter in a
# variable would go up in the subshell and be lost.
fw_n=$(mktemp)
printf 0 >"$fw_n"
tmux() {
  local n
  n=$(<"$fw_n")
  printf '%s' $((n + 1)) >"$fw_n"
  if ((n >= 2)); then printf 'tok-1\x1f42\x1f6\n'; else printf 'host\x1f9\x1f0\n'; fi
}
fold_wait %7 tok-1
fw_rc=$?
# The cursor's row as well as the history: the two together are how many rows
# the rewrite came to, which is what says whether any of them wrapped.
assert_eq 'it asks until the title is the token, and answers the history and the cursor then' \
  '0 42 6 3' "$fw_rc $REPLY $REPLY_CY $(<"$fw_n")"
# Waiting on the view, the end may already be in: either token does, and which
# it was is said.
tmux() { printf 'tok-1\x1f42\x1f6\n'; }
fold_wait %7 tok-1-view tok-1
fw_rc=$?
assert_eq 'either of two tokens ends the wait, and the one seen is said' \
  '0 tok-1' "$fw_rc $REPLY_TITLE"
tmux() { printf 'host\x1f9\n'; }
fold_wait_tries=3
fold_wait %7 tok-1
fw_rc=$?
assert_eq 'and gives up after its tries, with the last history it read' '1 9' "$fw_rc $REPLY"
unset -f tmux
/bin/rm -f "$fw_n"
unset fw_n fw_rc fold_wait_tries

section 'fold_swap: the new grid in one invocation'
fs_args=''
tmux() { fs_args+="[$*]"; }
fold_swap %7 520 10 host
assert_eq 'out of copy-mode and back, the view and the cursor placed, the title put back' \
  '[send-keys -X -t %7 cancel ; copy-mode -t %7 ; send-keys -X -t %7 goto-line 520 ; send-keys -X -t %7 top-line ; send-keys -X -N 10 -t %7 cursor-down ; select-pane -t %7 -T host ; set-option -p -t %7 -F @review_hist_base #{history_size}]' \
  "$fs_args"
fs_args=''
fold_swap %7 0 0 host
assert_eq 'with the cursor wanted on the top row there is no walk' \
  '[send-keys -X -t %7 cancel ; copy-mode -t %7 ; send-keys -X -t %7 goto-line 0 ; send-keys -X -t %7 top-line ; select-pane -t %7 -T host ; set-option -p -t %7 -F @review_hist_base #{history_size}]' \
  "$fs_args"
# select-pane -T expands formats in the title it is given, so a # in the title
# being put back would be read as the start of one.
fs_args=''
fold_swap %7 0 0 'host #1'
assert_match 'a # in the title goes back doubled, which is a # once expanded' \
  'select-pane -t %7 -T host ##1 ;' "$fs_args"
# Over the control client the sidebar already holds, when there is one: a
# command written down a descriptor rather than a tmux of its own. Nothing is
# waited for -- the turn after asks for the state down the same client, and
# tmux answers one client's commands in the order they came.
fs_w=$(mktemp)
exec {fs_wfd}>"$fs_w"
sub_out=$fs_wfd
sub_in=$fs_wfd
fs_args=''
fold_swap %7 520 10 'host #1'
exec {fs_wfd}>&-
assert_eq 'one line down the control client, quoted where tmux would split it' \
  'send-keys -X -t %7 cancel ; copy-mode -t %7 ; send-keys -X -t %7 goto-line 520 ; send-keys -X -t %7 top-line ; send-keys -X -N 10 -t %7 cursor-down ; select-pane -t %7 -T "host ##1" ; set-option -p -t %7 -F @review_hist_base "#{history_size}"' \
  "$(/bin/cat "$fs_w")"
assert_eq 'and no tmux of its own' '' "$fs_args"
sub_out=-1
sub_in=-1
/bin/rm -f "$fs_w"
unset -f tmux
unset fs_args fs_w fs_wfd

section 'fold_swap_early: onto what has landed, while the rest is still arriving'
# Rows are still landing when this runs, so the history copy-mode is entered on
# is not a number anything here can know -- and not one #{history_size} gives
# either, which goes on counting the rows that land after the entry: read that
# way the view came out five rows off, live. Copy-mode's own scroll does not
# move with them. history-top puts it at the whole of the history copy-mode was
# entered on, which is the basis, and run-shell -C expands its command as a
# format when it runs, so goto-line can work its distance from that.
fe_args=''
tmux() { fe_args+="[$*]"; }
fold_swap_early %7 380 10
assert_eq 'the view placed from the grid copy-mode was entered on, the cursor walked down it' \
  '[send-keys -X -t %7 cancel ; copy-mode -t %7 ; send-keys -X -t %7 history-top ; set-option -p -t %7 -F @review_hist_base #{scroll_position} ; run-shell -C -t %7 send-keys -X -t %7 goto-line #{e|-:#{scroll_position},380} ; send-keys -X -t %7 top-line ; send-keys -X -N 10 -t %7 cursor-down]' \
  "$fe_args"
fe_w=$(mktemp)
exec {fe_wfd}>"$fe_w"
sub_out=$fe_wfd
sub_in=$fe_wfd
fe_args=''
fold_swap_early %7 380 0
exec {fe_wfd}>&-
assert_eq 'and down the control client when there is one, with no walk for a cursor at the top' \
  'send-keys -X -t %7 cancel ; copy-mode -t %7 ; send-keys -X -t %7 history-top ; set-option -p -t %7 -F @review_hist_base "#{scroll_position}" ; run-shell -C -t %7 "send-keys -X -t %7 goto-line #{e|-:#{scroll_position},380}" ; send-keys -X -t %7 top-line' \
  "$(/bin/cat "$fe_w")"
sub_out=-1
sub_in=-1
/bin/rm -f "$fe_w"
unset -f tmux
unset fe_args fe_w fe_wfd

section 'fold_settle: the whole grid, under the reader wherever they have got to'
# The reader had the early view for as long as the rest took to land, and may
# have scrolled it. Their row is read again here, and the grid that is now
# whole is entered with them still on it.
fs_args=''
fold_swap() { fs_args+="[swap $*]"; }
tmux() { printf '500\x1f120\x1f7\n'; }
fold_settle %7 900 host
assert_eq 'the top row they were on and the screen row of their cursor, on the whole grid' \
  '[swap %7 520 7 host]' "$fs_args"
fs_args=''
tmux() { printf '500\x1f80\x1f3\n'; }
fold_settle %7 300 host
assert_eq 'and no lower than the bottom of it' '[swap %7 0 3 host]' "$fs_args"
unset -f tmux
restore_review
unset fs_args

section 'fold_key: the item, the decision, the rewrite, and a map to rebuild'
fk_cache=$(mktemp)
printf 'x\n' >"$fk_cache"
# Where the render is, as the sidebar worked it out once when it started:
# asking render_file again on every fold was a subshell and a mkdir apiece.
fold_cache=$fk_cache
render_file() { printf 'render_file was asked again'; }
# What the render says as it goes, one line per fold_next. A render too short to
# reach past the view says only how many rows it wrote.
fk_lines=(48)
# The ids sorted, because the order a set is written in is no part of what it
# says, and an associative array keeps none. Then the width, the token, the row
# the view ends on, and the token for it.
fold_start() {
  fk_calls+="[start $1 $2 $(tr ' ' '\n' <<<"$3" | sort | xargs) $4 $6 $8 $9]"
  fk_at=0
  return 0
}
fold_next() {
  ((fk_at < ${#fk_lines[@]})) || return 1
  REPLY=${fk_lines[fk_at]}
  fk_at=$((fk_at + 1))
  return 0
}
fold_stop() { :; }
# 48 rows written, and a pane that came to 40 of history and a cursor on its
# eighth row: 48 rows, so none of them wrapped. The title seen is the token
# waited on, unless a test says the end had already landed.
fold_wait() {
  fk_calls+="[wait $*]"
  REPLY=40
  REPLY_CY=${fk_cy_after-8}
  REPLY_TITLE=${fk_title:-$2}
  return "${fk_wait_rc-0}"
}
fold_swap() { fk_calls+="[swap $*]"; }
fold_swap_early() { fk_calls+="[early $*]"; }
fold_settle() { fk_calls+="[settle $*]"; }
map_rows() { fk_calls+="[map $*]"; mapped=1; }
# tty, basis, scroll, cursor row, title, render width, height, width.
tmux() {
  case $* in
    *pane_tty*)
      printf '/dev/ttys9\x1f100\x1f100\x1f%s\x1fhost\x1f%s\x1f60\x1f162\n' "$fk_cy" "${fk_rw-160}" ;;
    *) fk_calls+="[tmux $*]" ;;
  esac
  return 0
}
file_re=$fx_re
fk_reset() {
  folded=()
  fk_calls=''
  fk_cy=26
  fk_lines=(48)
  fk_title=''
  unset fk_cy_after fk_wait_rc
  mapped=1
  pending_row=7
  expect_row=7
  fold_gen=0
}

fk_reset
fold_key %7 = diff 0
# The map is built from what the render wrote, since every row it wrote is one
# row of the pane -- and built here, the moment the swap has gone: tmux spends
# 12ms copying a 40,000-row grid into copy-mode, which the next turn would
# otherwise spend waiting on its state.
assert_eq '= in a hunk collapses the hunk, the cursor goes to its box, and the map is built' \
  "[start /dev/ttys9 $fk_cache 21db538/1/2 160 review-fold-1 60 review-fold-1-view][wait %7 review-fold-1][swap %7 40 23 host][map %7 $fk_cache.map]" \
  "$fk_calls"
assert_eq 'the hunk is what is collapsed now' '21db538/1/2' "${!folded[*]}"
assert_eq 'and no move is left in flight against the old rows' '-1 -1' \
  "$pending_row $expect_row"

fk_reset
fk_cy_after=9
fold_key %7 = diff 0
assert_eq 'a row more than were written is a row that wrapped, and the map is left to the next turn' \
  0 "$(grep -c '\[map' <<<"$fk_calls")"
assert_eq 'which captures the pane for it' 0 "$mapped"

fk_reset
fold_key %7 = diff 0
fk_calls=''
fold_key %7 = diff 0
assert_eq 'each rewrite waits on a token of its own' 'review-fold-2' \
  "$(grep -o 'review-fold-[0-9]*' <<<"$fk_calls" | head -1)"
assert_eq 'and the second = opens what the first collapsed' '' "${!folded[*]}"

# A render longer than the view says so before it is done, and the reader is
# put on what has landed while the rest is written behind them -- then the
# whole grid is entered under wherever they have got to.
fk_reset
fk_lines=(view 48)
fold_key %7 = diff 0
assert_eq 'the reader is swapped onto the view first, and settled on the whole grid after' \
  "[start /dev/ttys9 $fk_cache 21db538/1/2 160 review-fold-1 60 review-fold-1-view][wait %7 review-fold-1-view review-fold-1][early %7 0 23][wait %7 review-fold-1][settle %7 40 host][map %7 $fk_cache.map]" \
  "$fk_calls"

fk_reset
fk_lines=(view 48)
fk_title='review-fold-1'
fold_key %7 = diff 0
assert_eq 'when the end has landed by the time the view is looked for, there is one swap' \
  "[start /dev/ttys9 $fk_cache 21db538/1/2 160 review-fold-1 60 review-fold-1-view][wait %7 review-fold-1-view review-fold-1][wait %7 review-fold-1][swap %7 40 23 host][map %7 $fk_cache.map]" \
  "$fk_calls"

fk_reset
fk_cy=17
fold_key %7 = diff 0
assert_eq 'a cursor already on the header stays on the row it was on' \
  "[start /dev/ttys9 $fk_cache 21db538/1/1 160 review-fold-1 60 review-fold-1-view][wait %7 review-fold-1][swap %7 40 17 host][map %7 $fk_cache.map]" \
  "$fk_calls"

fk_reset
folded=([21db538/1/2]=1)
fold_key %7 '<' diff 0
assert_eq '< on a collapsed hunk collapses its file, and the cursor goes to the file' \
  "[start /dev/ttys9 $fk_cache 21db538/1 21db538/1/2 160 review-fold-1 60 review-fold-1-view][wait %7 review-fold-1][swap %7 40 13 host][map %7 $fk_cache.map]" \
  "$fk_calls"

fk_reset
fk_cy=0
fold_key %7 '<' list 1
assert_eq 'from the list it is the selected commit, wherever the diff cursor is' \
  "[start /dev/ttys9 $fk_cache 612c33e 160 review-fold-1 60 review-fold-1-view][wait %7 review-fold-1][swap %7 40 31 host][map %7 $fk_cache.map]" \
  "$fk_calls"

fk_reset
fold_key %7 '>' diff 0
assert_eq '> on what is open writes nothing' '' "$fk_calls"
assert_eq 'and leaves the map alone' '1 7' "$mapped $pending_row"

fk_reset
fk_rw=''
fold_key %7 = diff 0
assert_eq 'a render with no width of its own is fitted to the pane' \
  "[start /dev/ttys9 $fk_cache 21db538/1/2 162 review-fold-1 60 review-fold-1-view][wait %7 review-fold-1][swap %7 40 23 host][map %7 $fk_cache.map]" \
  "$fk_calls"
unset fk_rw

fk_reset
fk_wait_rc=1
fold_key %7 = diff 0
assert_eq 'a token that never comes back still ends in the swap, not in a stale copy' \
  "[start /dev/ttys9 $fk_cache 21db538/1/2 160 review-fold-1 60 review-fold-1-view][wait %7 review-fold-1][swap %7 40 23 host][map %7 $fk_cache.map]" \
  "$fk_calls"

fk_reset
folded=([612c33e]=1)
fk_lines=('awk: can not open file')
fold_key %7 = diff 0
assert_eq 'a render that says neither view nor a count says so, and goes no further' \
  "[start /dev/ttys9 $fk_cache 21db538/1/2 612c33e 160 review-fold-1 60 review-fold-1-view][tmux display-message review: could not write the diff again]" \
  "$fk_calls"
assert_eq 'leaving the set describing the pane it could not change' '612c33e' "${!folded[*]}"

fk_reset
fk_lines=()
fold_key %7 = diff 0
assert_eq 'and so does one that says nothing at all' '' "${!folded[*]}"

fk_reset
fold_cache=/no/such/render
fold_key %7 = diff 0
assert_eq 'without the render to work from it says so, and writes nothing' \
  '[tmux display-message review: nothing to fold from -- q and open the review again]' \
  "$fk_calls"

# Down the control client when the sidebar has one: the state asked for there
# rather than by a tmux of its own.
fk_reset
fold_cache=$fk_cache
ctl_ask() {
  fk_calls+="[ask]"
  case $2 in
    *pane_tty*) REPLY=$'/dev/ttys9\x1f100\x1f100\x1f26\x1fhost\x1f160\x1f60\x1f162' ;;
  esac
  return 0
}
fold_key %7 = diff 0
assert_eq 'the state is asked down the control client, and no tmux is run for it' \
  "[ask][start /dev/ttys9 $fk_cache 21db538/1/2 160 review-fold-1 60 review-fold-1-view][wait %7 review-fold-1][swap %7 40 23 host][map %7 $fk_cache.map]" \
  "$fk_calls"
unset -f ctl_ask

unset -f tmux fk_reset
restore_review
shas=("${saved_shas[@]}")
unset -v row_of
file_rows=(); file_names=(); hunk_rows=(); folded=()
mapped=0; pending_row=-1; expect_row=-1
/bin/rm -f "$fk_cache" "$fx_cache" "$fx_out" "$fx_nostat" "$fx_accent" "$fm_map"
unset -f fx_rows fx_fold
unset fk_cache fk_calls fk_cy fold_gen file_re saved_shas fold_cache map_gen
unset fk_lines fk_at fk_title fk_cy_after fk_wait_rc
unset fx fx_plain fx_row fx_mod fx_add fx_re fx_rule fx_cache fx_out fx_nostat fx_accent fm_map
unset pub_commits pub_files pub_stops

section 'anchor_rows: where the reader is, in rows from the start of history'
# The pane is answered for by a stub reading these, so each case is just the
# six fields display-message would have returned.
a_present=0; a_sy=''; a_ey=''; a_hist=388; a_scroll=388; a_cy=0; a_base=388
tmux() {
  [[ $1 == display-message ]] || return 0
  printf '%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s' \
    "$a_present" "$a_sy" "$a_ey" "$a_hist" "$a_scroll" "$a_cy" "$a_base"
}
anchor_rows %1
assert_eq 'scrolled to the top, the cursor is the first row' 0 "$ANCHOR_FIRST_ROW"
assert_eq 'and the span is that row alone' 0 "$ANCHOR_LAST_ROW"
assert_eq 'the history size comes back with it' 388 "$ANCHOR_HIST"
a_scroll=0; a_cy=5
anchor_rows %1
assert_eq 'at the bottom the rows are past the whole history' 393 "$ANCHOR_FIRST_ROW"
a_scroll=388; a_cy=0; a_present=1; a_sy=7; a_ey=3
anchor_rows %1
assert_eq 'a selection dragged upwards still starts at its top' 3 "$ANCHOR_FIRST_ROW"
assert_eq 'and ends at its bottom' 7 "$ANCHOR_LAST_ROW"
# Mid-load the two sizes come apart: the tail of the diff has grown the grid,
# but scroll_position is still measured against it as it was when copy-mode
# was entered. The rows follow the basis, the capture follows the live size.
a_present=0; a_sy=''; a_ey=''; a_base=200; a_hist=388; a_scroll=200; a_cy=4
anchor_rows %1
assert_eq 'rows are counted against the basis, not the live size' 4 "$ANCHOR_FIRST_ROW"
assert_eq 'and the live size is what the capture gets' 388 "$ANCHOR_HIST"
unset -f tmux
unset a_present a_sy a_ey a_hist a_scroll a_cy a_base

section 'anchor_text: history rows become capture-pane coordinates'
# anchor_text asks commit_at whether the row sits in a commit's header, which
# reads these two; empty means no commit above, so the file paths below run.
# The fixture set the sections above built is put back at the end of this one.
saved_shas=("${shas[@]}")
shas=()
declare -A row_of=()
# capture-pane counts from the top of the visible screen, with the history
# behind it as negative numbers, so a row counted from the start of the history
# has to be shifted back by its size. The stub reports the coordinate it was
# asked for as the gutter number, which is the conversion itself.
tmux() {
  [[ $1 == capture-pane ]] || return 0
  local start=0 end=0 i
  while (($#)); do
    if [[ $1 == -S ]]; then
      start=$2
      shift 2
      continue
    fi
    if [[ $1 == -E ]]; then
      end=$2
      shift 2
      continue
    fi
    shift
  done
  # One row per coordinate, each numbered by the coordinate it sits at, offset
  # so a row in the history still prints as a gutter number. The capture now
  # reaches above the span to find the row a continuation belongs to, so the
  # span is what follows those rows rather than the whole answer.
  for ((i = start; i <= end; i++)); do
    printf '    ┊%5d│  some code\n' $((i + 1000))
  done
}
file_rows=(0); file_names=('bin/git-review')
anchor_text %1 40 40 388
assert_eq 'a row 348 back from the screen is read 348 back' 652 "$ANCHOR_FIRST"
assert_eq 'and the block comes off that row' 'some code' "$ANCHOR_BLOCK"
anchor_text %1 40 40 0
assert_eq 'with no history behind it the row is the coordinate' 1040 "$ANCHOR_FIRST"
anchor_text %1 400 400 388
assert_eq 'a row on the visible screen stays positive' 1012 "$ANCHOR_FIRST"
unset -f tmux

# Nearly half of delta's rows carry no number: the continuation of a wrapped
# line, the three rows of a hunk header box, a rule. A block over wrapped
# added code sits entirely inside a run of them, and used to be refused.
tmux() {
  [[ $1 == capture-pane ]] || return 0
  # A numbered row, then three continuations -- the shape delta writes for an
  # added line that wraps. The span asked for is the last three.
  printf '    ┊   26│# the line itself\n'
  printf '    ┊     │wrapped once\n'
  printf '    ┊     │wrapped twice\n'
  printf '    ┊     │wrapped again\n'
}
file_rows=(0); file_names=('tmux/scripts/review.sh')
anchor_text %1 1 3 0
assert_eq 'a span of continuations takes the line above them' 26 "$ANCHOR_FIRST"
assert_eq 'and reports it as a single line' 26 "$ANCHOR_LAST"
assert_eq 'the block is the rows selected, not the line they belong to' \
  $'wrapped once\nwrapped twice\nwrapped again' "$ANCHOR_BLOCK"
assert_eq 'and still naming the file' 'tmux/scripts/review.sh' "$ANCHOR_FILE"
# Rows with no number anywhere near them are still worth commenting on -- the
# reader picked them out. They carry the text and no line of a file.
tmux() {
  [[ $1 == capture-pane ]] || return 0
  printf '    ┊     │no numbers\n'
  printf '    ┊     │anywhere at all\n'
}
anchor_text %1 0 1 0
assert_eq 'text with no line number is still an anchor' \
  $'no numbers\nanywhere at all' "$ANCHOR_BLOCK"
assert_eq 'with no line of a file claimed for it' '' "$ANCHOR_FIRST"
unset -f tmux

shas=("${saved_shas[@]}")
unset -v row_of

section 'anchor_text: a commit header is not a line of the file before it'
# The rows delta writes for a commit -- its header, then its message -- carry
# no gutter number, and the numbered rows above them belong to the commit
# before. Walking back into those named a file and a line the reader was not
# looking at, which is worse than refusing.
shas=(aaaaaaa bbbbbbb)
declare -A row_of=([aaaaaaa]=0 [bbbbbbb]=10)
file_rows=(3); file_names=('lib/thing.ex')
tmux() {
  [[ $1 == capture-pane ]] || return 0
  local start=0 end=0
  while (($#)); do
    if [[ $1 == -S ]]; then start=$2; shift 2; continue; fi
    if [[ $1 == -E ]]; then end=$2; shift 2; continue; fi
    shift
  done
  local i
  for ((i = start; i <= end; i++)); do
    # Row 5 is the last diff line of the first commit; 10 and on are the second
    # commit's header and message, and carry no gutter.
    if ((i <= 5)); then printf '    ┊%5d│  code\n' $((100 + i)); else printf '  some commit text\n'; fi
  done
}
anchor_text %1 12 12 0
assert_eq 'a message line names its own commit' bbbbbbb "$ANCHOR_COMMIT"
assert_eq 'and no file, because the one above belongs to the commit before' \
  '' "$ANCHOR_FILE"
assert_eq 'with no line of that file invented for it' '' "$ANCHOR_FIRST"
assert_eq 'and carries the row the reader is on' 'some commit text' "$ANCHOR_BLOCK"
# A selection across the message: all of it, not the first line of it.
anchor_text %1 11 13 0
assert_eq 'a block across the message carries every row' \
  $'some commit text\nsome commit text\nsome commit text' "$ANCHOR_BLOCK"
anchor_text %1 10 10 0
assert_eq 'the commit header row itself, too' bbbbbbb "$ANCHOR_COMMIT"
# Inside the diff the old behaviour stands: a row with no number of its own
# still takes the numbered row above it.
file_rows=(3); file_names=('lib/thing.ex')
anchor_text %1 5 5 0
assert_eq 'a diff row still anchors to its file' 'lib/thing.ex' "$ANCHOR_FILE"
assert_eq 'and to a line of it' 105 "$ANCHOR_FIRST"
unset -f tmux
unset -v row_of
shas=("${saved_shas[@]}")

unset saved_shas

section 'trace: off unless REVIEW_TRACE names a file'
tf=$(mktemp)
REVIEW_TRACE='' trace 'ignored'
assert_eq 'no file named, nothing written' 0 "$(wc -c < "$tf" | tr -d ' ')"
REVIEW_TRACE=$tf trace 'a-step'
REVIEW_TRACE=$tf trace 'another-step'
assert_eq 'one line per call' 2 "$(wc -l < "$tf" | tr -d ' ')"
assert_match 'each carries a timestamp and the label' '^[0-9]+\.[0-9]+ a-step$' "$(head -1 "$tf")"
/bin/rm -f "$tf"
unset tf

section 'plan_chunks: the head of the diff, then the rest'
# It asks git itself now, in the time it used to spend blocked on the sidebar.
git() { [[ $* == 'rev-list --reverse base..HEAD' ]] && printf 'c1\nc2\nc3\n'; }
chunks=(); plan_chunks 'base..HEAD'
assert_eq 'it splits in two' 2 "${#chunks[@]}"
assert_eq 'the head is the first commit on its own' 'base..c1' "${chunks[0]}"
# The base stays on the tail. c1..HEAD alone is everything HEAD reaches that c1
# does not, and on a history with merges that is not bounded by the base at
# all: a range of 58 commits came out as 80, the list never found all of its
# commits in the diff, and the map was built again on every turn for good.
assert_eq 'and the tail is everything after it, still above the base' 'c1..HEAD ^base' \
  "${chunks[1]}"
# A one-commit range has nothing to split, and splitting it would buy an empty
# second chunk for a git, a delta and a settle.
git() { [[ $* == 'rev-list --reverse base..HEAD' ]] && printf 'c1\n'; }
chunks=(); plan_chunks 'base..HEAD'
assert_eq 'one commit has nothing to split' 1 "${#chunks[@]}"
assert_eq 'so the whole range goes in one' 'base..HEAD' "${chunks[0]}"
git() { [[ $* == 'rev-list --reverse HEAD' ]] && printf 'r1\n'; }
chunks=(); plan_chunks 'HEAD'
assert_eq 'and neither does a history of one commit' 'HEAD' "${chunks[*]}"
# The whole history splits at the root, and git log of a root is that commit
# alone -- there is no parent for it to walk on to.
git() { [[ $* == 'rev-list --reverse HEAD' ]] && printf 'r1\nc2\nc3\n'; }
chunks=(); plan_chunks 'HEAD'
assert_eq 'the whole history is the root, then everything since it' 'r1 r1..HEAD' \
  "${chunks[*]}"
git() { return 1; }
chunks=(); plan_chunks 'base..HEAD'
assert_eq 'a git that fails falls back to the whole range' 'base..HEAD' "${chunks[0]}"
unset -f git
unset chunks

section 'guess_agent: the session first, then the directory'
agent_pane=(%1 %2 %3)
agent_session=(01_dot-files 03_shop-api 03_shop-api)
agent_cwd=(/r/dot-files /r/shop-api /r/shop-api/lib)

# REPLY is left alone when it declines, so each case reads the status too --
# an assertion on REPLY alone passes on a stale value from the case before it.
guess() { REPLY=''; guess_agent "$@" && printf '%s' "$REPLY" || printf 'none'; }
assert_eq 'the agent in this session wins, wherever it sits' 0 "$(guess 01_dot-files /r/anywhere)"
assert_eq 'no session match falls back to the directory' 1 "$(guess '' /r/shop-api)"
assert_eq 'and to an agent whose directory contains it' 0 "$(guess '' /r/dot-files/tmux/scripts)"
assert_eq 'the closer directory wins over the one above it' 2 "$(guess '' /r/shop-api/lib/deep)"
# Two in the same session is exactly the case where guessing is worse than
# asking: sending a review to the wrong agent costs more than one keypress.
assert_eq 'two in the session, neither in this directory, is left alone' none \
  "$(guess 03_shop-api /r/nowhere)"
assert_eq 'but the one also in this directory wins' 1 "$(guess 03_shop-api /r/shop-api)"
assert_eq 'nothing matching is left alone' none "$(guess 09_other /r/nowhere)"
agent_cwd=(/r/same /r/same /r/x)
assert_eq 'two at the same depth is left alone' none "$(guess '' /r/same)"
agent_pane=()
assert_eq 'no agents at all is left alone' none "$(guess 01_dot-files /r/dot-files)"
unset -f guess
unset agent_pane agent_session agent_cwd

section 'preselect_agent: guesses once, and never over a choice'
# load_agent_sessions is a round trip; stubbed, so this tests the wiring round
# the guess rather than the listing.
load_agent_sessions() {
  agent_pane=(%7)
  agent_kind=(claude)
  agent_session=(01_dot-files)
  agent_cwd=("$PWD")
  agent_label=('01_dot-files:1  claude')
}
tmux() { preselect_tmux_args="$*"; }
agent_pane_cur=''; agent_label_cur=''; agent_guessed=0; preselect_done=0
shown_session=0; preselect_tmux_args=''
preselect_agent @1 01_dot-files
assert_eq 'it takes the agent in the session' '%7' "$agent_pane_cur"
assert_match 'the label carries the harness glyph' '01_dot-files:1' "$agent_label_cur"
assert_eq 'and is marked a guess, not a choice' 1 "$agent_guessed"
assert_eq 'it only runs once' 1 "$preselect_done"
assert_match 'the window is told, so a retarget keeps it' '@review_agent_guessed 1' \
  "$preselect_tmux_args"

# A review that already has an agent is left alone -- including one the reader
# chose, which is the case that matters.
agent_pane_cur=%99; agent_label_cur='chosen'; agent_guessed=0; preselect_tmux_args=''
preselect_agent @1 01_dot-files
assert_eq 'an agent already set is not replaced' '%99' "$agent_pane_cur"
assert_eq 'and nothing is written' '' "$preselect_tmux_args"
unset -f load_agent_sessions tmux
unset agent_pane_cur agent_label_cur agent_guessed preselect_done preselect_tmux_args shown_session

section 'file_at: the file a row belongs to'
file_rows=(10 50 120)
file_names=(bin/git-review tmux/scripts/review.sh README.md)
f() { file_at "$1" && printf '%s' "$REPLY"; }
assert_eq 'above the first header, nothing' '' "$(f 9)"
assert_eq 'the header row itself counts as inside its file' bin/git-review "$(f 10)"
assert_eq 'a row inside the first file' bin/git-review "$(f 49)"
assert_eq 'the next header switches file' tmux/scripts/review.sh "$(f 50)"
assert_eq 'the last file runs to the end' README.md "$(f 500)"
unset -f f
file_rows=(); file_names=()

section 'the sidebar tick survives the fields tmux leaves empty'
# Outside copy-mode scroll_position and copy_cursor_y are both empty, so the
# tick carries two adjacent separators. A tab separator would be folded into
# one by read -- tab is IFS whitespace -- and every field after them would
# shift two places left, which is how window_width came back as the zoom flag.
tick_fields() {
  local sep=$1 raw
  raw="0${sep}0${sep}${sep}${sep}165${sep}200${sep}44${sep}1${sep}0${sep}0"
  local in_mode hist scroll cy dw ww dh zoomed diff_active searching
  IFS=$sep read -r in_mode hist scroll cy dw ww dh zoomed diff_active searching <<<"$raw"
  printf '%s|%s|%s|%s|%s' "$dw" "$ww" "$dh" "$zoomed" "$searching"
}
assert_eq 'a unit separator keeps the empty fields in place' \
  '165|200|44|1|0' "$(tick_fields $'\x1f')"
assert_eq 'a tab would have shifted them, which is the bug this replaced' \
  '44|1|0|0|' "$(tick_fields $'\t')"
assert_eq 'the width derived while zoomed is the window width' 200 \
  "$(IFS=$'\x1f' read -r a b c d dw ww _ <<<"0"$'\x1f'"0"$'\x1f\x1f\x1f'"165"$'\x1f'"200"$'\x1f'"44"; printf '%s' "$ww")"
assert_eq 'and unzoomed it is the window less the diff pane and its border' 34 \
  "$(IFS=$'\x1f' read -r a b c d dw ww _ <<<"0"$'\x1f'"0"$'\x1f\x1f\x1f'"165"$'\x1f'"200"$'\x1f'"44"; printf '%s' "$((ww - dw - 1))")"
unset -f tick_fields

section 'render: a live search takes n/N off the diff stops'
out=$(render 0 60 20 diff 0 1 | strip)
assert_match 'n/N follow the match once a search is running' 'n/N match' "$out"
assert_eq 'and no longer claim to step any stop' 0 "$(grep -c 'n/N any' <<<"$out")"
# Wide enough for the whole row: the narrower forms drop ][ before they drop
# the keys that only exist here.
out=$(render 0 110 20 diff 0 1 | strip)
assert_match 'files keep their own key' '\]\[ file' "$out"
assert_match 'commits keep theirs' '}{ commit' "$out"
out=$(render 0 60 20 diff 0 0 | strip)
assert_match 'without a search they step any stop again' 'n/N any' "$out"
assert_eq 'the list legend is unaffected by a search' \
  "$(render 0 60 20 list 0 0 | strip | grep -c '^ list  ')" \
  "$(render 0 60 20 list 0 1 | strip | grep -c '^ list  ')"
unset -f git

section 'render_loading: centred, and says what it is waiting for'
change_plain='3 files  +40  -5'
change_col=$change_plain
out=$(render_loading 60 20 0 | strip)
assert_match 'names the range' 'base\.\.HEAD' "$out"
assert_match 'counts the commits' '10 commits' "$out"
assert_match 'carries the diffstat' '3 files  \+40  -5' "$out"
assert_match 'a spinner frame is present' "${loading_frames[0]}" "$(render_loading 60 20 0)"
assert_match 'the frame advances' "${loading_frames[3]}" "$(render_loading 60 20 3)"
assert_eq 'frames wrap round' "$(render_loading 60 20 0)" "$(render_loading 60 20 ${#loading_frames[@]})"
indent=$(render_loading 60 20 0 | strip | grep -o '^ *⣾' | head -1)
centred=0; ((${#indent} > 10)) || centred=1
assert_ok "$centred" 'the block is indented towards the centre' \
  '>10 leading spaces' "${#indent}"

section 'file_row_regex: matches delta file headers only'
re=$(file_row_regex)
matched=0; printf '\uf0f6 install.sh\n' | grep -qE "$re" || matched=1
assert_ok "$matched" 'matches a modified-file header'
matched=0; printf '\U000f0752 bin/git-review\n' | grep -qE "$re" || matched=1
assert_ok "$matched" 'matches an added-file header'
matched=0; printf 'commit deadbee\n' | grep -qvE "$re" || matched=1
assert_ok "$matched" 'ignores a commit header'
matched=0; printf '  some indented text\n' | grep -qvE "$re" || matched=1
assert_ok "$matched" 'ignores ordinary text'

section 'quit: back to the window the review was opened from'
quit_args=''
tmux() {
  case $1 in
    show-options) printf '%s' "$quit_back"; return 0 ;;
    *) quit_args+="[$*]" ;;
  esac
}
quit_back='@7'; quit_args=''; quit '@9'
assert_eq 'the stored window is selected and the review closed in one call' \
  "[select-window -t @7 ; kill-window -t @9]" "$quit_args"
quit_back=''; quit_args=''; quit '@9'
assert_eq 'with nowhere to go back to it just closes' '[kill-window -t @9]' "$quit_args"
# The window it was opened from can have been closed since; killing this one
# still has to happen.
tmux() {
  case $1 in
    show-options) printf '@7'; return 0 ;;
    select-window) return 1 ;;
    *) quit_args+="[$*]" ;;
  esac
}
quit_args=''; quit '@9'
assert_eq 'a stale return window falls back to closing this one' \
  '[kill-window -t @9]' "$quit_args"
unset -f tmux; unset quit_args quit_back

section 'place: the scrollback row asked for, under the cursor where it was'
place_args=''
tmux() { place_args+="[$*]"; }
place_args=''; place '%1' 100 10 90
assert_eq 'a row the view can reach needs only the scroll' \
  '[send-keys -X -t %1 goto-line 20]' "$place_args"
# hist + cy - target = 100 + 10 - 5 = 105, past the end of history, so the
# scroll stops at hist and the cursor covers what is left.
place_args=''; place '%1' 100 10 5
assert_match 'running out of history at the top is made up with the cursor' \
  'goto-line 100 ; send-keys -X -N 5 -t %1 cursor-up' "$place_args"
place_args=''; place '%1' 100 10 115
assert_match 'and at the bottom, in the other direction' \
  'goto-line 0 ; send-keys -X -N 5 -t %1 cursor-down' "$place_args"
unset -f tmux; unset place_args

section 'paint_index: draws the selection, or declines to'
paint_calls=''
render() { paint_calls+="[$*]"; }
paint_saved_shas=("${shas[@]+"${shas[@]}"}")
shas=(a b c); width=80; height=40; on_range=0; searching=0; on_session=0
diff_active=1; shown=-1; shown_focus=''
paint_calls=''; paint_index 1
assert_eq 'the focused pane is the diff while the diff has focus' \
  '[1 80 40 diff 0 0 0]' "$paint_calls"
assert_eq 'and what was drawn is remembered' '1 diff' "$shown $shown_focus"
diff_active=0; paint_calls=''; paint_index 2
assert_eq 'with the list focused the legend is the list one' \
  '[2 80 40 list 0 0 0]' "$paint_calls"
paint_calls=''; paint_index 9
assert_eq 'a commit that does not exist is not drawn' '' "$paint_calls"
paint_calls=''; paint_index -1
assert_eq 'nor is one before the first' '' "$paint_calls"
width=0; paint_calls=''; paint_index 0
assert_eq 'and nothing is drawn before the geometry is known' '' "$paint_calls"
width=80
restore_review

section 'select_index: paints now, moves later'
paint_index() { paint_calls+="(paint $1)"; }
select_saved_row_of=$(declare -p row_of 2>/dev/null || printf 'declare -A row_of=()')
declare -A row_of=([a]=10 [b]=20 [c]=30)
pending_row=-1; paint_calls=''; select_index 1
assert_eq 'the row the move will go to is remembered, not sent' 20 "$pending_row"
assert_eq 'and the selection is painted straight away' '(paint 1)' "$paint_calls"
pending_row=-1; paint_calls=''; select_index -5
assert_eq 'before the first commit selects the first' 10 "$pending_row"
pending_row=-1; paint_calls=''; select_index 99
assert_eq 'past the last selects the last' 30 "$pending_row"
# A commit whose header the row map has not reached yet has nowhere to move to.
unset 'row_of[b]'
pending_row=-1; paint_calls=''; select_index 1
assert_eq 'a commit with no row yet is left alone' -1 "$pending_row"
assert_eq 'and nothing is painted for it' '' "$paint_calls"
restore_review
eval "$select_saved_row_of"
unset select_saved_row_of

section 'flush_pending: one move, once the reader stops'
place() { flush_args="[$*]"; }
hist=100; cy=10; flush_args=''
pending_row=-1; expect_row=-1; flush_pending '%1'
assert_eq 'nothing pending sends nothing' '' "$flush_args"
pending_row=42; expect_row=7; flush_args=''; flush_pending '%1'
assert_eq 'a move still unconfirmed holds the next one back' '' "$flush_args"
assert_eq 'and the pending row survives to be sent later' 42 "$pending_row"
pending_row=42; expect_row=-1; expect_turns=9; flush_args=''; flush_pending '%1'
assert_eq 'otherwise it goes, from the position last reported' '[%1 100 10 42]' "$flush_args"
assert_eq 'the move becomes the one now outstanding' 42 "$expect_row"
assert_eq 'its patience starts over' 0 "$expect_turns"
assert_eq 'and nothing is left pending' -1 "$pending_row"
restore_review; unset flush_args paint_calls
shas=("${paint_saved_shas[@]+"${paint_saved_shas[@]}"}")
unset paint_saved_shas

section 'claim_width: asks for its share, once per geometry'
claim_args=''
tmux() { claim_args+="[$*]"; }
claim_saved_pane=${TMUX_PANE-}
window_seen=0
claim_args=''; claim_width '%2' 220 77 && claim_rc=0 || claim_rc=1
assert_eq 'a list already at its share asks for nothing' '' "$claim_args"
assert_eq 'and reports the tick can go on' 0 "$claim_rc"
# Inside the sidebar TMUX_PANE is the pane's own id, and it is preferred: the
# id passed in is the diff's, which is not the one to resize.
TMUX_PANE='%9'
window_seen=0; claim_args=''
claim_width '%2' 220 30 && claim_rc=0 || claim_rc=1
assert_eq 'one that is not asks for it, for its own pane' \
  '[resize-pane -x 77 -t %9]' "$claim_args"
assert_eq 'and reports the geometry is about to change' 1 "$claim_rc"
claim_args=''; claim_width '%2' 220 30 && claim_rc=0 || claim_rc=1
assert_eq 'the same window is not asked about twice' '' "$claim_args"
unset TMUX_PANE
window_seen=0; claim_args=''; claim_width '%2' 220 30
assert_eq 'without one it falls back to the pane it was given' \
  '[resize-pane -x 77 -t %2]' "$claim_args"
[[ -n $claim_saved_pane ]] && TMUX_PANE=$claim_saved_pane
unset -f tmux; unset claim_args claim_rc claim_saved_pane

section 'reveal_diff: the whole handover in one round trip'
reveal_args=''
tmux() { reveal_args="$*"; }
TMUX_PANE='%1'; reveal_diff
assert_eq 'it is one invocation' 1 "$(printf '%s' "$reveal_args" | grep -c .)"
assert_match 'copy-mode is entered before the rest of the diff lands' \
  'copy-mode -t %1' "$reveal_args"
assert_match 'and parked at the top' 'send-keys -X -t %1 history-top' "$reveal_args"
assert_match 'the pane is selected, which also unzooms' 'select-pane -t %1' "$reveal_args"
assert_match 'the list is told to stop waiting' "send-keys -t {bottom-left} z" "$reveal_args"
assert_match 'and the base the scroll is measured from is recorded' \
  'set-option -p -t %1 -F @review_hist_base' "$reveal_args"
unset -f tmux; unset reveal_args

section 'comment_send: pasted, not sent'
send_args=''
tmux() { send_args+="[$1]"; return 0; }
comment_send '%3' 'some text' && send_rc=0 || send_rc=1
assert_eq 'the buffer is set and then pasted' '[set-buffer][paste-buffer]' "$send_args"
assert_eq 'and it reports success' 0 "$send_rc"
tmux() { [[ $1 == set-buffer ]] && return 1; return 0; }
comment_send '%3' 'x' && send_rc=0 || send_rc=1
assert_eq 'a buffer that cannot be set is a failure' 1 "$send_rc"
tmux() { [[ $1 == paste-buffer ]] && return 1; return 0; }
comment_send '%3' 'x' && send_rc=0 || send_rc=1
assert_eq 'and so is a paste that does not land' 1 "$send_rc"
unset -f tmux; unset send_args send_rc

section 'holding: the list and the placeholder while the diff loads'
hold_calls=''
render() { hold_calls+="[render $1]"; }
render_loading() { hold_calls+="[loading $3]"; }
width=80; hdr_w=80; height=40; on_range=0; searching=0; on_session=0; spin=5
shown=3; hold_calls=''; hold_list </dev/null
assert_eq 'a list showing a later commit is redrawn against the first' \
  '[render 0]' "$hold_calls"
assert_eq 'and it is the first that is now shown' 0 "$shown"
hold_calls=''; hold_list </dev/null
assert_eq 'once it is there it is left alone' '' "$hold_calls"
spin=5; shown=3; hold_list <<<'z'
assert_eq 'a key from the diff pane takes the spinner back to the start' 0 "$spin"
spin=5; hold_calls=''; hold_placeholder </dev/null
assert_eq 'the placeholder draws the frame it is on' '[loading 5]' "$hold_calls"
assert_eq 'and moves to the next' 6 "$spin"
assert_eq 'the list is marked for a redraw from scratch' -2 "$shown"
spin=5; hold_placeholder <<<'z'
assert_eq 'a key resets the placeholder spinner too' 0 "$spin"
# While the diff renders, the list is zoomed over the whole window and draws at
# its width -- but the header is a pane of its own, still the width of the
# column, and painted at the list's width it wrapped every row it had.
paint_header() { hold_calls+="[header $1]"; }
width=120; hdr_w=34; hold_calls=''

hold_placeholder </dev/null
hold_list </dev/null

assert_eq 'the header is painted at its column, not at the zoomed list' \
  '[header 34][header 34]' "$(grep -o '\[header [0-9]*\]' <<<"$hold_calls" | tr -d '\n')"
restore_review; unset hold_calls hdr_w

section 'load_change_summary: the diffstat the placeholder shows'
change_plain=''; change_col=''
git() { printf ' 7 files changed, 120 insertions(+), 45 deletions(-)\n'; }
load_change_summary 'base..HEAD'
assert_eq 'files, insertions and deletions' '7 files  +120  -45' "$change_plain"
coloured=0; [[ $change_col == *"$added+120"* && $change_col == *"$removed-45"* ]] || coloured=1
assert_ok "$coloured" 'insertions and deletions carry the palette colours'
change_plain=''; change_col=''
git() { printf ' 1 file changed, 3 insertions(+)\n'; }
load_change_summary 'base..HEAD'
assert_eq 'one file is not pluralised, and deletions are left out' '1 file  +3' "$change_plain"
change_plain=''; change_col=''
git() { printf ' 2 files changed, 8 deletions(-)\n'; }
load_change_summary 'base..HEAD'
assert_eq 'a range that only deletes' '2 files  -8' "$change_plain"
change_plain='untouched'; change_col='untouched'
git() { printf '\n'; }
load_change_summary 'base..HEAD'
assert_eq 'nothing changed leaves the caller what it had' 'untouched' "$change_plain"
# The whole history is measured from the empty tree. git diff given the rev
# alone would measure the working tree against it, which on a clean checkout
# is nothing at all.
change_plain=''; change_col=''
git() {
  case $* in
    'hash-object -t tree /dev/null') printf 'e0\n' ;;
    'diff --shortstat e0 HEAD') printf ' 3 files changed, 9 insertions(+)\n' ;;
    *) printf ' 1 file changed, 1 insertion(+)\n' ;;
  esac
}
load_change_summary 'HEAD'
assert_eq 'every commit is the empty tree to HEAD' '3 files  +9' "$change_plain"
unset -f git

section 'review.sh: every verb reaches its handler'
# In a subshell each time, so the stubs cannot outlive the check and the real
# functions are still there for the tests that follow.
dispatch() {
  (
    open() { printf 'open(%s)' "$*"; }
    diff_pane_cmd() { printf 'diff(%s)' "$*"; }
    sidebar() { printf 'sidebar(%s)' "$*"; }
    jump() { printf 'jump(%s)' "$*"; }
    nav() { printf 'nav(%s)' "$*"; }
    keypress() { printf 'key(%s)' "$*"; }
    quit() { printf 'quit(%s)' "$*"; }
    retarget() { printf 'retarget(%s)' "$*"; }
    main "$@"
  )
}
assert_eq 'open carries the pane, the range and the window to go back to' \
  'open(%0 base..HEAD @3)' "$(dispatch open '%0' 'base..HEAD' '@3')"
assert_eq 'open with only a pane leaves the rest empty' 'open(%0  )' "$(dispatch open '%0')"
assert_eq 'diff carries the range and the width' 'diff(base..HEAD 142)' \
  "$(dispatch diff 'base..HEAD' 142)"
assert_eq 'sidebar carries the geometry too' \
  'sidebar(%1 %2 /dev/ttys1 base..HEAD 220 55)' \
  "$(dispatch sidebar '%1' '%2' /dev/ttys1 'base..HEAD' 220 55)"
assert_eq 'jump is handed everything it was given' 'jump(%1 next 100 20 3 7 9)' \
  "$(dispatch jump '%1' next 100 20 3 7 9)"
assert_eq 'nav takes a window, a direction and a kind' 'nav(@2 next file)' \
  "$(dispatch nav '@2' next file)"
assert_eq 'key takes a window and a key' 'key(@2 j)' "$(dispatch key '@2' j)"
assert_eq 'quit takes the window to close' 'quit(@2)' "$(dispatch quit '@2')"
assert_eq 'retarget takes the window and the new range' 'retarget(@2 HEAD~3..HEAD)' \
  "$(dispatch retarget '@2' 'HEAD~3..HEAD')"
dispatch >/dev/null 2>&1
assert_eq 'no verb at all is a usage error' 64 "$?"
dispatch nonsense >/dev/null 2>&1
assert_eq 'and so is one that means nothing' 64 "$?"
unset -f dispatch

section 'open: both panes, told their geometry rather than negotiating it'
open_cwd=$PWD
open_dir=$(mktemp -d)
open_log=$(mktemp)
open_info() { printf '%s\x1f%s\x1f%s\x1f%s\x1f%s' "$open_dir" main '@1' 220 55; }
# Written to a file, not a variable: new-window is read through $(...), so a
# stub that only assigned would record it in a subshell and lose it. -p is what
# separates the one query open makes from the message it shows on failure.
tmux() {
  case $* in
    'display-message -p'*) open_info; return 0 ;;
  esac
  printf '[%s]' "$*" >>"$open_log"
  [[ $1 == new-window ]] && printf '%%7'
  # The header split reports back the pane it made and the tty the sidebar
  # paints it through; the list split reports nothing, because nothing asks.
  [[ $1 == split-window && $* == *pane_tty* ]] && printf '%%8 /dev/ttys9'
  [[ $1 == split-window && $* != *pane_tty* && $* == *-P* ]] && printf '%%9'
  return 0
}
calls() { open_calls=$(cat "$open_log"); : >"$open_log"; }
gr_resolve_range() { REPLY='base..HEAD'; return 0; }
# A range that was asked for is read by git before anything is built round it.
git() { [[ $1 == rev-list ]] && printf 'c1\n'; return 0; }
self='/plugin/review.sh'
open '%0'
cd "$open_cwd" || :
calls
assert_eq 'a review that opens hands retarget its diff pane' '%7' "$opened"
assert_match 'the diff pane is a new window named for the range' \
  'new-window .*-n base\.\.HEAD review' "$open_calls"
# 220 less the 77 the list takes and its border is 142 for the diff pane, and
# delta is told two less than that: the column the marks sit in and its border,
# which are the only cells the diff gives up for good. The other thirty-nine
# come out of the list, and only while the pane is being read.
assert_match 'and it is handed the width delta must render at' \
  'review\.sh diff base\.\.HEAD 140' "$open_calls"
assert_match 'with the rest reserved for the comments pane' \
  '@review_gutter_w 40' "$open_calls"
assert_match 'the header is split off it at its final width' \
  'split-window -hb -l 77 -t %7 .*review\.sh header %7' "$open_calls"
assert_match 'and the list under the header, the window less the header' \
  'split-window -v -l 50 -t %8' "$open_calls"
assert_match 'and it is recorded, because it can no longer be searched for' \
  '@review_list_pane %9' "$open_calls"
assert_match 'the sidebar is told the geometry, so it need ask tmux nothing' \
  'sidebar %7 %8 /dev/ttys9 base\.\.HEAD 220 55' "$open_calls"
assert_match 'the split and the zoom are one invocation, on the new pane' \
  'split-window -v .*; resize-pane -Z' "$open_calls"
assert_match 'the window is marked as a review, for the q binding' \
  'set-option -w -t %7 @review 1' "$open_calls"
assert_match 'q is told where to go back to' \
  'set-option -w -t %7 @review_return @1' "$open_calls"
assert_match 'and nav is told which pane holds the diff' \
  '@review_diff_pane %7' "$open_calls"
# A retarget passes the window the first review was opened from.
open '%0' 'HEAD~3..HEAD' '@4'; cd "$open_cwd" || :; calls
assert_match 'a window passed in wins over the one the pane is in' \
  '@review_return @4' "$open_calls"
# Nothing is opened over a directory that has gone.
open_info() { printf '%s\x1f%s\x1f%s\x1f%s\x1f%s' /no/such/dir main '@1' 220 55; }
open '%0'; cd "$open_cwd" || :; calls
assert_eq 'a path that cannot be reached says so and opens nothing' 0 \
  "$(grep -c 'new-window' <<<"$open_calls")"
assert_match 'and it says which one' 'cannot reach /no/such/dir' "$open_calls"
# And nothing over a repository with no commits to show.
open_info() { printf '%s\x1f%s\x1f%s\x1f%s\x1f%s' "$open_dir" main '@1' 220 55; }
gr_resolve_range() { return 1; }
open '%0'; cd "$open_cwd" || :; calls
assert_eq 'a range that will not resolve opens nothing either' 0 \
  "$(grep -c 'new-window' <<<"$open_calls")"
assert_match 'and says why' 'no commits to review' "$open_calls"
assert_eq 'and retarget is told nothing opened' '' "$opened"
# A range that was asked for and resolves to text git has nothing for -- a rev
# that was never there, a base level with HEAD -- is refused the same way.
gr_resolve_range() { REPLY='gone..HEAD'; return 0; }
git() { return 128; }
open '%0' 'gone'; cd "$open_cwd" || :; calls
assert_eq 'a range with no commits in it opens nothing' 0 \
  "$(grep -c 'new-window' <<<"$open_calls")"
assert_match 'and says which range it was' 'no commits to review in gone' "$open_calls"
assert_eq 'and retarget is told so' '' "$opened"
unset -f tmux open_info calls git
restore_review
rmdir "$open_dir" 2>/dev/null || :; rm -f "$open_log"
unset open_calls open_cwd open_dir open_log

section 'retarget: a new range in the same place'
retarget_calls=''
tmux() {
  case "$*" in
    *@review_diff_pane*) printf '%s' "$retarget_pane" ;;
    *@review_return*) printf '@4' ;;
    *) retarget_calls+="[$*]" ;;
  esac
  return 0
}
open() { retarget_calls+="[open $*]"; opened='%12'; }
retarget_pane='%7'; retarget_calls=''; retarget '@9' 'HEAD~5..HEAD'
assert_match 'the new review is opened over the old pane' \
  'open %7 HEAD~5\.\.HEAD @4' "$retarget_calls"
assert_match 'and the window it replaces is closed afterwards' \
  'kill-window -t @9' "$retarget_calls"
# A typed range that open refuses leaves the reader in the review they had,
# not in whatever window was next to it.
open() { retarget_calls+="[open $*]"; opened=''; }
retarget_pane='%7'; retarget_calls=''; retarget '@9' 'gone'
assert_eq 'a range open refuses closes nothing' '[open %7 gone @4]' "$retarget_calls"
retarget_pane=''; retarget_calls=''; retarget '@9' 'HEAD~5..HEAD'
assert_eq 'a window that is not a review is left alone' '' "$retarget_calls"
unset -f tmux; restore_review; unset retarget_calls retarget_pane

section 'keypress: the key goes to the list, whichever pane is focused'
# Both panes are read off the window rather than searched for. "The pane that
# is not the diff" was two panes the moment the header was split off, and the
# header is the one a search finds first.
key_calls=''
tmux() {
  case $1 in
    show-options)
      case $* in
        *@review_diff_pane*) printf '%s' "$key_dpane" ;;
        *@review_list_pane*) printf '%s' "$key_list" ;;
      esac ;;
    *) key_calls+="[$*]" ;;
  esac
  return 0
}
key_dpane='%7'; key_list='%8'; key_calls=''; keypress '@9' c
assert_eq 'the list pane gets it, by the id open recorded' '[send-keys -t %8 c]' "$key_calls"
key_dpane=''; key_calls=''; keypress '@9' c
assert_eq 'a window with no diff pane recorded takes no key' '' "$key_calls"
# A window whose only pane is the diff has no list to hand anything to.
tmux() {
  case $1 in
    show-options)
      # The diff is recorded, the list is not -- a window half set up, which
      # is what a review that failed part way through leaves behind.
      case $* in
        *@review_diff_pane*) printf '%%7' ;;
      esac ;;
    *) key_calls+="[$*]" ;;
  esac
  return 0
}
key_calls=''; keypress '@9' c
assert_eq 'and neither does one with no list recorded' '' "$key_calls"
unset -f tmux; unset key_calls key_dpane

section 'nav: the same jump, addressed by window'
nav_jump=''
jump() { nav_jump="$*"; }
tmux() {
  case $1 in
    show-options) printf '%s' "$nav_pane" ;;
    display-message) printf '%s' "$nav_state" ;;
  esac
  return 0
}
nav_pane='%7'; nav_state=$'1\x1f100\x1f20\x1f3\x1f5 9 40'
nav_jump=''; nav '@9' next file
assert_eq 'the rows arrive as separate arguments, not one string' \
  '%7 next 100 20 3 5 9 40' "$nav_jump"
# Outside copy-mode there is no cursor to step from.
nav_state=$'0\x1f100\x1f20\x1f3\x1f5 9 40'
nav_jump=''; nav '@9' next file
assert_eq 'a pane that is not being read is not moved' '' "$nav_jump"
nav_pane=''; nav_jump=''; nav '@9' next file
assert_eq 'and neither is a window that is not a review' '' "$nav_jump"
unset -f tmux; restore_review; unset nav_jump nav_pane nav_state

section 'settle_view: the finished grid, with the reader left where they were'
settle_args=''
tmux() {
  case $1 in
    display-message) printf '%s' "$settle_state"; return 0 ;;
    *) settle_args="$*"; return 0 ;;
  esac
}
TMUX_PANE='%7'
# base 100, scroll 100, cy 0: the reader is at the top, which is row 0, and
# history has grown to 4000 behind them.
settle_state=$'100\x1f100\x1f0\x1f4000'; settle_args=''; settle_view
assert_match 'copy-mode is left and re-entered, so the whole grid is readable' \
  'cancel ; copy-mode -t %7' "$settle_args"
assert_match 'the reader is put back where they were' 'goto-line 4000' "$settle_args"
assert_match 'the cursor is taken to the top of the view' 'top-line' "$settle_args"
assert_match 'and the base the scroll is measured from is reset to the live size' \
  'set-option -p -t %7 -F @review_hist_base #\{history_size\}' "$settle_args"
# Ten rows down: row 10, so the view stops ten short of the end.
settle_state=$'100\x1f100\x1f10\x1f4000'; settle_args=''; settle_view
assert_match 'a reader part-way down keeps their distance from the end' \
  'goto-line 3990' "$settle_args"
settle_state=$'\x1f\x1f\x1f'; settle_args=''; settle_view
assert_eq 'a pane that reports nothing is left alone' '' "$settle_args"
unset -f tmux; unset settle_args settle_state

section 'diff_pane_cmd: the head of the diff, then the rest behind the reader'
diff_events=''
plan_chunks() { chunks=("${diff_chunks[@]}"); }
reveal_diff() { diff_events+='[reveal]'; }
settle_view() { diff_events+='[settle]'; }
quit() { diff_events+="[quit $1]"; }
git() { diff_events+="[git ${*: -1}]"; diff_pager=$GIT_PAGER; }
tmux() { diff_events+="[tmux $*]"; }
TMUX_PANE='%7'
diff_cache=$(render_file %7)
printf 'a render left by a review before\n' >"$diff_cache"
diff_chunks=(c1 'c1..HEAD'); diff_events=''
diff_pane_cmd 'base..HEAD' 142 </dev/null
# What the pane shows is kept as well, so that a fold can be drawn from it
# again without running git or delta. tee, so the bytes are the pane's own.
assert_eq 'delta writes the pane and the render the folds are drawn from' \
  "delta --paging=never --width=142 | tee -a $(printf '%q' "$diff_cache")" "$diff_pager"
assert_eq 'which starts empty, rather than behind a review before it' 0 \
  "$(wc -c <"$diff_cache" | tr -d ' ')"
assert_match 'and the width it was drawn at is published with the rest' \
  '@review_render_w 142' "$diff_events"
assert_match 'the first commit is written before anything else' \
  '^\[git c1\]\[reveal\]' "$diff_events"
assert_match 'the reader is handed the pane before the rest arrives' \
  'reveal\]\[git c1\.\.HEAD\]' "$diff_events"
assert_eq 'and the view is settled once, after the last chunk' 1 \
  "$(grep -c '\[settle\]' <<<"$diff_events")"
assert_match 'the list is told the diff has landed' '@review_loaded 1' "$diff_events"
assert_match 'and woken, in the same invocation' 'send-keys -t {bottom-left} z' "$diff_events"
assert_match 'the pane closes the review when it is dismissed' 'quit %7' "$diff_events"
# The last two arguments, which for a chunk handed over whole would be the
# stat width and the chunk.
diff_chunks=(c1 'c1..HEAD ^base'); diff_events=''
git() { diff_events+="[git ${*: -2}]"; }
diff_pane_cmd 'base..HEAD' 142 </dev/null
assert_match 'a chunk of two revs reaches git as two, so the base still bounds it' \
  '\[git c1\.\.HEAD \^base\]' "$diff_events"
git() { diff_events+="[git ${*: -1}]"; diff_pager=$GIT_PAGER; }
# One chunk means one pass and nothing appended behind the reader, so there is
# no stranded grid to re-enter.
diff_chunks=('base..HEAD'); diff_events=''
diff_pane_cmd 'base..HEAD' 142 </dev/null
assert_eq 'a review small enough not to be split does not settle' 0 \
  "$(grep -c '\[settle\]' <<<"$diff_events")"
assert_eq 'and reveals once' 1 "$(grep -c '\[reveal\]' <<<"$diff_events")"
unset -f git tmux
restore_review
/bin/rm -f "$diff_cache"
unset diff_events diff_chunks diff_cache diff_pager

section 'jump: steps from where the keys asked to be, not where the pane got to'
jump_calls=''
place() { jump_calls+="[place $*]"; }
paint_index() { jump_calls+="[paint $1]"; }
jump_saved_shas=("${shas[@]+"${shas[@]}"}")
shas=(c0 c1 c2); width=0; at_row=-1; pending_row=-1
# hist 100, scroll 100, cy 0: the cursor is at row 0, so the next stop is 5.
jump_calls=''; jump '%7' next 100 100 0 5 9 40
assert_eq 'outside the list the pane is moved directly' '[place %7 100 0 5]' "$jump_calls"
jump_calls=''; jump '%7' prev 100 60 0 5 9 40
assert_eq 'prev takes the last stop before the cursor' '[place %7 100 0 9]' "$jump_calls"
jump_calls=''; jump '%7' last 100 100 0 5 9 40
assert_eq 'last goes to the end of the list' '[place %7 100 0 40]' "$jump_calls"
jump_calls=''; jump '%7' first 100 60 0 5 9 40
assert_eq 'first goes back to the start' '[place %7 100 0 5]' "$jump_calls"
jump_calls=''; jump '%7' next 100 60 0 40
assert_eq 'a jump with nowhere left to go does nothing' '' "$jump_calls"
# The keys run ahead of the pane: at_row is where they have asked to be, and a
# second j has to step from there or it recomputes the same target and is lost.
at_row=9; jump_calls=''; jump '%7' next 100 100 0 5 9 40
assert_eq 'a queued move is what the next jump steps from' '[place %7 100 0 40]' "$jump_calls"
at_row=-1
jump_calls=''; jump '%7' next 100 '' 0 5 9 40
assert_eq 'a pane not in copy-mode reports no scroll, and is left alone' '' "$jump_calls"
jump_calls=''; jump '%7' next 100 100 0
assert_eq 'and so is a kind of stop the window has none of' '' "$jump_calls"
# Inside the sidebar's loop the move is held for flush_pending instead.
width=80; declare -A row_of=([c0]=5 [c1]=9 [c2]=40)
jump_calls=''; pending_row=-1; jump '%7' next 100 100 0 5 9 40
assert_eq 'in the list the move is queued, not sent' '' "$(grep -o 'place' <<<"$jump_calls")"
assert_eq 'the row it will go to is remembered' 5 "$pending_row"
assert_match 'and the selection is painted at once' 'paint' "$jump_calls"
width=0
restore_review
shas=("${jump_saved_shas[@]+"${jump_saved_shas[@]}"}")
unset jump_calls jump_saved_shas

section 'load_agent_sessions: which panes are running an agent'
tmux() {
  printf '%s\n' \
    "%1${US}claude${US}@1${US}main${US}1${US}api${US}busy${US}/w/api" \
    "%2${US}codex${US}@2${US}main${US}2${US}web${US}${US}/w/web" \
    "%3${US}2.1.4${US}@3${US}side${US}3${US}cli${US}idle${US}/w/cli" \
    "%4${US}zsh${US}@4${US}main${US}4${US}shell${US}${US}/w/x" \
    "${US}${US}${US}${US}${US}${US}${US}"
}
US=$'\x1f'
load_agent_sessions
assert_eq 'only the panes running an agent are kept' 3 "${#agent_pane[@]}"
assert_eq 'claude by name' claude "${agent_kind[0]}"
assert_eq 'codex by name' codex "${agent_kind[1]}"
# Claude Code execs its release directly, so the process name is the version.
assert_eq 'and claude by version, which is what its process is called' \
  claude "${agent_kind[2]}"
assert_eq 'a pane with no state is idle rather than empty' idle "${agent_state[1]}"
assert_eq 'the state is kept when there is one' busy "${agent_state[0]}"
assert_eq 'the label names the session, the index and the window' \
  'main:1  api' "${agent_label[0]}"
assert_eq 'and the directory comes along for the guess' /w/cli "${agent_cwd[2]}"
load_agent_sessions '@2'
assert_eq 'the window asked to be skipped is left out' 2 "${#agent_pane[@]}"
assert_eq 'and it is the right one that went' '%1 %3' "${agent_pane[*]}"

section 'load_pick_sessions: the agents, as rows of the picker'
# The same stub: load_pick_sessions reads its rows through load_agent_sessions,
# so a real tmux here would offer whatever the machine happens to be running.
load_pick_sessions '@9'
assert_eq 'one row per agent' 3 "${#pick_kind[@]}"
assert_eq 'each is a session row' session "${pick_kind[0]}"
assert_match 'a claude pane takes the claude glyph' '󰚩' "${pick_label[0]}"
assert_match 'and a codex pane its own' '󰻟' "${pick_label[1]}"
assert_match 'the glyph is followed by two spaces, since it takes two cells' \
  '󰚩  main:1' "${pick_label[0]}"
assert_eq 'the state is shown in the second column' busy "${pick_extra[0]}"
assert_eq 'and the payload carries the pane the comments go to' \
  '%1' "${pick_payload[0]%%$'\x1f'*}"
tmux() { :; }
load_pick_sessions '@9'
assert_eq 'with no agent running there is one row saying so' 1 "${#pick_kind[@]}"
assert_eq 'and it is not something that can be chosen' none "${pick_kind[0]}"
assert_eq 'a row that says what it says' 'no agent is running' "${pick_label[0]}"
unset -f tmux

section 'apply_pick_session: the agent is remembered on the window'
session_args=''
tmux() { session_args="$*"; }
pick_kind=(session none); pick_payload=("%5${US}󰚩  main:2  web" '')
agent_pane_cur=''; agent_label_cur=''; agent_guessed=1
apply_pick_session '@9' 0
assert_eq 'the pane a comment is pasted into' '%5' "$agent_pane_cur"
assert_eq 'and the label the row shows' '󰚩  main:2  web' "$agent_label_cur"
assert_eq 'a chosen agent is no longer a guess' 0 "$agent_guessed"
assert_match 'the choice is set on the window, so a retarget keeps it' \
  '@review_agent_pane %5' "$session_args"
assert_match 'with its label' '@review_agent_label' "$session_args"
assert_match 'and the guess flag cleared, in the same invocation' \
  '@review_agent_guessed' "$session_args"
session_args=''; apply_pick_session '@9' 1
assert_eq 'the row that is not an agent chooses nothing' '' "$session_args"
unset -f tmux; unset session_args

section 'apply_pick: a range replaces the window, anything else is a popup'
pick_args=''
retarget() { pick_args+="[retarget $*]"; }
tmux() {
  case $1 in
    display-message) printf '/w/repo'; return 0 ;;
    *) pick_args+="[$*]" ;;
  esac
}
git_review='/plugin/bin/git-review'; self='/plugin/review.sh'
pick_kind=(range wip staged stash prompt-count prompt-range none)
pick_payload=('HEAD~4..HEAD' '' '' 'stash@{2}' '32' 'HEAD' '')
pick_args=''; apply_pick '%7' '@9' 0
assert_eq 'a range is opened over this window' '[retarget @9 HEAD~4..HEAD]' "$pick_args"
pick_args=''; apply_pick '%7' '@9' 1
assert_match 'the working tree has no commits to list, so it is a popup' \
  'display-popup .*-d /w/repo /plugin/bin/git-review --wip' "$pick_args"
pick_args=''; apply_pick '%7' '@9' 2
assert_match 'and so does the index' 'git-review --staged' "$pick_args"
pick_args=''; apply_pick '%7' '@9' 3
assert_match 'a stash is quoted, braces and all' \
  'git-review --stash stash@.\{2.\}' "$pick_args"
pick_args=''; apply_pick '%7' '@9' 4
assert_match 'a count is asked for, with how far back there is to go' \
  'command-prompt -p review the last n commits \(1-32\): -I 1' "$pick_args"
assert_match 'and answered by retargeting this window' \
  'run-shell "/plugin/review.sh retarget @9 %%"' "$pick_args"
pick_args=''; apply_pick '%7' '@9' 5
assert_match 'a range is asked for, seeded with the one on screen' \
  'command-prompt -p review: -I HEAD run-shell' "$pick_args"
pick_args=''; apply_pick '%7' '@9' 6
assert_eq 'the row that says no agent is running does nothing' '' "$pick_args"
unset -f tmux; restore_review; unset pick_args

section 'clear_comments: asks first, because nothing brings it back'
cstore=$(comment_file /tmp/test-repo 'clear..HEAD')
/bin/rm -f "$cstore"
said=''
tmux() { said+="[$*]"; return 0; }
clear_comments "$cstore"
assert_eq 'an empty queue is not something to confirm' 1 $?
assert_match 'and says so' 'nothing queued to clear' "$said"
comment_add "$cstore" aaa1111 bin/git-review 24 24 '' 'first'
comment_add "$cstore" bbb2222 bin/git-review 30 30 '' 'second'
# The answer is read from this process's stdin, so the tests feed it one.
said=''
clear_comments "$cstore" <<<'n'
assert_eq 'anything but y keeps the queue' 1 $?
assert_eq 'and the queue is still there' 2 "$(comment_count "$cstore")"
assert_match 'it counts what it is about to discard' 'discard 2 queued comments' "$said"
assert_match 'and says it kept them' 'review: kept' "$said"
said=''
clear_comments "$cstore" <<<'y'
assert_eq 'y discards it' 0 $?
assert_eq 'and the queue is gone' 0 "$(comment_count "$cstore")"
assert_match 'saying how many went' 'review: 2 discarded' "$said"
# One comment is a comment, not comments.
comment_add "$cstore" ccc3333 f 1 1 '' 'only'
said=''
clear_comments "$cstore" <<<'y'
assert_match 'a single one is asked about in the singular' 'discard 1 queued comment\?' "$said"
/bin/rm -f "$cstore"
unset -f tmux
unset cstore said

section 'clear_comments: y is lent to the read for the length of the question'
# The bug this is here for. R is offered from the diff pane, the question it
# asks is answered by a raw read on the list's own stdin, and y in the diff is
# tmux-yank's -- so the answer went to the clipboard, the read timed out ten
# seconds later, and the queue was still there every time. d never had the
# problem because it is offered only in the comments pane, which forwards its
# own y, which is why deleting one worked while clearing them all did not.
#
# The half of the fix that lives here is the flag the binding is guarded on.
# Asserted as the whole sequence rather than call by call, because raised and
# never lowered reads exactly like the working case one call at a time, and it
# would keep y away from the yank for the rest of the review.
askstore=$(comment_file /tmp/test-repo 'asking..HEAD')
/bin/rm -f "$askstore"
asked=''
tmux() { asked+="[$*]"; return 0; }
ask_saved_pane=${TMUX_PANE-}
# The option goes on the window the read is waiting in, which is this process's
# own pane -- the same one claim_width resizes.
TMUX_PANE='%9'
comment_add "$askstore" aaa1111 bin/git-review 24 24 '' 'first'
clear_comments "$askstore" <<<'y'
assert_eq 'up before the question is drawn, down before the queue goes' \
  '[set-option -w -t %9 @review_asking 1][display-message -d 8000 review: discard 1 queued comment? y to discard, any other key to keep][set-option -w -t %9 -u @review_asking][display-message review: 1 discarded]' \
  "$asked"
comment_add "$askstore" bbb2222 bin/git-review 30 30 '' 'second'
asked=''
clear_comments "$askstore" <<<'n'
assert_eq 'and down again on the answer that keeps the queue' \
  '[set-option -w -t %9 @review_asking 1][display-message -d 8000 review: discard 1 queued comment? y to discard, any other key to keep][set-option -w -t %9 -u @review_asking][display-message review: kept]' \
  "$asked"
# Nothing queued is nothing to ask about, so there is nothing to lend y for
# either -- and a flag raised here would never come down, because the reader is
# never given the chance to answer.
/bin/rm -f "$askstore"
asked=''
clear_comments "$askstore"
assert_eq 'an empty queue never raises it at all' \
  '[display-message review: nothing queued to clear]' "$asked"
[[ -n $ask_saved_pane ]] && TMUX_PANE=$ask_saved_pane
unset -f tmux
unset askstore asked ask_saved_pane

section 'send_comments: to the agent that was chosen, if it is still there'
send_msgs=''
comment_send() { send_msgs+="[paste $1]"; return "$send_paste_rc"; }
tmux() {
  case $1 in
    display-message)
      [[ $2 == -p ]] && return "$send_pane_rc"
      send_msgs+="[say ${*:2}]"; return 0 ;;
    *) send_msgs+="[$*]" ;;
  esac
  return 0
}
send_store=$(mktemp); /bin/rm -f "$send_store"
send_paste_rc=0; send_pane_rc=0
agent_pane_cur=''; agent_label_cur=''
send_msgs=''; send_comments '@9' "$send_store" 'base..HEAD'
assert_match 'with no agent chosen it says to choose one' 'pick an agent first' "$send_msgs"
agent_pane_cur='%5'; agent_label_cur='󰚩  main:2  web'
send_pane_rc=1; send_msgs=''; send_comments '@9' "$send_store" 'base..HEAD'
assert_match 'an agent that has exited since is reported, not pasted into' \
  'is gone -- pick another' "$send_msgs"
send_pane_rc=0; send_msgs=''; send_comments '@9' "$send_store" 'base..HEAD'
assert_match 'an empty queue is refused rather than sent blank' \
  'nothing queued to send' "$send_msgs"
comment_add "$send_store" abc1234 f.sh 1 1 'x' 'a comment'
send_paste_rc=1; send_msgs=''; send_comments '@9' "$send_store" 'base..HEAD'
assert_match 'a paste that will not land says so' 'could not paste' "$send_msgs"
assert_eq 'and the queue is kept, so nothing is lost' 1 "$(comment_count "$send_store")"
send_paste_rc=0; comments=99
send_msgs=''; send_comments '@9' "$send_store" 'base..HEAD'
assert_match 'otherwise it is pasted into the agent pane' '\[paste %5\]' "$send_msgs"
assert_match 'the count and the agent are named' '1 sent to 󰚩  main:2  web' "$send_msgs"
assert_match 'and it says the agent still has to be told to run it' \
  'press enter to run it' "$send_msgs"
# Sending is a handover, so the focus goes with it -- being told what happened
# from a window you are not in is no use.
assert_match 'the agent window is brought forward' \
  'switch-client -t %5 ; select-window -t %5 ; select-pane -t %5' "$send_msgs"
assert_eq 'the queue is emptied' 0 "$(comment_count "$send_store")"
assert_eq 'and the badge with it' 0 "$comments"
/bin/rm -f "$send_store"
unset -f tmux; restore_review
unset send_msgs send_store send_paste_rc send_pane_rc

section "get_tmux_option: the user's value, or the plugin's default"
opt_value=''
tmux() { printf '%s\n' "$opt_value"; }
# shellcheck source-path=SCRIPTDIR source=../scripts/helpers.sh
source "$plugin/scripts/helpers.sh"
opt_value='C'; assert_eq 'a value that is set is used' C "$(get_tmux_option '@review-key' g)"
opt_value=''; assert_eq 'one that is not falls back to the default' g \
  "$(get_tmux_option '@review-key' g)"
unset -f tmux; unset opt_value

section 'review.tmux: every key bound, in one invocation'
tmux_log=$(mktemp)
fake_bin=$(mktemp -d)
cat >"$fake_bin/tmux" <<'FAKE'
#!/usr/bin/env bash
# show-option is how the entry point reads its two settable keys, and list-keys
# how it reads back the yank it has to leave behind the y it borrows;
# everything else is the one call that binds.
if [[ $1 == show-option ]]; then
  printf '\n'
  exit 0
fi
if [[ $1 == list-keys ]]; then
  printf '%s\n' "${YANK_Y-}"
  exit 0
fi
printf '%s\n' "$*" >>"$TMUX_LOG"
FAKE
chmod +x "$fake_bin/tmux"
# What tmux-yank leaves in the copy-mode-vi table, printed the way list-keys
# prints it -- a bind-key command, so that its output can be fed straight back
# in. What the fallback wants is the command on the end of it.
yank_binding='bind-key -T copy-mode-vi y send-keys -X copy-pipe pbcopy'
YANK_Y=$yank_binding TMUX_LOG=$tmux_log PATH="$fake_bin:$PATH" "$plugin/review.tmux"
bound=$(cat "$tmux_log")
assert_eq 'the bindings are sent as one call, not a dozen' 1 "$(grep -c . <<<"$bound")"
assert_match 'prefix+g opens a review, in the background' \
  'bind-key g run-shell -b .*/scripts/review\.sh open #\{pane_id\}' "$bound"
assert_match 'prefix+G is the working tree, in a popup' \
  'bind-key G display-popup .*/bin/git-review --wip' "$bound"
assert_eq 'seventeen keys are bound in copy-mode' 17 \
  "$(grep -o 'bind-key -T copy-mode-vi' <<<"$bound" | grep -c .)"
# C and R are bound from the start even though the legend only offers them once
# there is something queued: a binding that came and went would mean reloading
# the configuration mid-review, which takes the review's own bindings with it.
for k in ']' '\[' '}' '{' c C R s a n N q y Enter '=' '<' '>'; do
  matched=0; grep -q -- "bind-key -T copy-mode-vi $k " <<<"$bound" || matched=1
  assert_ok "$matched" "copy-mode $k is bound"
done
# y is why R never worked from the diff. The list asks its question by blocking
# on a raw read of its own stdin, and every pane that offers R has to send the
# answer there -- the comments pane and the header forward their own y, and the
# diff, which has no loop of its own, had nothing bound at all. So the answer
# went to tmux-yank, the read timed out ten seconds later, and the queue was
# still there. d was never offered here, which is why deleting one comment
# worked while clearing them all did not.
#
# The whole binding, because the half of it that matters is the half that is
# easy to lose: routed while a question is up, and the yank it displaced put
# back underneath for the rest of the time.
ybound=${bound#*bind-key -T copy-mode-vi y }
ybound=${ybound%% ; *}
assert_eq 'y answers a question while one is up, and yanks while none is' \
  "if-shell -F #{&&:#{&&:#{&&:#{@review},#{==:#{pane_mode},copy-mode}},#{==:#{pane_at_left},0}},#{@review_asking}} send-keys -t '{bottom-left}' y ${yank_binding#*copy-mode-vi y }" \
  "$ybound"
# The fold keys go to the list's loop like every other key there: the set of
# collapsed items is held in it, and so is the map that says what is under the
# cursor. None of them means anything to tmux's own copy-mode-vi, so there is
# no fallback to keep -- only the unzoom the other routed keys fall back to.
for k in '=' '<' '>'; do
  assert_match "copy-mode $k is routed to the list from a review diff" \
    "bind-key -T copy-mode-vi $k if-shell -F [^ ]*pane_at_left[^ ]* send-keys -t '\\{bottom-left\\}' $k" \
    "$bound"
done
assert_match 'every one is guarded on the window being a review' \
  '@review' "$bound"
assert_match 'and on the pane being read rather than showing output' \
  'pane_mode},copy-mode' "$bound"
assert_match 'n falls back to search-again outside a review' \
  "send-keys -X search-again" "$bound"
assert_match 'and Enter to the yank that cancels' 'copy-pipe-and-cancel' "$bound"
# A y with nothing bound to it has no yank to put back, and if-shell is content
# with the two arguments.
: >"$tmux_log"
YANK_Y='' TMUX_LOG=$tmux_log PATH="$fake_bin:$PATH" "$plugin/review.tmux"
bound=$(cat "$tmux_log")
ybound=${bound#*bind-key -T copy-mode-vi y }
ybound=${ybound%% ; *}
assert_eq 'a y that was never bound is routed and nothing more' \
  "if-shell -F #{&&:#{&&:#{&&:#{@review},#{==:#{pane_mode},copy-mode}},#{==:#{pane_at_left},0}},#{@review_asking}} send-keys -t '{bottom-left}' y" \
  "$ybound"
# Sourced again without tpm having re-bound y first, which is what reloading
# this file on its own does. Read back and wrapped a second time, the binding
# would nest inside itself and grow a level on every reload.
: >"$tmux_log"
YANK_Y="bind-key -T copy-mode-vi y $ybound" TMUX_LOG=$tmux_log \
  PATH="$fake_bin:$PATH" "$plugin/review.tmux"
assert_eq 'the one already in place is left exactly as it is' 0 \
  "$(grep -c -- 'bind-key -T copy-mode-vi y ' "$tmux_log")"
# The two keys that can be moved.
: >"$tmux_log"
cat >"$fake_bin/tmux" <<'FAKE'
#!/usr/bin/env bash
if [[ $1 == show-option ]]; then
  case $3 in
    '@review-key') printf 'R\n' ;;
    '@review-wip-key') printf 'W\n' ;;
  esac
  exit 0
fi
if [[ $1 == list-keys ]]; then
  printf '%s\n' "${YANK_Y-}"
  exit 0
fi
printf '%s\n' "$*" >>"$TMUX_LOG"
FAKE
chmod +x "$fake_bin/tmux"
TMUX_LOG=$tmux_log PATH="$fake_bin:$PATH" "$plugin/review.tmux"
bound=$(cat "$tmux_log")
assert_match 'a key set by the user is the one bound' 'bind-key R run-shell' "$bound"
assert_match 'and so is the one for the working tree' 'bind-key W display-popup' "$bound"
/bin/rm -rf "$fake_bin"; /bin/rm -f "$tmux_log"
unset bound ybound yank_binding tmux_log fake_bin

section 'read_state: whatever the server pushed since the last turn'
state_file=$(mktemp)
state_asked=0
tmux() { state_asked=$((state_asked + 1)); printf 'asked'; return "$state_rc"; }
state_rc=0
# With no subscription it asks, every turn.
sub_out=-1; tick=''; read_state '%7' && state_ok=0 || state_ok=1
assert_eq 'without a subscription the state is asked for' asked "$tick"
assert_eq 'and the turn goes on' 0 "$state_ok"
state_rc=1; read_state '%7' && state_ok=0 || state_ok=1
assert_eq 'a pane that has gone stops the loop' 1 "$state_ok"
state_rc=0
# With one, whatever arrived is drained and the last state wins.
printf '%s\n' \
  '%subscription-changed rv %7 - - 0 : 1 100 90 5' \
  '%output %7 something' \
  '%subscription-changed rv %7 - - 0 : 1 100 80 5' >"$state_file"
exec {state_fd}<"$state_file"
sub_out=$state_fd; tick=''; state_asked=0
read_state '%7'
assert_eq 'the last state pushed is the one kept' '1 100 80 5' "$tick"
assert_eq 'and nothing was asked for' 0 "$state_asked"
tick='held'; read_state '%7'
assert_eq 'a turn with nothing waiting leaves the last one standing' held "$tick"
exec {state_fd}<&-
# And does not wait to find that out. Each turn used to give the client a
# fiftieth of a second to say something, and a key pressed in that time waited
# on it: up to 20ms on every key, a fold's included, for a client that had
# nothing to say. Ten turns against a client that says nothing take what ten
# turns take, not ten fiftieths of a second.
exec {state_fd}< <(sleep 2)
sub_out=$state_fd; tick='held'
state_t0=$EPOCHREALTIME
for _ in 1 2 3 4 5 6 7 8 9 10; do read_state '%7'; done
state_ms=$(((${EPOCHREALTIME/./} - ${state_t0/./}) / 1000))
assert_ok "$((state_ms < 100 ? 0 : 1))" 'a turn with nothing waiting does not wait for it' \
  'under 100ms for ten turns' "${state_ms}ms"
exec {state_fd}<&-
unset state_t0 state_ms
# tmux can write a line in more than one piece, and a turn only waits a
# fiftieth of a second for the rest. Caught in a live run: the turn read the %
# of a push and gave up, the next read the rest as a line of its own, and
# without its % it matched nothing -- so the push was dropped. tmux pushes a
# value only when it changes, so it never came again, and the list went on
# drawing for a border that had moved a minute before.
exec {state_fd}< <(printf '%%'; sleep 0.3; printf '%s\n' 'subscription-changed rv %7 - - 0 : 1 100 82 5')
sub_out=$state_fd; tick=''; state_asked=0

read_state '%7'
sleep 0.5
read_state '%7'

assert_eq 'a push that arrives in pieces is still a push' '1 100 82 5' "$tick"
exec {state_fd}<&-
# A control client that exits falls back to asking rather than going blind.
printf '%s\n' '%exit' >"$state_file"
exec {state_fd}<"$state_file"
sub_out=$state_fd; tick=''; state_asked=0
read_state '%7'
assert_eq 'the subscription is given up' -1 "$sub_out"
assert_eq 'and the state asked for instead' asked "$tick"
exec {state_fd}<&-
/bin/rm -f "$state_file"
unset -f tmux; unset state_file state_asked state_rc state_ok state_fd

section 'ask_state: the reply, not the push a second later'
ask_w=$(mktemp)
ask_r=$(mktemp)
# state_format is the script's own, and the sections after this one read it.
ask_save_format=$state_format
# What the control client says back: the command echo, a push that happened to
# land while the reply was in flight, then the reply itself.
{
  printf '%%begin 1 1 1\n'
  printf '%%subscription-changed rv %%1 0 0 0 : STALE-PUSH\n'
  printf 'THE-REPLY\n'
  printf '%%end 1 1 1\n'
} >"$ask_r"
exec {ask_rfd}<"$ask_r"
exec {ask_wfd}>"$ask_w"
sub_out=$ask_rfd
sub_in=$ask_wfd
state_format='#{scroll_position}'
tick=''
# Called directly, never through $(...): it sets the caller's tick, and a
# subshell would both set a copy and read the descriptor to the end.
ask_state %1
ask_status=$?
assert_eq 'it answers true' 0 "$ask_status"
assert_eq 'the reply is what the tick becomes' 'THE-REPLY' "$tick"
exec {ask_wfd}>&-
assert_match 'and the ask went down the control client' \
  'display-message -p -t %1' "$(cat "$ask_w")"
exec {ask_rfd}<&-
# A client that has gone takes the fast path with it rather than hanging.
printf '%%exit\n' >"$ask_r"
exec {ask_rfd}<"$ask_r"
sub_out=$ask_rfd
exec {ask_wfd}>"$ask_w"
sub_in=$ask_wfd
ask_state %1
ask_status=$?
assert_eq 'a client that has exited answers false' 1 "$ask_status"
assert_eq 'and says so, so the caller stops asking' -1 "$sub_out"
exec {ask_rfd}<&-
exec {ask_wfd}>&-
# The ask reads the descriptor the turns read, so it can be handed the rest of
# a push a turn read only the start of. It has to take that start with it, or
# the next turn puts it in front of a push of its own and loses that one too.
{
  printf '%s\n' 'subscription-changed rv %1 0 0 0 : HALF-PUSH'
  printf '%%begin 1 1 1\n'
  printf 'THE-REPLY\n'
  printf '%%end 1 1 1\n'
  printf '%s\n' '%subscription-changed rv %1 0 0 0 : NEXT-PUSH'
} >"$ask_r"
exec {ask_rfd}<"$ask_r"
exec {ask_wfd}>"$ask_w"
sub_out=$ask_rfd; sub_in=$ask_wfd; sub_partial='%'; tick=''

ask_state %1
ask_tick=$tick
read_state %1

assert_eq 'an ask takes up the half a push a turn left' 'THE-REPLY NEXT-PUSH' "$ask_tick $tick"
exec {ask_rfd}<&-
exec {ask_wfd}>&-
# What an ask sees first on a client that has only just subscribed: the empty
# answer to the subscription itself, and notices tmux sends every client
# whenever something happens -- neither of them this ask's reply. Taking the
# first answer as its own and a notice as the state, the sidebar was handed
# '%session-changed $0 0', worked out a list one column wide from it, and drew
# the header at that until a push put it right.
{
  printf '%%begin 1 1 1\n'
  printf '%%end 1 1 1\n'
  # The $0 is tmux's session id, written as tmux writes it.
  # shellcheck disable=SC2016
  printf '%s\n' '%session-changed $0 0'
  printf '%s\n' '%layout-change @1 1714,285x78,0,0{80x78,0,0,1,204x78,81,0,2}'
  printf '%%begin 1 2 1\n'
  printf 'THE-REPLY\n'
  printf '%%end 1 2 1\n'
} >"$ask_r"
exec {ask_rfd}<"$ask_r"
exec {ask_wfd}>"$ask_w"
sub_out=$ask_rfd; sub_in=$ask_wfd; sub_partial=''; tick=''

ask_state %1

assert_eq 'the reply is the answer to the ask, not to the subscription or a notice' \
  'THE-REPLY' "$tick"
exec {ask_rfd}<&-
exec {ask_wfd}>&-
sub_partial=''
unset ask_tick
/bin/rm -f "$ask_r" "$ask_w"
state_format=$ask_save_format
sub_out=-1
sub_in=-1
tick=''
unset ask_r ask_w ask_save_format ask_status

section 'ctl_ask: any one-line answer, down the control client'
# What ask_state does for the tick, for any format: the fold asks for the diff
# pane's state and then for its title this way, at 0.4ms an ask against 5ms for
# a tmux of its own -- and far worse on a machine whose endpoint agent inspects
# every exec. The empty answer ahead of it is what a command with no output
# leaves behind, which the swap at the end of a fold is.
ctl_w=$(mktemp)
ctl_r=$(mktemp)
{
  printf '%%begin 1 1 1\n'
  printf '%%end 1 1 1\n'
  printf '%%begin 1 2 1\n'
  printf 'host\x1f42\n'
  printf '%%end 1 2 1\n'
} >"$ctl_r"
exec {ctl_rfd}<"$ctl_r"
exec {ctl_wfd}>"$ctl_w"
sub_out=$ctl_rfd; sub_in=$ctl_wfd; sub_partial=''
ctl_ask %7 '#{pane_title}'
ctl_status=$?
exec {ctl_wfd}>&-
exec {ctl_rfd}<&-
assert_eq 'the answer, past the empty one a command with no output leaves' \
  "0 host${US}42" "$ctl_status $REPLY"
assert_eq 'asked as a display-message of that pane' \
  'display-message -p -t %7 "#{pane_title}"' "$(/bin/cat "$ctl_w")"
sub_out=-1
sub_in=-1
ctl_ask %7 '#{pane_title}'
ctl_status=$?
assert_eq 'and with no control client up it answers false, for the caller to ask itself' \
  1 "$ctl_status"
/bin/rm -f "$ctl_r" "$ctl_w"
unset ctl_r ctl_w ctl_rfd ctl_wfd ctl_status

section 'sidebar_exit: the control client goes first, and nothing waits on the pane'
# The sidebar was caught once gone quiet for good in the middle of its exit: the
# trap wrote the cursor back to its own pane before anything else, the pane was
# not being read, and the write held the process -- with the control client it
# was about to kill still attached to the session behind it. Here the pane is a
# pipe whose reader never reads, filled before the exit starts.
sleep 30 &
sub_pid=$!
exit_sub=$sub_pid
exec {exit_fd}> >(sleep 3)
head -c 200000 /dev/zero 1>&"$exit_fd" 2>/dev/null &
exit_filler=$!
sleep 0.3
# In a subshell of its own, so an exit that does block is a failed assertion
# rather than the test run itself stuck on the pipe.

( sidebar_exit 1>&"$exit_fd" 2>/dev/null ) &
exit_job=$!
for _ in $(seq 1 10); do
  kill -0 "$exit_job" 2>/dev/null || break
  sleep 0.05
done

exit_stuck=0
kill -0 "$exit_job" 2>/dev/null && { exit_stuck=1; kill "$exit_job" 2>/dev/null; }
exit_alive=0; kill -0 "$exit_sub" 2>/dev/null && exit_alive=1
assert_eq 'the exit does not wait on a pane nobody reads' 0 "$exit_stuck"
assert_eq 'and the control client is gone with it' 0 "$exit_alive"
kill "$exit_filler" "$exit_sub" 2>/dev/null
exec {exit_fd}>&-
sub_pid=''
unset exit_sub exit_fd exit_filler exit_job exit_stuck exit_alive

# The render the folds are drawn from is the size of the whole diff, and nothing
# else would ever remove it.
fold_cache=$(mktemp)
( sidebar_exit ) 2>/dev/null
fold_left=0
[[ -e $fold_cache ]] && fold_left=1
assert_eq 'the render the folds are drawn from goes with the review' 0 "$fold_left"
/bin/rm -f "$fold_cache"
unset fold_cache fold_left

section 'start_subscription: a control client, subscribed to the one format'
sub_dir=$(mktemp -d)
cat >"$sub_dir/tmux" <<'FAKE'
#!/usr/bin/env bash
# Echoes what it is told to subscribe to, which is what the test reads back.
printf 'control-mode %s\n' "$*"
while IFS= read -r line; do printf 'sent:%s\n' "$line"; done
FAKE
chmod +x "$sub_dir/tmux"
sub_out=-1; sub_in=-1; sub_pid=''
PATH="$sub_dir:$PATH" start_subscription '%7' 'main' && sub_ok=0 || sub_ok=1
assert_eq 'the client starts' 0 "$sub_ok"
assert_ok "$([[ $sub_out -ge 0 ]] && echo 0 || echo 1)" 'and there is a pipe to read it on'
assert_ok "$([[ -n $sub_pid ]] && echo 0 || echo 1)" 'and a process behind it'
IFS= read -r -t 2 -u "$sub_out" sub_line || sub_line=''
assert_match 'it attaches in control mode, taking no part in sizing' \
  'control-mode -C attach-session -f no-output -t main' "$sub_line"
IFS= read -r -t 2 -u "$sub_out" sub_line || sub_line=''
assert_match 'and subscribes the pane to the state format' \
  'sent:refresh-client -B "rv:%7:' "$sub_line"
assert_match 'which carries the fields the loop reads' 'scroll_position' "$sub_line"
kill "$sub_pid" 2>/dev/null
exec {sub_out}<&- 2>/dev/null || true
/bin/rm -rf "$sub_dir"
sub_out=-1; sub_in=-1
unset sub_line sub_ok sub_dir

section 'pick_keys: moving the picker, and leaving it'
pick_done=''
apply_pick() { pick_done="apply_pick $*"; }
apply_pick_session() { pick_done="apply_pick_session $*"; }
pick_kind=(range wip staged stash)
pick_label=(a b c d); pick_extra=('' '' '' ''); pick_payload=('' '' '' '')
picking=1; pick_cur=1; pick_mode=range; shown=0; needs_clear=0
pick_keys '%7' '@9' <<<'j'
assert_eq 'j steps down' 2 "$pick_cur"
pick_keys '%7' '@9' <<<'k'
assert_eq 'k steps back up' 1 "$pick_cur"
pick_keys '%7' '@9' < <(printf 'G')
assert_eq 'last goes to the end' 3 "$pick_cur"
# gg, the way vi spells it: a lone g is not a movement.
pick_keys '%7' '@9' < <(printf 'gg')
assert_eq 'first goes back to the start' 0 "$pick_cur"
pick_done=''; pick_keys '%7' '@9' < <(printf '\r')
assert_eq 'enter takes the item under the cursor' 'apply_pick %7 @9 0' "$pick_done"
assert_eq 'and the picker is done' 0 "$picking"
assert_eq 'the list is redrawn from scratch behind it' -2 "$shown"
assert_eq 'over a cleared pane' 1 "$needs_clear"
picking=1; pick_mode=session; pick_done=''
pick_keys '%7' '@9' < <(printf '\r')
assert_eq 'in session mode enter chooses an agent instead' \
  'apply_pick_session @9 0' "$pick_done"
picking=1; pick_done=''; pick_keys '%7' '@9' <<<'q'
assert_eq 'q dismisses it' 0 "$picking"
assert_eq 'without choosing anything' '' "$pick_done"
picking=1; pick_keys '%7' '@9' < <(printf '\e')
assert_eq 'and so does escape' 0 "$picking"
picking=1; pick_keys '%7' '@9' </dev/null
assert_eq 'a turn with no key leaves it up' 1 "$picking"
restore_review; unset pick_done

section 'add_comment: the anchor, an editor, and what comes back'
comment_msgs=''
anchor_rows() { ANCHOR_FIRST_ROW=10; ANCHOR_LAST_ROW=12; ANCHOR_HIST=100; return "$anchor_rc"; }
anchor_text() {
  ANCHOR_COMMIT=$a_commit; ANCHOR_FILE=$a_file
  ANCHOR_FIRST=$a_first; ANCHOR_LAST=$a_last; ANCHOR_BLOCK=$a_block
  return "$text_rc"
}
# The popup is where the editor would run; here it writes the file instead.
tmux() {
  case $1 in
    display-popup)
      # The popup's command is the last argument -- "$EDITOR <file>" -- so the
      # file is what follows the space in it. Taken positionally rather than
      # out of "$*", which joins on IFS, and IFS is not always a space here.
      popup_cmd=${*: -1}
      [[ -n $editor_writes ]] && printf '%s\n' "$editor_writes" >>"${popup_cmd##* }"
      ;;
    display-message) comment_msgs+="[${*:2}]" ;;
  esac
  return 0
}
add_store=$(mktemp); /bin/rm -f "$add_store"
anchor_rc=0; text_rc=0
a_commit=40c21a5; a_file=tmux-review/scripts/review.sh; a_first=512; a_last=514
a_block=$'if ((on_range)); then\n  select_index 0'
agent_label_cur='󰚩  main:2  web'
editor_writes='the guard runs after this'
comment_msgs=''; add_comment '%7' "$add_store"
assert_eq 'the comment is queued' 1 "$(comment_count "$add_store")"
assert_match 'and the count and the agent are reported' \
  '1 queued for 󰚩  main:2  web' "$comment_msgs"
queued=$(comment_prompt "$add_store" 'base..HEAD' repo)
assert_match 'the commit is carried' 'commit 40c21a5' "$queued"
assert_match 'with the file and the lines the selection covered' \
  'review\.sh:512-514' "$queued"
assert_match 'the block is quoted' '> if \(\(on_range\)\); then' "$queued"
assert_match 'every line of it' '> {3}select_index 0' "$queued"
assert_match 'and the body is what was written' 'the guard runs after this' "$queued"
/bin/rm -f "$add_store"
# Saving nothing cancels, which is how :q! gets out.
editor_writes=''; comment_msgs=''; add_comment '%7' "$add_store"
assert_eq 'an empty file queues nothing' 0 "$(comment_count "$add_store")"
assert_match 'and says the comment was discarded' 'comment discarded' "$comment_msgs"
# The template alone is not a comment either.
editor_writes='# still just the header'; comment_msgs=''
add_comment '%7' "$add_store"
assert_eq 'a file of nothing but comment lines queues nothing' 0 \
  "$(comment_count "$add_store")"
text_rc=1; comment_msgs=''; add_comment '%7' "$add_store"
assert_match 'a selection covering nothing that can be cited says so' \
  'nothing there to comment on' "$comment_msgs"
anchor_rc=1; comment_msgs=''; add_comment '%7' "$add_store"
assert_eq 'and a pane that reports no rows is left alone' '' "$comment_msgs"
/bin/rm -f "$add_store"
unset -f tmux anchor_rows anchor_text; restore_review
unset comment_msgs add_store anchor_rc text_rc queued editor_writes
unset a_commit a_file a_first a_last a_block

section 'edit_comment: the same editor, under the references as recorded'
# The end to end section presses e and d against a real review, but only down
# the one path a reader takes when nothing goes wrong. These are the rest: the
# empty save that must not be read as a delete, the edit that changes nothing,
# and the indexes that are not there.
ed_msgs=''
ed_mode=replace
ed_writes='the edited body'
# Stands in for the popup: replace writes the file, append adds to what the
# template seeded it with, and none leaves it empty -- which is what saving
# nothing looks like from out here.
tmux() {
  local f
  case $1 in
    display-popup)
      f=${*: -1}; f=${f##* }
      case $ed_mode in
        replace) printf '%s\n' "$ed_writes" >|"$f" ;;
        append) printf '%s\n' "$ed_writes" >>"$f" ;;
        none) : >|"$f" ;;
      esac
      ;;
    display-message) ed_msgs+="[${*:2}]" ;;
  esac
  return 0
}
ed_store=$(mktemp); /bin/rm -f "$ed_store"
ed_seed() {
  /bin/rm -f "$ed_store"
  comment_add "$ed_store" abc1234 lib/a.ex 10 12 'defp a do' 'the first'
  comment_add "$ed_store" def5678 lib/b.ex 3 3 'defp b do' 'the second'
  comment_load "$ed_store"
}

ed_seed
ed_mode=replace ed_writes='the edited body' ed_msgs=''
edit_comment "$ed_store" 1
assert_eq 'the body is what was written' 'the edited body' "$(comment_load "$ed_store"; printf '%s' "${cm_body[1]}")"
assert_match 'and it says so' 'comment edited' "$ed_msgs"
# The point of the whole function: the references are the ones on record, not
# whatever the diff is showing now. anchor_rows and anchor_text are never
# called here -- if they were, a rebase would move the comment silently.
assert_eq 'the references are the ones that were recorded' 'def5678|lib/b.ex|3|3|defp b do' \
  "$(comment_load "$ed_store"; printf '%s|%s|%s|%s|%s' "${cm_commit[1]}" "${cm_file[1]}" "${cm_first[1]}" "${cm_last[1]}" "${cm_block[1]}")"
assert_eq 'and the comment beside it is untouched' 'the first' \
  "$(comment_load "$ed_store"; printf '%s' "${cm_body[0]}")"
assert_eq 'with the queue no longer than it was' 2 "$(comment_count "$ed_store")"

# Saving nothing keeps what was there. It cannot mean discard: d is for that,
# and an editor left by habit would otherwise throw the comment away.
ed_seed; ed_mode=none; ed_msgs=''
edit_comment "$ed_store" 0
assert_eq 'saving nothing keeps the comment' 'the first' \
  "$(comment_load "$ed_store"; printf '%s' "${cm_body[0]}")"
assert_match 'and says it is unchanged' 'unchanged' "$ed_msgs"
assert_eq 'the queue is still whole' 2 "$(comment_count "$ed_store")"

# Saving the same words is not a change either, and must not rewrite the file.
ed_seed; ed_mode=replace; ed_writes='the first'; ed_msgs=''
edit_comment "$ed_store" 0
assert_match 'writing the same words again is unchanged too' 'unchanged' "$ed_msgs"
assert_eq 'and nothing was edited' 0 "$(printf '%s' "$ed_msgs" | grep -c 'comment edited')"

# The separators are the one thing a body must not carry: it is the last field,
# so one of those in it would split the queue at that point.
ed_seed; ed_mode=replace; ed_writes=$'a body \x1f with \x1e separators'; ed_msgs=''
edit_comment "$ed_store" 0
assert_eq 'the record separators are stripped out of a body' 'a body  with  separators' \
  "$(comment_load "$ed_store"; printf '%s' "${cm_body[0]}")"
assert_eq 'so the queue still reads as two records' 2 "$(comment_count "$ed_store")"

ed_seed; ed_msgs=''
edit_comment "$ed_store" 9
assert_eq 'an index past the end edits nothing' 1 "$?"
edit_comment "$ed_store" -1
assert_eq 'and neither does one before the start' 1 "$?"
assert_eq 'with nothing said about either' '' "$ed_msgs"

section 'delete_comment: after asking, and only after'
ed_seed; ed_msgs=''
delete_comment "$ed_store" 0 <<<'n'
assert_eq 'n keeps it' 2 "$(comment_count "$ed_store")"
assert_match 'and says so' 'kept' "$ed_msgs"
ed_msgs=''
delete_comment "$ed_store" 0 </dev/null
assert_eq 'and so does walking away without answering' 2 "$(comment_count "$ed_store")"
assert_match 'which is also kept' 'kept' "$ed_msgs"

ed_msgs=''
delete_comment "$ed_store" 0 <<<'y'
assert_eq 'y takes it out' 1 "$(comment_count "$ed_store")"
assert_eq 'and the one that is left is the other' 'the second' \
  "$(comment_load "$ed_store"; printf '%s' "${cm_body[0]}")"
assert_eq 'with its references still whole' 'def5678|lib/b.ex|3|3' \
  "$(comment_load "$ed_store"; printf '%s|%s|%s|%s' "${cm_commit[0]}" "${cm_file[0]}" "${cm_first[0]}" "${cm_last[0]}")"
assert_match 'and it says what happened' 'comment deleted' "$ed_msgs"

# The last one out leaves no file, which is what the pane reads to know it has
# nothing to show.
ed_msgs=''
delete_comment "$ed_store" 0 <<<'Y'
assert_eq 'Y answers the same as y' 0 "$(comment_count "$ed_store")"
assert_eq 'and an emptied queue leaves no file behind' 0 \
  "$([[ -e $ed_store ]] && echo 1 || echo 0)"

# Which one is going, in the reader's own words, so d on the wrong row of a
# stacked pair is visibly the wrong one.
ed_seed; ed_msgs=''
cm_body[0]=$'a first line that is quite a lot longer than forty characters\nand a second'
comment_write "$ed_store"; comment_load "$ed_store"
delete_comment "$ed_store" 0 <<<'n'
assert_match 'the question quotes the comment it is about' 'a first line that is quite a lot longer' "$ed_msgs"
assert_match 'cut to one line and to a length that fits' '…' "$ed_msgs"
assert_eq 'and never the second line of it' 0 "$(printf '%s' "$ed_msgs" | grep -c 'and a second')"

ed_msgs=''
delete_comment "$ed_store" 9 <<<'y'
assert_eq 'an index past the end deletes nothing' 1 "$?"
assert_eq 'and asks nothing either' '' "$ed_msgs"

/bin/rm -f "$ed_store"
unset -f tmux ed_seed; restore_review
unset ed_msgs ed_store ed_mode ed_writes

section 'sidebar: the loop, driven by a scripted server'
# The loop only ever leaves on q or on the pane going away, so the harness
# scripts a finite run of ticks and lets read_state fail after the last -- which
# is the same signal it gets when the diff pane is closed.
#
# The tick index lives in a file: read_state reads the state through $(...), so
# a counter in a variable would be incremented in a subshell and lost.
sb_log=$(mktemp); sb_out=$(mktemp); sb_ix=$(mktemp); sb_ticks=$(mktemp)
# Where the header pane's tty would be. A plain file takes the same writes,
# which is what lets the pane the loop never reads back be asserted on.
sb_hdr=$(mktemp)
# in_mode, basis, scroll, cy, diff width, window width, height, zoomed,
# diff focused, searching, loaded, live size.
sb_tick() { printf '%s\x1f' "$@" | sed 's/\x1f$//'; }
sb_normal=$(sb_tick 1 100 100 0 142 220 40 0 1 0 1 100)
sb_loading=$(sb_tick 1 100 100 0 142 220 40 1 1 0 0 100)

sidebar_run() {
  local keys=$1; shift
  printf '%s\n' "$@" >"$sb_ticks"
  printf '0' >"$sb_ix"
  : >"$sb_log"
  (
    tmux() {
      local n
      case $* in
        # The one query made before the loop: window, agent, session.
        # Five fields, matching the format: window, agent pane, agent label,
        # session, guessed. The agent pane is empty on purpose -- a review that
        # already has one has nothing to guess, and this is the run that checks
        # the guess is made.
        *window_id*) printf '@9\x1f\x1f\x1fmain\x1f0' ; return 0 ;;
        # The state the loop turns on: one scripted tick per turn, and a refusal
        # once they run out, which is the signal a closed diff pane gives.
        #
        # Matched on pane_in_mode, and placed ahead of the bare copy_cursor_y
        # arm below, because the state format carries #{copy_cursor_y} among its
        # twelve fields: an arm matching that alone answers the state query too,
        # and answering it with a single 0 leaves the tick index where it was.
        # The ticks then never run out, and running out is the only thing that
        # ends the loop -- it spun 37k turns before the suite was killed.
        *pane_in_mode*)
          n=$(cat "$sb_ix"); printf '%s' $((n + 1)) >"$sb_ix"
          sed -n "$((n + 1))p" "$sb_ticks" | grep -q . || return 1
          sed -n "$((n + 1))p" "$sb_ticks"
          return 0 ;;
        # The one-field query the copy-mode re-entry path makes on its own.
        *copy_cursor_y*) printf '0'; return 0 ;;
        'capture-pane'*)
          # A commit header every twenty rows, which is what the row map reads.
          printf 'commit %s\n' "${shas[@]}"
          return 0 ;;
      esac
      printf 'TMUX %s\n' "$*" >>"$sb_log"
      return 0
    }
    git() {
      case $* in
        *'--shortstat'*) printf ' 3 files changed, 9 insertions(+)\n' ;;
        *'config'*) printf 'delta.file-modified-label \n' ;;
        *'--reverse --format'*) printf 'c0\x1ffirst\x1f1 hour ago\x1fA\n'
                                printf 'c1\x1fsecond\x1f1 hour ago\x1fB\n' ;;
      esac
      return 0
    }
    render() { printf 'RENDER %s\n' "$*" >>"$sb_log"; }
    render_loading() { printf 'LOADING %s\n' "$*" >>"$sb_log"; }
    render_picker() { printf 'PICKER %s\n' "$*" >>"$sb_log"; }
    add_comment() { printf 'ADD %s\n' "$*" >>"$sb_log"; }
    send_comments() { printf 'SEND %s\n' "$*" >>"$sb_log"; }
    quit() { printf 'QUIT %s\n' "$*" >>"$sb_log"; }
    start_subscription() { return 1; }
    map_rows() {
      printf 'MAP %s\n' "$*" >>"$sb_log"
      row_of=([c0]=5 [c1]=40); file_rows=(); file_names=(); mapped=1
    }
    steer() { printf 'STEER %s\n' "$*" >>"$sb_log"; }
    preselect_agent() { printf 'PRESELECT %s\n' "$*" >>"$sb_log"; }
    load_pick_items() { pick_kind=(range); pick_label=(x); pick_extra=(''); pick_payload=(''); }
    load_pick_sessions() { pick_kind=(session); pick_label=(y); pick_extra=(''); pick_payload=("%5${US}y"); }
    pick_keys() { printf 'PICKKEYS %s\n' "$*" >>"$sb_log"; picking=0; }
    fold_key() { printf 'FOLD %s\n' "$*" >>"$sb_log"; mapped=0; }
    sidebar '%7' '%6' "$sb_hdr" 'base..HEAD' 220 40
  ) <<<"$keys" >"$sb_out" 2>&1
  sb_seen=$(cat "$sb_log")
  sb_header=$(strip <"$sb_hdr")
}

sidebar_run '' "$sb_normal" "$sb_normal"
assert_match 'the first frame is the placeholder, drawn before tmux is touched' \
  'LOADING 220 40 0' "$sb_seen"
assert_match 'and once the diff has landed, the list' 'RENDER 0 77 35 diff' "$sb_seen"
assert_match 'the list is sized from the window and the diff pane' \
  'RENDER 0 77 ' "$sb_seen"
assert_match 'an agent is guessed once the reader has the list' \
  'PRESELECT @9 main' "$sb_seen"
# The header is painted through a tty this loop is only handed, so what lands
# there is the whole of what can be checked -- and it is painted before the
# first tmux call, off the geometry it was given.
assert_match 'the header pane is painted with the range' 'base\.\.HEAD' "$sb_header"
assert_match 'and with what the range comes to' '\+9.*2 commits' "$sb_header"

# Still loading: the list waits behind the placeholder rather than being drawn
# at the zoomed width and reflowing when the zoom comes off.
sidebar_run '' "$sb_loading" "$sb_loading"
assert_eq 'a zoomed pane is never drawn a list' 0 "$(grep -c 'RENDER' <<<"$sb_seen")"
assert_ok "$([[ $(grep -c 'LOADING' <<<"$sb_seen") -ge 1 ]] && echo 0 || echo 1)" \
  'it holds the placeholder instead'
assert_eq 'and nothing is guessed before there is a list to guess for' 0 \
  "$(grep -c 'PRESELECT' <<<"$sb_seen")"

sidebar_run 'q' "$sb_normal" "$sb_normal" "$sb_normal"
assert_match 'q closes the window' 'QUIT' "$sb_seen"

sidebar_run 'c' "$sb_normal" "$sb_normal" "$sb_normal"
assert_match 'c opens the comment editor on the diff pane' 'ADD %7' "$sb_seen"
sidebar_run 's' "$sb_normal" "$sb_normal" "$sb_normal"
assert_match 's hands the queue over, with the window and the range' \
  'SEND @9 .* base\.\.HEAD' "$sb_seen"
sidebar_run 'j' "$sb_normal" "$sb_normal" "$sb_normal"
assert_match 'a movement key is steered against the diff' 'STEER %7 j' "$sb_seen"
sidebar_run '=' "$sb_normal" "$sb_normal" "$sb_normal"
assert_match '= is a fold, with the focus and the selected commit' 'FOLD %7 = diff 0' "$sb_seen"
# The herestring ends the keys with a newline, which arrives as enter and is
# steered like any other key; what matters is that = itself is not.
assert_eq 'and is not steered' 0 "$(grep -c 'STEER %7 =' <<<"$sb_seen")"
# A fold builds the map itself when it can trust what it wrote. One that
# cannot leaves it to the next turn, which captures the pane for it.
assert_match 'and a map the fold left unbuilt is captured on the turn after' $'MAP %7 \n' "$sb_seen"
sidebar_run '<' "$sb_normal" "$sb_normal" "$sb_normal"
assert_match '< is one too' 'FOLD %7 < diff 0' "$sb_seen"
sidebar_run '>' "$sb_normal" "$sb_normal" "$sb_normal"
assert_match 'and so is >' 'FOLD %7 > diff 0' "$sb_seen"

# a reaches the agent picker without having to walk the selection to its row.
sidebar_run 'a' "$sb_normal" "$sb_normal" "$sb_normal"
assert_match 'a opens the picker' 'PICKER 77 35 0' "$sb_seen"
assert_match 'and hands it the keys' 'PICKKEYS %7 @9' "$sb_seen"

# Focus moving off the diff parks its cursor at the top of the view, so a jump
# from the list lands its file at the top rather than wherever it was left.
sb_unfocus=$(sb_tick 1 100 100 7 142 220 40 0 0 0 1 100)
sidebar_run '' "$sb_normal" "$sb_unfocus" "$sb_unfocus"
assert_match 'the diff cursor is parked when the list takes the focus' \
  'TMUX send-keys -X -t %7 top-line' "$sb_seen"
assert_match 'and the list legend is the one shown' 'RENDER .* list ' "$sb_seen"

# Every tmux-yank binding ends in -and-cancel, and a diff out of copy-mode is
# inert -- so the mode is put back rather than the review being over.
sb_cancelled=$(sb_tick 0 100 100 0 142 220 40 0 1 0 1 100)
sidebar_run '' "$sb_normal" "$sb_cancelled" "$sb_normal"
assert_match 'copy-mode is re-entered after a yank cancels it' \
  'copy-mode -t %7' "$sb_seen"
assert_match 'on the grid as it now stands' '@review_hist_base 100' "$sb_seen"
assert_match 'and the view is put back where the reader was' \
  'goto-line 100' "$sb_seen"

# A range with no commits is not a review.
sidebar_empty() {
  (
    git() { return 0; }
    tmux() { return 0; }
    sidebar '%7' '%6' "$sb_hdr" 'base..HEAD' 220 40
  ) </dev/null 2>&1
}
assert_match 'a range with nothing in it says so and waits' \
  'nothing to review' "$(sidebar_empty | strip)"

/bin/rm -f "$sb_log" "$sb_out" "$sb_ix" "$sb_ticks" "$sb_hdr"
unset -f sidebar_run sidebar_empty sb_tick
unset sb_log sb_out sb_ix sb_ticks sb_hdr sb_seen sb_normal sb_loading sb_unfocus sb_cancelled

section 'git-review: the range it resolves'
tmp=$(mktemp -d)
trap 'rm -rf "$tmp" "$tmp_counts"' EXIT
(
  cd "$tmp" || exit 1
  git init -q -b main .
  git config user.email t@example.com
  git config user.name Test
  # The user's own config signs every commit; this identity has no key.
  git config commit.gpgsign false
  for n in 1 2 3 4; do
    echo "$n" > "file$n"
    git add "file$n"
    git commit -qm "commit $n"
  done
) >/dev/null 2>&1
assert_eq 'the throwaway repository has four commits' 4 \
  "$(git -C "$tmp" rev-list --count HEAD 2>/dev/null)"

review=$plugin/bin/git-review

assert_eq 'a range argument is passed through' 'a1b2..c3d4' \
  "$(cd "$tmp" && "$review" --range a1b2..c3d4)"
assert_eq 'a count becomes a relative range' 'HEAD~3..HEAD' \
  "$(cd "$tmp" && "$review" --range 3)"
assert_eq 'a ref becomes a range to HEAD' 'main..HEAD' \
  "$(cd "$tmp" && "$review" --range main)"

# No remote at all, and HEAD on main: nothing on it was ever pushed, so every
# commit is outstanding and all of them are the review, the root included.
assert_eq 'a trunk nobody has pushed is reviewed whole' 'HEAD' \
  "$(cd "$tmp" && "$review" --range)"

# HEAD~n stops existing at the root. Four commits are HEAD~3..HEAD and the root.
assert_eq 'a count that reaches the root is every commit' 'HEAD' \
  "$(cd "$tmp" && "$review" --range 4)"
assert_eq 'and so is one that goes past it' 'HEAD' \
  "$(cd "$tmp" && "$review" --range 40)"
assert_eq 'HEAD on its own is every commit, not the none since it' 'HEAD' \
  "$(cd "$tmp" && "$review" --range HEAD)"
(cd "$tmp" && "$review" --range 0) >/dev/null 2>&1
assert_eq 'the last 0 commits are refused' 1 "$?"
assert_eq 'the whole history is every commit git log shows' 4 \
  "$(cd "$tmp" && "$review" --no-header | grep -c '^commit ')"

# With origin/HEAD recorded, the base is the remote branch -- and up to date
# with it, what was pushed is not outstanding, so the tip is the review.
(
  cd "$tmp" || exit 1
  git update-ref refs/remotes/origin/main HEAD
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
) >/dev/null 2>&1
assert_eq 'level with a pushed base falls back to the tip' 'HEAD~1..HEAD' \
  "$(cd "$tmp" && "$review" --range)"
(cd "$tmp" && git update-ref refs/remotes/origin/main HEAD~2) >/dev/null 2>&1
assert_eq 'origin/HEAD is the base' 'origin/main..HEAD' \
  "$(cd "$tmp" && "$review" --range)"

# On a branch, the same resolution covers the commits the base lacks.
(cd "$tmp" && git checkout -q -b feature && echo x > f && git add f && git commit -qm f) >/dev/null 2>&1
assert_eq 'a branch resolves against the same base' 'origin/main..HEAD' \
  "$(cd "$tmp" && "$review" --range)"

# The old alias reviewed `--not HEAD..master`, which is empty on the base
# branch and fatal wherever the default branch is not called master.
(cd "$tmp" && git checkout -q main) >/dev/null 2>&1
assert_eq 'the base branch still has a range' 'origin/main..HEAD' \
  "$(cd "$tmp" && "$review" --range)"

# A branch off a long-lived branch off trunk. Reviewing it against trunk buries
# the few commits it owns under everything the long-lived branch carries -- 872
# commits under 5, in the repository this was written for. The base is whichever
# published ancestor sits closest behind HEAD, so the reader sees their own work.
stack=$(mktemp -d)
trap 'rm -rf "$tmp" "$tmp_counts" "$stack"' EXIT
(
  cd "$stack" || exit 1
  git init -q -b main .
  git config user.email t@example.com
  git config user.name Test
  # The user's own config signs every commit; this identity has no key.
  git config commit.gpgsign false
  echo trunk > trunk && git add trunk && git commit -qm trunk
  git update-ref refs/remotes/origin/main HEAD
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  git checkout -q -b long-lived
  for n in 1 2 3; do echo "$n" > "long$n"; git add "long$n"; git commit -qm "long $n"; done
  # Published: the rule only trusts a local branch that has a remote twin.
  git update-ref refs/remotes/origin/long-lived HEAD
  git checkout -q -b feature
  for n in 1 2; do echo "$n" > "feat$n"; git add "feat$n"; git commit -qm "feat $n"; done
) >/dev/null 2>&1

assert_eq 'the stacked branch owns two commits' 2 \
  "$(git -C "$stack" rev-list --count long-lived..HEAD 2>/dev/null)"
assert_eq 'the closest published ancestor is the base' 'long-lived..HEAD' \
  "$(cd "$stack" && "$review" --range)"

# Trunk is still the base where nothing closer exists: the long-lived branch
# itself resolves the way it always did.
assert_eq 'a branch off trunk is unchanged' 'origin/main..HEAD' \
  "$(cd "$stack" && git checkout -q long-lived && "$review" --range)"
(cd "$stack" && git checkout -q feature) >/dev/null 2>&1

# A ref sitting on HEAD itself leaves nothing to review, so it is not a base.
(cd "$stack" && git branch -f twin HEAD && git update-ref refs/remotes/origin/twin HEAD) >/dev/null 2>&1
assert_eq 'a ref level with HEAD is not the base' 'long-lived..HEAD' \
  "$(cd "$stack" && "$review" --range)"

# The branch's own remote twin trails it whenever there is anything unpushed.
# Reviewing against that shows what has not been pushed, not what the branch is.
(cd "$stack" && git update-ref refs/remotes/origin/feature HEAD~1) >/dev/null 2>&1
assert_eq "a branch's own remote twin is never its base" 'long-lived..HEAD' \
  "$(cd "$stack" && "$review" --range)"

# An unpublished branch is a scratch ref, not a base: no remote twin, no say.
(cd "$stack" && git branch -f wip HEAD~1) >/dev/null 2>&1
assert_eq 'an unpublished branch is not a base' 'long-lived..HEAD' \
  "$(cd "$stack" && "$review" --range)"

# Set once per branch, and the search is skipped entirely.
(cd "$stack" && git config branch.feature.reviewBase origin/main) >/dev/null 2>&1
assert_eq 'reviewBase overrides the search' 'origin/main..HEAD' \
  "$(cd "$stack" && "$review" --range)"
(cd "$stack" && git config --unset branch.feature.reviewBase) >/dev/null 2>&1

# The remote HEAD symref is a name for trunk, not a branch in its own right --
# `origin` must never be offered as a base.
assert_eq 'the remote HEAD symref is not a base' 'long-lived..HEAD' \
  "$(cd "$stack" && "$review" --range)"

# An explicit argument still wins over everything.
assert_eq 'an explicit base beats the search' 'origin/main..HEAD' \
  "$(cd "$stack" && "$review" --range origin/main)"

# A local trunk that has run ahead of its remote is an alias for trunk, not a
# base of its own. Were it allowed to compete, a day of unpushed commits on main
# would quietly change what a review of a branch cut from main shows.
(cd "$stack" && git checkout -q main && echo ahead > ahead &&
  git add ahead && git commit -qm ahead && git checkout -q long-lived) >/dev/null 2>&1
assert_eq 'local trunk ahead of its remote is still trunk' 'origin/main..HEAD' \
  "$(cd "$stack" && "$review" --range)"
(cd "$stack" && git checkout -q feature) >/dev/null 2>&1
assert_eq 'and it does not displace a nearer base' 'long-lived..HEAD' \
  "$(cd "$stack" && "$review" --range)"

# Where HEAD is a merge, two published lines are both ancestors and the nearer
# of the two is the base. Which one a history walk reaches first is git's
# business and not the question being asked, so the counting decides it.
merged=$(mktemp -d)
trap 'rm -rf "$tmp" "$tmp_counts" "$stack" "$merged"' EXIT
(
  cd "$merged" || exit 1
  git init -q -b main .
  git config user.email t@example.com
  git config user.name Test
  # The user's own config signs every commit; this identity has no key.
  git config commit.gpgsign false
  echo trunk > trunk && git add trunk && git commit -qm trunk
  git update-ref refs/remotes/origin/main HEAD
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  # far: two commits, but twenty behind HEAD once near is merged in.
  git checkout -q -b far
  for n in 1 2; do echo "$n" > "far$n"; git add "far$n"; git commit -qm "far $n"; done
  git update-ref refs/remotes/origin/far HEAD
  # near: twenty commits, but four behind HEAD.
  git checkout -q -b near main
  for n in $(seq 1 20); do echo "$n" > "near$n"; git add "near$n"; git commit -qm "near $n"; done
  git update-ref refs/remotes/origin/near HEAD
  git checkout -q -b feature far
  echo f > f && git add f && git commit -qm f
  git merge -q --no-ff near -m merge
) >/dev/null 2>&1

assert_eq 'the far line is twenty-two behind' 22 \
  "$(git -C "$merged" rev-list --count far..HEAD 2>/dev/null)"
assert_eq 'the near line is four behind' 4 \
  "$(git -C "$merged" rev-list --count near..HEAD 2>/dev/null)"
assert_eq 'under a merge the nearer line is the base' 'near..HEAD' \
  "$(cd "$merged" && "$review" --range)"

# Detached: there is no branch name to exclude and no reviewBase to read, but
# the refs sitting on HEAD are still not bases, so the answer does not move.
assert_eq 'a detached HEAD resolves the same way' 'long-lived..HEAD' \
  "$(cd "$stack" && git checkout -q --detach && "$review" --range)"
(cd "$stack" && git checkout -q feature) >/dev/null 2>&1

# Two published lines equally far behind a merge. Which one git hands back first
# is its business, so the name decides and the answer is the same twice running.
tie=$(mktemp -d)
trap 'rm -rf "$tmp" "$tmp_counts" "$stack" "$merged" "$tie"' EXIT
(
  cd "$tie" || exit 1
  git init -q -b main .
  git config user.email t@example.com
  git config user.name Test
  # The user's own config signs every commit; this identity has no key.
  git config commit.gpgsign false
  echo trunk > trunk && git add trunk && git commit -qm trunk
  git update-ref refs/remotes/origin/main HEAD
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  git checkout -q -b aaa && echo a > a && git add a && git commit -qm a
  git update-ref refs/remotes/origin/aaa HEAD
  git checkout -q -b zzz main && echo z > z && git add z && git commit -qm z
  git update-ref refs/remotes/origin/zzz HEAD
  git checkout -q -b feature aaa
  git merge -q --no-ff zzz -m merge
) >/dev/null 2>&1

assert_eq 'both lines are two behind' '2 2' \
  "$(git -C "$tie" rev-list --count aaa..HEAD 2>/dev/null) $(git -C "$tie" rev-list --count zzz..HEAD 2>/dev/null)"
assert_eq 'an equal distance is broken by name' 'aaa..HEAD' \
  "$(cd "$tie" && "$review" --range)"
assert_eq 'and it answers the same way twice' 'aaa..HEAD' \
  "$(cd "$tie" && "$review" --range)"

# No trunk under any of the names git-review knows, but a published branch the
# work was cut from. The search is the only thing left to answer with.
notrunk=$(mktemp -d)
trap 'rm -rf "$tmp" "$tmp_counts" "$stack" "$merged" "$tie" "$notrunk"' EXIT
(
  cd "$notrunk" || exit 1
  git init -q -b dev .
  git config user.email t@example.com
  git config user.name Test
  # The user's own config signs every commit; this identity has no key.
  git config commit.gpgsign false
  echo d > d && git add d && git commit -qm d
  git update-ref refs/remotes/origin/dev HEAD
  git checkout -q -b work && echo w > w && git add w && git commit -qm w
) >/dev/null 2>&1

assert_eq 'the repository has no main, master or origin/HEAD' '' \
  "$(git -C "$notrunk" for-each-ref --format='%(refname:short)' \
     refs/heads/main refs/heads/master refs/remotes/origin/main refs/remotes/origin/master 2>/dev/null)"
assert_eq 'a published base stands in for a trunk there is none of' 'dev..HEAD' \
  "$(cd "$notrunk" && "$review" --range)"

# Nothing to stand in for it either: no remote, no trunk under any name, one
# branch -- the notes repository this was written for. The branch sits on HEAD,
# so it is not a base, and there is nothing else. The work was never branched
# from anything, so all of it is the review.
unbased=$(mktemp -d)
trap 'rm -rf "$tmp" "$tmp_counts" "$stack" "$merged" "$tie" "$notrunk" "$unbased"' EXIT
(
  cd "$unbased" || exit 1
  git init -q -b docs .
  git config user.email t@example.com
  git config user.name Test
  # The user's own config signs every commit; this identity has no key.
  git config commit.gpgsign false
  for n in 1 2 3; do echo "$n" > "doc$n"; git add "doc$n"; git commit -qm "doc $n"; done
) >/dev/null 2>&1
assert_eq 'the repository has no remote and one branch' 'docs' \
  "$(git -C "$unbased" for-each-ref --format='%(refname:short)' 2>/dev/null)"
assert_eq 'with no base at all, every commit is the review' 'HEAD' \
  "$(cd "$unbased" && "$review" --range)"
assert_eq 'the root among them' 3 \
  "$(cd "$unbased" && "$review" --no-header | grep -c '^commit ')"
assert_eq 'and a count short of the root is still a range' 'HEAD~2..HEAD' \
  "$(cd "$unbased" && "$review" --range 2)"

# Detached there, the branch name is gone but nothing else has changed.
assert_eq 'detached, it is still every commit' 'HEAD' \
  "$(cd "$unbased" && git checkout -q --detach && "$review" --range)"

# And a repository with no commits has nothing to review at all.
unborn=$(mktemp -d)
trap 'rm -rf "$tmp" "$tmp_counts" "$stack" "$merged" "$tie" "$notrunk" "$unbased" "$unborn"' EXIT
git -C "$unborn" init -q -b docs . >/dev/null 2>&1
(cd "$unborn" && "$review" --range) >/dev/null 2>&1
assert_eq 'an unborn HEAD is refused' 1 "$?"

section 'git-review: the header'
with=$(cd "$tmp" && "$review" 1 2>&1 | head -1)
assert_match 'the range line is printed by default' 'HEAD~1\.\.HEAD' "$(strip <<<"$with")"
without=$(cd "$tmp" && "$review" --no-header 1 2>&1 | head -1)
assert_match '--no-header starts straight at the commit' '^commit ' "$(strip <<<"$without")"
assert_eq '--no-header composes with --range' 'HEAD~2..HEAD' \
  "$(cd "$tmp" && "$review" --no-header --range 2)"
(cd "$tmp" && "$review" --bogus) >/dev/null 2>&1
assert_eq 'an unknown flag exits 64' 64 "$?"

# The two bugs that got past every unit test here were the same shape: an
# associative array used before it was declared, which bash reads as an
# arithmetic subscript and set -u then kills the sidebar over. Nothing but
# actually opening a window catches that, so this opens one -- on its own tmux
# server, so it cannot disturb the one in use.
# Every socket a run stands up is named for that run's pid, so one glob takes
# all of them -- including the servers whose variable has since been reassigned
# to the next section's, which is how review-guard outlived a trap that named
# $gsock after $gsock had become review-gutter.
#
# Each server is told to go before its socket is taken: the socket is the only
# way to reach it, and a server whose section never got to kill it -- a run
# stopped part way still runs this -- would otherwise be left up for good.
clean_sockets() {
  local sock
  for sock in "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/"review-*-"$$"; do
    [[ -S $sock ]] || continue
    tmux -S "$sock" kill-server 2>/dev/null || :
    /bin/rm -f "$sock" 2>/dev/null || :
  done
}

section 'clean_sockets: a server goes with its socket'
# The trap that calls this runs however a run ends, and a run stopped part way
# -- interrupted, or given up on by whatever started it -- ends with servers
# still up that their own sections never got to kill. Taking only the socket
# away left each of those running with no way back to it: one was found eight
# days on, still holding a review window and four of its processes.
csock=review-cleanprobe-$$
if ! tmux -L "$csock" -f /dev/null new-session -d 'sleep 60' 2>/dev/null; then
  skip 'a server going with its socket' 'no tmux server could be started'
else
  cpid=$(tmux -L "$csock" display-message -p '#{pid}')

  clean_sockets

  calive=0
  for _ in $(seq 1 20); do
    kill -0 "$cpid" 2>/dev/null || break
    sleep 0.05
  done
  kill -0 "$cpid" 2>/dev/null && calive=1
  assert_eq 'cleaning up takes the server down, not only its socket' 0 "$calive"
  kill "$cpid" 2>/dev/null
fi
/bin/rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$csock"
unset csock cpid calive

section 'opening a review window: all three panes survive it'
socket=review-test-$$
# kill-server does not always take the socket file with it, and a suite that
# has been run a few hundred times leaves a few hundred of them behind.
trap 'rm -rf "$tmp" "$tmp_counts" "$stack" "$merged" "$tie" "$notrunk" "$unbased" "$unborn"; clean_sockets' EXIT
# -f /dev/null: a server that reads the real config spends half a minute
# letting TPM load every plugin, and none of them matter here.
if ! want_live; then
  skip 'opening a review window' 'live sections are out of scope'
elif ! tmux -L "$socket" -f /dev/null new-session -d -x 120 -y 40 -c "$repo" 2>/dev/null; then
  no 'a throwaway tmux server could be started' 'a server' 'none'
else
  # -f /dev/null leaves tmux's own 2000-line default, and a review whose diff
  # is longer than the scrollback can hold loses the commit headers off the top
  # -- so the row map never completes, and the list sits on its placeholder for
  # good. Real use does not hit this because .tmux.conf sets 50000; the test
  # server has to say so too, or the suite passes or fails on how large the
  # repository's most recent commit happens to be.
  tmux -L "$socket" set-option -g history-limit 50000
  pane=$(tmux -L "$socket" display-message -p '#{pane_id}')
  tmux -L "$socket" run-shell -b -t "$pane" "$plugin/scripts/review.sh open $pane HEAD~1..HEAD"

  win=''
  for _ in $(seq 1 60); do
    win=$(tmux -L "$socket" list-windows -F '#{window_id} #{window_name}' 2>/dev/null |
      grep review | cut -d' ' -f1)
    [[ -n $win ]] && break
    sleep 0.25
  done
  assert_ok "$([[ -n $win ]] && echo 0 || echo 1)" 'the window appears'

  if [[ -n $win ]]; then
    # Wait for the splits, not for the diff: the failure this guards against
    # kills the pane within a second of it starting, and waiting on delta would
    # put half a minute into the suite for nothing.
    for _ in $(seq 1 60); do
      (($(tmux -L "$socket" list-panes -t "$win" -F x 2>/dev/null | grep -c x) >= 3)) && break
      sleep 0.25
    done
    # Then on the diff saying it is done, because the list shows a placeholder
    # until it does and that placeholder names the range -- which one of the
    # assertions below is that it no longer does. A fixed sleep made this test
    # depend on how large the repository's last commit happened to be.
    dpane=$(tmux -L "$socket" show-options -w -t "$win" -qv @review_diff_pane)
    for _ in $(seq 1 160); do
      [[ $(tmux -L "$socket" show-options -w -t "$dpane" -qv @review_loaded 2>/dev/null) == 1 ]] &&
        break
      sleep 0.25
    done
    # Watched for two seconds rather than looked at once after one. The header
    # is painted before the sidebar has heard from tmux at all, and the push
    # that first tells it anything is up to a second behind the subscription:
    # every frame in between was worked out from an empty state, which came to
    # a list one column wide, and the header was drawn at that -- its figures
    # at the foot and the range and the agent cut to nothing above them. A
    # single look a second in lands on either side of that.
    hdr=$(tmux -L "$socket" list-panes -t "$win" -F '#{pane_id} #{pane_start_command}' |
      grep 'review.sh header' | cut -d' ' -f1)
    hdr_cut=0
    for _ in $(seq 1 40); do
      hdr_text=$(tmux -L "$socket" capture-pane -p -t "$hdr" 2>/dev/null)
      [[ $hdr_text == *commit* && $hdr_text != *'HEAD~1..HEAD'* ]] && hdr_cut=$((hdr_cut + 1))
      sleep 0.05
    done
    live=$(tmux -L "$socket" list-panes -t "$win" -F '#{pane_dead}' | grep -c '^0$')
    assert_eq 'all three panes are alive' 3 "$live"

    sb=$(tmux -L "$socket" list-panes -t "$win" -F '#{pane_id} #{pane_start_command}' |
      grep sidebar | cut -d' ' -f1)
    assert_ok "$([[ -n $sb ]] && echo 0 || echo 1)" 'the list pane is one of them'
    hdr=$(tmux -L "$socket" list-panes -t "$win" -F '#{pane_id} #{pane_start_command}' |
      grep 'review.sh header' | cut -d' ' -f1)
    assert_ok "$([[ -n $hdr ]] && echo 0 || echo 1)" 'and the header pane another'
    if [[ -n $sb ]]; then
      drawn=$(tmux -L "$socket" capture-pane -p -t "$sb" | grep -c .)
      assert_ok "$([[ $drawn -gt 0 ]] && echo 0 || echo 1)" 'the list drew something'
      assert_eq 'and the range is no longer one of its rows' 0 \
        "$(tmux -L "$socket" capture-pane -p -t "$sb" | grep -c 'HEAD~1\.\.HEAD')"
    fi
    if [[ -n $hdr ]]; then
      # The one end-to-end check that the sidebar can paint a pane it does not
      # own: everything up to here would pass with the tty write going nowhere.
      # -t a pane still lists every pane of its window, so the height has to be
      # asked for on the pane itself.
      assert_eq 'the header is the four rows it was split at' 4 \
        "$(tmux -L "$socket" display-message -p -t "$hdr" '#{pane_height}')"
      hdr_text=$(tmux -L "$socket" capture-pane -p -t "$hdr")
      assert_match 'it names the range being reviewed' 'HEAD~1\.\.HEAD' "$hdr_text"
      assert_match 'says where a comment would go' 'no agent selected' "$hdr_text"
      assert_match 'and counts what the range comes to' '\+[0-9]+.*1 commit' "$hdr_text"
      assert_eq 'and never draws the count without the range above it' 0 "$hdr_cut"
    fi
  fi
  tmux -L "$socket" kill-server 2>/dev/null
fi

# The reader can drag the border between the list and the diff, and tmux tells
# neither pane that anyone did. The list used to render at the share of the
# window it was opened with whatever its pane had become: dragged narrower, its
# rows wrapped and pushed the commits off the top; dragged wider, it drew into
# 80 columns of a 100-column pane and left the rest blank.
#
# 285 wide: the list's share is 80, delta renders at 202, and 82 is the widest
# the list can be before the diff is narrower than it rendered at.
section 'the commit list follows the border the reader drags'
rsock=review-resize-$$
if ! want_live; then
  skip 'the list against a dragged border' 'live sections are out of scope'
elif ! tmux -L "$rsock" -f /dev/null new-session -d -x 285 -y 78 -c "$repo" \
  'sleep 900' 2>/dev/null; then
  skip 'the list against a dragged border' 'no tmux server could be started'
else
  tmux -L "$rsock" set-option -g history-limit 50000
  rpane=$(tmux -L "$rsock" display-message -p '#{pane_id}')
  tmux -L "$rsock" run-shell -b -t "$rpane" \
    "$plugin/scripts/review.sh open $rpane HEAD~2..HEAD"
  rwin=''
  for _ in $(seq 1 120); do
    rwin=$(tmux -L "$rsock" list-windows -F '#{window_id} #{window_name}' 2>/dev/null |
      grep review | cut -d' ' -f1)
    [[ -n $rwin ]] && break
    sleep 0.25
  done
  if [[ -z $rwin ]]; then
    skip 'the list against a dragged border' 'the review window never opened'
  else
    rdiff=$(tmux -L "$rsock" show-options -w -t "$rwin" -qv @review_diff_pane)
    rlist=$(tmux -L "$rsock" show-options -w -t "$rwin" -qv @review_list_pane)
    for _ in $(seq 1 200); do
      [[ $(tmux -L "$rsock" show-options -w -t "$rdiff" -qv @review_loaded 2>/dev/null) == 1 ]] &&
        break
      sleep 0.25
    done
    rwidth() { tmux -L "$rsock" display-message -p -t "$1" '#{pane_width}'; }
    # The widest row the list drew, and how many rows are wider than the pane --
    # both in columns rather than bytes. The rule is box-drawing and the
    # subjects are cut with an ellipsis, which are three bytes a glyph, so awk's
    # length() and wc -c both read an 80-column row as 235. ${#var} counts
    # characters under a UTF-8 locale, which is what dwidth relies on too.
    #
    # -J, because a pane that narrows rewraps what it already holds: rows drawn
    # for 80 come back from a 60-column pane as 60-column lines and the rest of
    # each on the next, and without joining them again the list reads as having
    # redrawn for 60 when it has not drawn anything. The drag to 60 passed that
    # way for as long as it had existed, and the sidebar losing the push that
    # should have told it about the drag hid behind it.
    rcols() {
      local line max=0
      while IFS= read -r line; do ((${#line} > max)) && max=${#line}; done \
        < <(tmux -L "$rsock" capture-pane -p -J -t "$rlist")
      printf '%s' "$max"
    }
    rover() {
      local line n=0
      while IFS= read -r line; do ((${#line} > $1)) && n=$((n + 1)); done \
        < <(tmux -L "$rsock" capture-pane -p -J -t "$rlist")
      printf '%s' "$n"
    }
    # Waited for, not slept on. tmux moves the border at once, but the rows are
    # rebuilt on the sidebar's next tick and a fixed sleep races it -- caught in
    # the suite with the pane already 82 and its rows still drawn for 60.
    # Returns regardless: what the state actually is, is the assertions' to say.
    rsettle() {
      local _
      for _ in $(seq 1 200); do
        [[ $(rwidth "$rlist") == "$1" && $(rcols) == "$2" ]] && return 0
        sleep 0.25
      done
      return 0
    }
    # The list is zoomed over the whole window while the diff renders, and the
    # diff pane drops the zoom once its first commit is down. Resizing before
    # then is thrown away: the width goes to the zoomed pane, and unzooming
    # restores the layout the pane had before it -- which cost a run here, the
    # drag to 60 coming back as 80. @review_loaded is the diff saying it has
    # finished writing, not the list saying it has finished drawing, so both are
    # waited for.
    for _ in $(seq 1 200); do
      [[ $(tmux -L "$rsock" display-message -p -t "$rwin" '#{window_zoomed_flag}') == 0 ]] &&
        break
      sleep 0.25
    done
    rsettle 80 80
    tmux -L "$rsock" capture-pane -p -S - -E - -t "$rdiff" >"$tmp/rs_base.txt"

    assert_eq 'the list opens at its share of the window' 80 "$(rwidth "$rlist")"
    assert_eq 'and draws rows that exactly fill it' 80 "$(rcols)"

    # Dragged narrower. The diff only gets wider, so nothing it holds can fold.
    tmux -L "$rsock" resize-pane -x 60 -t "$rlist"
    rsettle 60 60
    assert_eq 'dragged narrower, the pane is where it was put' 60 "$(rwidth "$rlist")"
    assert_eq 'and the rows are rebuilt to fit it' 60 "$(rcols)"
    # The failure this replaces: rows built for 80 in a 60-column pane wrap, and
    # every wrapped row costs a second one, so the commits scroll off the top.
    assert_eq 'with no row wide enough to wrap' 0 "$(rover 60)"

    # Dragged wider, but only into what the diff is not drawing on: the two
    # columns held back for the marks. Allowed, and followed.
    tmux -L "$rsock" resize-pane -x 82 -t "$rlist"
    rsettle 82 82
    assert_eq 'dragged wider but within the diff means, the pane stands' 82 \
      "$(rwidth "$rlist")"
    assert_eq 'and the rows are rebuilt again' 82 "$(rcols)"
    assert_eq 'the diff left exactly the width it rendered at' 202 \
      "$(rwidth "$rdiff")"

    # Dragged wider than the diff can afford. The border is taken back to the
    # last width that leaves the diff the 202 it rendered at.
    tmux -L "$rsock" resize-pane -x 100 -t "$rlist"
    # Watched, not only waited for. The list builds its rows for 100 in the turn
    # that sees the drag, takes the border back to 82 and goes on from the state
    # tmux last pushed -- which still says 100, and goes on saying it until the
    # next push a second later. Every row of that second was drawn for 100 in an
    # 82-column pane and wrapped. A wait for 82 and 82 passes over it, because
    # the rows it drew before the drag are still 82 wide when the border comes
    # back, so the second is only seen by looking during it.
    rwide=0
    for _ in $(seq 1 30); do
      [[ $(rwidth "$rlist") == 82 ]] && (($(rcols) > 82)) && rwide=$((rwide + 1))
      sleep 0.1
    done
    rsettle 82 82
    assert_eq 'dragged too wide, the border is taken back' 82 "$(rwidth "$rlist")"
    assert_eq 'and the rows are never drawn wider than it was given back' 0 "$rwide"
    assert_eq 'to exactly what the diff rendered at' 202 "$(rwidth "$rdiff")"
    assert_eq 'and the rows follow it there too' 82 "$(rcols)"
    tmux -L "$rsock" capture-pane -p -S - -E - -t "$rdiff" >"$tmp/rs_after.txt"
    # The whole reason for the clamp. A diff narrower than its content folds
    # every full row, which breaks the row map and breaks searching across the
    # fold. Measured before the clamp existed: this drag wrapped 26 rows.
    assert_ok "$(cmp -s "$tmp/rs_base.txt" "$tmp/rs_after.txt" && echo 0 || echo 1)" \
      'and not one row of the diff folded on the way' 'the same scrollback' 'rows folded'
    unset -f rwidth rcols rover rsettle
    unset rwide
  fi
  tmux -L "$rsock" kill-server 2>/dev/null
fi
rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$rsock"
unset rsock rpane rwin rdiff rlist

# A routed key is sent to {left}, and {left} is the leftmost *visible* pane --
# so in any arrangement where the pressing pane is itself the leftmost visible
# one, send-keys hands the key straight back to the binding that sent it. The
# guard is still true on the way back in, so it sends again: a recursion with no
# base case, which fills the command queue until the server has to be SIGKILLed.
# It wedged a real server for 50 minutes, reached by zooming the diff and
# pressing c.
#
# The two guards are read out of review.tmux rather than repeated here, so that
# this stays a test of the bindings rather than of a copy of them -- eval, not a
# regex, because routes_left is written in terms of in_review. Nothing sends a
# key: the states are built and the formats are asked what they would have
# decided, which is the whole decision and cannot itself hang.
section 'the routing guard: no key is ever routed back into its own pane'
eval "$(grep -E '^(in_review|routes_left|zoomed_review)=' "$plugin/review.tmux")"
assert_ok "$([[ -n ${in_review:-} && -n ${routes_left:-} && -n ${zoomed_review:-} ]] &&
  echo 0 || echo 1)" 'all three guards were found in review.tmux' 'three formats' \
  "${in_review:-} / ${routes_left:-} / ${zoomed_review:-}"

gsock=review-guard-$$
trap 'rm -rf "$tmp" "$tmp_counts" "$stack" "$merged" "$tie" "$notrunk" "$unbased" "$unborn"; clean_sockets' EXIT

if ! want_live; then
  skip 'the routing guard' 'live sections are out of scope'
elif ! tmux -L "$gsock" -f /dev/null new-session -d -x 200 -y 50 2>/dev/null; then
  no 'a throwaway tmux server could be started' 'a server' 'none'
else
  tmux -L "$gsock" split-window -h
  g_sidebar=$(tmux -L "$gsock" list-panes -F '#{pane_id}' | head -1)
  g_diff=$(tmux -L "$gsock" list-panes -F '#{pane_id}' | tail -1)
  tmux -L "$gsock" set-option -w @review 1
  tmux -L "$gsock" copy-mode -t "$g_sidebar"
  tmux -L "$gsock" copy-mode -t "$g_diff"

  # What each binding would decide, and where a routed key would actually land.
  routes() { tmux -L "$gsock" display-message -p -t "$1" "$routes_left"; }
  in_place() { tmux -L "$gsock" display-message -p -t "$1" "$in_review"; }
  unzooms() { tmux -L "$gsock" display-message -p -t "$1" "$zoomed_review"; }
  lands_on() { tmux -L "$gsock" display-message -p -t '{left}' '#{pane_id}'; }

  # The arrangement the plugin builds: the key is pressed on the diff, and the
  # sidebar is a different pane, so routing is the right answer.
  tmux -L "$gsock" select-pane -t "$g_diff"
  assert_eq 'a key on the diff pane still routes' 1 "$(routes "$g_diff")"
  assert_eq 'and it lands on the sidebar, not itself' "$g_sidebar" "$(lands_on)"
  assert_eq 'with no unzoom to do' 0 "$(unzooms "$g_diff")"

  # Mouse scroll over the sidebar puts it in copy-mode, and then the guard used
  # to hold there too -- with {left} resolving to the sidebar itself.
  tmux -L "$gsock" select-pane -t "$g_sidebar"
  assert_eq 'a key on the sidebar itself is refused' 0 "$(routes "$g_sidebar")"
  assert_eq 'which is where it would have landed' "$g_sidebar" "$(lands_on)"

  # Zooming the diff leaves it the only visible pane, so {left} is the diff.
  tmux -L "$gsock" select-pane -t "$g_diff"
  tmux -L "$gsock" resize-pane -Z -t "$g_diff"
  assert_eq 'a key on a zoomed diff is refused' 0 "$(routes "$g_diff")"
  assert_eq 'which is where it would have landed' "$g_diff" "$(lands_on)"
  assert_eq 'and that is the case that unzooms instead' 1 "$(unzooms "$g_diff")"

  # Enter does not route -- it copies in this pane -- so it is not in the loop
  # and must not be refused along with the keys that are. Refusing it here would
  # take the else branch, copy-pipe-and-cancel, which drops the diff out of
  # copy-mode and ends the review: the one thing its binding exists to prevent.
  assert_eq 'Enter still copies on a zoomed diff' 1 "$(in_place "$g_diff")"

  # A review down to one pane has nowhere to route to at all.
  tmux -L "$gsock" resize-pane -Z -t "$g_diff"
  tmux -L "$gsock" kill-pane -t "$g_sidebar"
  tmux -L "$gsock" copy-mode -t "$g_diff"
  assert_eq 'a key in a one-pane review is refused' 0 "$(routes "$g_diff")"
  assert_eq 'which is where it would have landed' "$g_diff" "$(lands_on)"
  assert_eq 'and there is no zoom to undo' 0 "$(unzooms "$g_diff")"
  assert_eq 'but Enter still copies there too' 1 "$(in_place "$g_diff")"

  unset -f routes in_place unzooms lands_on
  tmux -L "$gsock" kill-server 2>/dev/null
fi

# The basis #{scroll_position} is measured against is a number, and a number can
# be 0: a first chunk that fits on screen leaves #{history_size} and
# #{scroll_position} both there, and that zero is written to the option. Read
# back through #{?opt,a,b} it is false -- tmux spells the string "0" false
# exactly as it spells unset false -- so the read fell through to the live
# history size. The basis then ran ahead of the scroll by the whole of the
# second chunk, and the view settle_view restored landed that far down: the
# cursor sat on the last line of the first commit instead of its first.
#
# The format is read out of review.sh rather than repeated here. A pane with a
# real scrollback is needed, or the fallback and the stored zero are the same
# number and nothing is being told apart.
section 'the scroll basis: a stored zero is a basis, not a missing one'
eval "$(grep -E '^hist_base=' "$plugin/scripts/review.sh")"
assert_ok "$([[ -n ${hist_base:-} ]] && echo 0 || echo 1)" \
  'the basis format was found in review.sh' 'a format' "${hist_base:-}"
# What the option was read through before, kept here as the thing that must not
# come back rather than as something the plugin still uses.
was='#{?@review_hist_base,#{@review_hist_base},#{history_size}}'

hsock=review-basis-$$
trap 'rm -rf "$tmp" "$tmp_counts" "$stack" "$merged" "$tie" "$notrunk" "$unbased" "$unborn"; clean_sockets' EXIT

if ! want_live; then
  skip 'the header pane answers its own keys' 'live sections are out of scope'
elif ! tmux -L "$hsock" -f /dev/null new-session -d -x 80 -y 24 \
     'seq 1 400; sleep 600' 2>/dev/null; then
  no 'a throwaway tmux server could be started' 'a server' 'none'
else
  hp=$(tmux -L "$hsock" display-message -p '#{pane_id}')
  # Until the history stops growing, not until it starts: seq is still printing
  # when it first reads non-zero, and on a busy machine the answer read then was
  # 180 of what came to 377 -- which the assertions below then compared against.
  live=0
  live_was=-1
  for _ in $(seq 1 40); do
    live=$(tmux -L "$hsock" display-message -p -t "$hp" '#{history_size}')
    ((live > 0 && live == live_was)) && break
    live_was=$live
    sleep 0.25
  done
  unset live_was
  basis() { tmux -L "$hsock" display-message -p -t "$hp" "$hist_base"; }
  before() { tmux -L "$hsock" display-message -p -t "$hp" "$was"; }

  assert_ok "$((live > 0 ? 0 : 1))" 'the pane has a scrollback to fall back to' \
    'a non-zero history' "$live"

  # Never set: there is no basis yet, so the live history size is the answer.
  tmux -L "$hsock" set-option -p -t "$hp" @review_hist_base ''
  assert_eq 'an unset basis falls back to the live history size' "$live" "$(basis)"

  # Set to zero: the reader is at the top of a diff that fits, and 0 is the
  # answer -- not the history size, which is what the old spelling gave.
  tmux -L "$hsock" set-option -p -t "$hp" @review_hist_base 0
  assert_eq 'a basis of zero reads as zero' 0 "$(basis)"
  assert_eq 'which is exactly what the old spelling got wrong' "$live" "$(before)"

  # And an ordinary basis is still itself.
  tmux -L "$hsock" set-option -p -t "$hp" @review_hist_base 7
  assert_eq 'a non-zero basis reads as itself' 7 "$(basis)"
  assert_eq 'which the old spelling also got right' 7 "$(before)"

  unset -f basis before
  unset was live hp
  tmux -L "$hsock" kill-server 2>/dev/null
fi

section 'header_key: R is answered up here too, by handing it down'
sent=''
tmux() { sent+="[$*]"; return 0; }
quit() { :; }
paint_sel() { :; }
sel=range
hdr_file=''
header_key @1 %1 R
assert_eq 'the key goes to the list, which owns the queue' \
  "[send-keys -t {bottom-left} R]" "$sent"
assert_eq 'and neither row up here moves for it' range "$sel"
sent=''
header_key @1 %1 j
assert_eq 'the rows still answer their own keys' agent "$sel"
unset -f tmux quit paint_sel
unset sent sel hdr_file

section 'the header pane answers its own keys'
# The rows up there are chosen in the pane they are drawn in. The list cannot
# be walked up out of and into them -- that is tested with steer -- so this is
# the only way they are reached.
hdr_calls=''
tmux() { hdr_calls+="[$*]"; return 0; }
quit() { hdr_calls+="[quit $1]"; return 0; }
sel=range
header_key '@9' '%7' j
assert_eq 'j moves to the agent row' agent "$sel"
assert_match 'and publishes it for the sidebar to draw' \
  '@review_hdr_sel agent' "$hdr_calls"
assert_match 'waking the list, which is what paints the pane' \
  'send-keys -t {bottom-left} z' "$hdr_calls"
assert_eq 'in one invocation' 1 "$(grep -cF 'set-option' <<<"$hdr_calls")"
hdr_calls=''
header_key '@9' '%7' k
assert_eq 'k moves back to the range' range "$sel"
header_key '@9' '%7' j
header_key '@9' '%7' j
assert_eq 'and there is nothing below the agent row to reach' agent "$sel"
header_key '@9' '%7' k
header_key '@9' '%7' k
assert_eq 'nor anything above the range' range "$sel"
# Two rows, so the ends of a list are the rows themselves.
header_key '@9' '%7' last
assert_eq 'G is the last of the two' agent "$sel"
header_key '@9' '%7' first
assert_eq 'and gg the first' range "$sel"
hdr_calls=''
header_key '@9' '%7' n
assert_eq 'a key that means nothing here changes nothing' range "$sel"
assert_eq 'and says nothing either' '' "$hdr_calls"

hdr_calls=''
header_key '@9' '%7' enter
assert_match 'enter asks for the picker of the row it is on' \
  '@review_hdr_open range' "$hdr_calls"
assert_match 'and moves the focus to the pane that draws it' \
  'select-pane -t {bottom-left}' "$hdr_calls"
assert_eq 'the selection itself is not republished' 0 \
  "$(grep -cF '@review_hdr_sel' <<<"$hdr_calls")"

hdr_calls=''
header_key '@9' '%7' q
assert_eq 'q ends the loop' 1 "$?"
assert_match 'having closed the review from the pane it was opened over' \
  'quit %7' "$hdr_calls"
unset -f tmux quit
unset sel hdr_calls
restore_review

section 'gutter_goto: the diff is asked to move, not moved here'
shas=(aaa bbb ccc)
declare -A row_of=([aaa]=0 [bbb]=40 [ccc]=200)
cm_row=(10 40)
gutter_cur=1
pending_row=-1
painted=-1
paint_index() { painted=$1; }
gutter_goto
assert_eq 'the list highlight follows the comment straight away' 1 "$painted"
# Held rather than sent: the same path a held j takes, so a run of them costs
# one round trip and not one a key.
assert_eq 'and the move is left for the pause to flush' 40 "$pending_row"
# Nothing to go to, and nothing broken by asking.
cm_row=('')
gutter_cur=0
pending_row=-1
gutter_goto
assert_eq 'an unanchored comment is not somewhere to send anyone' -1 "$pending_row"
unset -f paint_index
unset shas row_of cm_row gutter_cur pending_row painted

section 'paint_gutter: down the pane tty, and only when the frame changed'
gtty=$(mktemp)
gutter_tty=$gtty
gutter_w=20
shown_gutter=''
needs_gutter_clear=1
cm_row=(102)
cm_body=('hello')
paint_gutter 100 8
out=$(cat "$gtty")
assert_match 'the frame reaches the tty' 'hello' "$out"
assert_match 'with the cursor homed first' $'^\e\\[H' "$out"
# Never a full-screen erase: tmux answers \e[2J by pushing the whole screen
# into the pane's scrollback, which on a pane this tall was seventy-eight lines
# of debris per redraw. Every row ends in \e[K instead, so the frame erases the
# screen as it writes it.
assert_eq 'and never with a full-screen erase' 0 "$(grep -c $'\e\\[2J' <<<"$out")"
assert_eq 'every row erasing to its own end instead' 8 \
  "$(grep -o $'\e\\[K' <<<"$out" | grep -c .)"
: >"$gtty"
paint_gutter 100 8
assert_eq 'an identical frame is not written again' '' "$(cat "$gtty")"
paint_gutter 101 8
assert_match 'a moved viewport is' 'hello' "$(cat "$gtty")"
# No tty is not an error: the pane can be killed between a tick reading it and
# this writing to it.
gutter_tty=''
shown_gutter=''
assert_eq 'a pane that has gone is not written to' 0 \
  "$(paint_gutter 100 8; printf '%s' $?)"
/bin/rm -f "$gtty"
unset gtty out gutter_tty gutter_w shown_gutter needs_gutter_clear cm_row cm_body

section 'the comments pane: the diff keeps the width it was rendered at'
# The one test that would have caught the only real bug in this pane: git sizes
# --stat to the terminal, not to delta's --width, so the diffstat came out
# wider than the rest of the diff and folded the moment the pane was split off.
# Nothing short of a real delta against a real repository shows that.
gsock=review-gutter-$$
gtmp=$(mktemp -d)
(
  cd "$gtmp" || exit 1
  git init -q -b main .
  git config user.email t@example.com
  git config user.name Test
  git config commit.gpgsign false
  # A long path and enough churn that git's own diffstat bar is the widest row
  # of the whole diff. git scales that bar to the terminal it believes it is
  # writing to, which is the pane and not delta's --width -- so without
  # --stat-width this row alone comes out wider than the rest of the diff and
  # folds the moment the comments pane is split off. The path is deep and the
  # rows are long for exactly that reason; a short name or a small change
  # leaves the bar well inside the width and the fold never happens.
  mkdir -p a/deeply/nested/path/to/some/source
  f=a/deeply/nested/path/to/some/source/wide-file-name.txt
  for n in $(seq 1 200); do
    printf 'line %03d %s\n' "$n" "$(printf 'x%.0s' $(seq 1 90))"
  done >"$f"
  git add "$f"
  git commit -qm 'add the file'
  for n in $(seq 1 200); do
    printf 'line %03d %s CHANGED\n' "$n" "$(printf 'y%.0s' $(seq 1 90))"
  done >"$f"
  git add "$f"
  git commit -qm 'rewrite every line of it'
) >/dev/null 2>&1

# Keyed off the toplevel git reports, not the path mktemp handed back: on this
# platform the two differ by a /private prefix, and the sidebar works out the
# queue's name from the former.
gstore=$(comment_file "$(git -C "$gtmp" rev-parse --show-toplevel)" 'HEAD~1..HEAD')
rm -f "$gstore"
comment_add "$gstore" "$(git -C "$gtmp" rev-parse --short HEAD)" \
  a/deeply/nested/path/to/some/source/wide-file-name.txt 20 20 '' \
  'queued before the review was ever opened'

if ! want_live; then
  skip 'the comments pane against a real delta' 'live sections are out of scope'
elif ! tmux -L "$gsock" -f /dev/null new-session -d -x 285 -y 78 -c "$gtmp" 2>/dev/null; then
  no 'a throwaway tmux server could be started' 'a server' 'none'
else
  tmux -L "$gsock" set-option -g history-limit 50000
  gpane=$(tmux -L "$gsock" display-message -p '#{pane_id}')
  tmux -L "$gsock" run-shell -b -t "$gpane" \
    "$plugin/scripts/review.sh open $gpane HEAD~1..HEAD"
  gwin=''
  for _ in $(seq 1 80); do
    gwin=$(tmux -L "$gsock" list-windows -F '#{window_id} #{window_name}' 2>/dev/null |
      grep review | cut -d' ' -f1)
    [[ -n $gwin ]] && break
    sleep 0.25
  done
  assert_ok "$([[ -n $gwin ]] && echo 0 || echo 1)" 'the review window appears'

  if [[ -n $gwin ]]; then
    gdiff=$(tmux -L "$gsock" show-options -w -t "$gwin" -qv @review_diff_pane)
    for _ in $(seq 1 200); do
      [[ $(tmux -L "$gsock" show-options -w -t "$gdiff" -qv @review_loaded 2>/dev/null) == 1 ]] &&
        break
      sleep 0.25
    done
    sleep 1
    glist=$(tmux -L "$gsock" show-options -w -t "$gwin" -qv @review_list_pane)
    # 285 less the 80 the list takes and its border leaves 204 for the diff
    # pane; delta is told two less, for the column the marks sit in and its
    # border. That is the whole of what the diff gives up.
    assert_eq 'the width for the pane is reserved on the window' 40 \
      "$(tmux -L "$gsock" show-options -w -t "$gwin" -qv @review_gutter_w)"
    assert_match 'and delta is told the narrower number' 'diff HEAD~1\.\.HEAD 202' \
      "$(tmux -L "$gsock" display-message -p -t "$gdiff" '#{pane_start_command}')"
    # A comment was queued before the review opened, so the marks are already
    # up without anything being pressed: 285 less the list's 80 and two borders
    # and the three the marks take.
    # Waited for rather than slept on. The marks come up when the sidebar's loop
    # next reads the store, and the fixed sleep above races that tick: caught
    # twice, the pane was simply not there yet and every assertion after it
    # failed on the geometry of a review that had no comments pane.
    ggut=''
    for _ in $(seq 1 80); do
      ggut=$(tmux -L "$gsock" list-panes -t "$gwin" -F '#{pane_id} #{pane_start_command}' |
        grep 'review.sh gutter' | cut -d' ' -f1)
      [[ -n $ggut ]] && break
      sleep 0.25
    done
    assert_ok "$([[ -n $ggut ]] && echo 0 || echo 1)" \
      'a queued comment brings the marks up on its own'
    assert_eq 'one column of them, which is all a mark is' 1 \
      "$(tmux -L "$gsock" display-message -p -t "${ggut:-$gdiff}" '#{pane_width}')"
    assert_eq 'and the diff keeps the rest' 202 \
      "$(tmux -L "$gsock" display-message -p -t "$gdiff" '#{pane_width}')"
    # -e, because the mark is a painted cell rather than a glyph: the text of
    # that row is a single space, and what makes it a mark is the background.
    assert_match 'the mark is painted' '48;2;122;162;247' \
      "$(tmux -L "$gsock" capture-pane -p -e -t "${ggut:-$gdiff}")"

    tmux -L "$gsock" capture-pane -p -S - -E - -t "$gdiff" >"$gtmp/before.txt"
    ghist_before=$(tmux -L "$gsock" display-message -p -t "$glist" '#{history_size}')

    # Put the reader somewhere that is not an edge, so that a view which moves
    # has somewhere to move to. tmux repositions a pane's copy-mode whenever the
    # pane is resized -- the cursor goes to the top row and the view slides
    # under it -- and splitting or widening this pane resizes the diff, so
    # writing the first comment used to take the diff out from under the reader.
    gview() {
      tmux -L "$gsock" display-message -p -t "$gdiff" \
        '#{e|-:#{@review_hist_base},#{scroll_position}}:#{copy_cursor_y}'
    }
    # Which pane the window says is active, asked of the window rather than of
    # a pane: -t a pane still lists every pane of its window, so a filter is
    # what picks the one out.
    gactive() {
      tmux -L "$gsock" list-panes -t "$gwin" -F '#{pane_id}' -f '#{pane_active}'
    }
    tmux -L "$gsock" select-pane -t "$gdiff"
    tmux -L "$gsock" send-keys -X -t "$gdiff" -N 20 scroll-up
    tmux -L "$gsock" send-keys -X -t "$gdiff" -N 12 cursor-down
    sleep 1
    gbefore=$(gview)
    assert_match 'the reader is somewhere with room to slip' '^[0-9]+:12$' "$gbefore"

    tmux -L "$gsock" send-keys -t "$glist" C
    for _ in $(seq 1 40); do
      [[ $(tmux -L "$gsock" display-message -p -t "$ggut" '#{pane_width}') == 40 ]] && break
      sleep 0.25
    done
    sleep 1
    assert_eq 'C widens it to everything reserved' 40 \
      "$(tmux -L "$gsock" display-message -p -t "$ggut" '#{pane_width}')"
    # The point of the whole exercise: widening the comments pane does not cost
    # the diff a single column. It is the width it was opened at and the width
    # delta rendered at, before and after.
    assert_eq 'and the diff does not give up one column for it' 202 \
      "$(tmux -L "$gsock" display-message -p -t "$gdiff" '#{pane_width}')"
    assert_match 'and the comment itself is readable now' 'queued before' \
      "$(tmux -L "$gsock" capture-pane -p -t "$ggut")"
    assert_eq 'and the reader is standing in it, which is what they asked for' \
      "$ggut" "$(gactive)"
    assert_eq 'the diff is left exactly where the reader had it' "$gbefore" "$(gview)"

    tmux -L "$gsock" capture-pane -p -S - -E - -t "$gdiff" >"$gtmp/after.txt"
    assert_ok "$(cmp -s "$gtmp/before.txt" "$gtmp/after.txt" && echo 0 || echo 1)" \
      'and not one row of the diff reflowed' 'the same scrollback' 'rows folded'

    # Where the cells came from. The list is the one pane that can afford them:
    # what it gives up is subject, which fit already cuts, and the whole message
    # is printed above the diff a keypress away. 80 less the 39 between a column
    # of marks and a pane wide enough to read one.
    assert_eq 'the commit list is what paid for them' 41 \
      "$(tmux -L "$gsock" display-message -p -t "$glist" '#{pane_width}')"
    # Stated rather than left over, which is the whole reason the layout is
    # restated instead of a border dragged: the three panes and their two
    # borders still account for every column of the window, exactly.
    assert_eq 'and the window still adds up to itself' 285 \
      "$(($(tmux -L "$gsock" display-message -p -t "$glist" '#{pane_width}') +
          $(tmux -L "$gsock" display-message -p -t "$gdiff" '#{pane_width}') +
          $(tmux -L "$gsock" display-message -p -t "$ggut" '#{pane_width}') + 2))"
    # Counted rather than measured: a wrapped row is still two rows of at most
    # the pane's width, so nothing about its content gives it away -- what gives
    # it away is that there are more rows than the list has things to say. One
    # commit in the range, then the rule, the diffstat, the rule and the legend.
    assert_eq 'and it drew five rows, not ten' 5 \
      "$(tmux -L "$gsock" capture-pane -p -t "$glist" | grep -c .)"

    # Collapsed again -- back to the marks, not gone: the comment is still queued.
    tmux -L "$gsock" send-keys -t "$glist" C
    for _ in $(seq 1 40); do
      [[ $(tmux -L "$gsock" display-message -p -t "$ggut" '#{pane_width}') == 1 ]] && break
      sleep 0.25
    done
    sleep 1
    assert_eq 'C again collapses it back to the marks' 1 \
      "$(tmux -L "$gsock" display-message -p -t "$ggut" '#{pane_width}')"
    assert_eq 'rather than closing it, because the comment is still queued' 4 \
      "$(tmux -L "$gsock" list-panes -t "$gwin" -F x | grep -c x)"
    assert_eq 'and still is after it narrows again' "$gbefore" "$(gview)"
    assert_eq 'and the diff never moved at all' 202 \
      "$(tmux -L "$gsock" display-message -p -t "$gdiff" '#{pane_width}')"
    assert_eq 'with the reader back in the diff they were reading' \
      "$gdiff" "$(gactive)"
    assert_eq 'the list having got its own cells back' 80 \
      "$(tmux -L "$gsock" display-message -p -t "$glist" '#{pane_width}')"
    # Every pane that moved is cleared with the layout that moved it. Their rows
    # are as wide as they are, so tmux rewraps them into the scrollback on the
    # way down and joins them on the way up -- none of it ever on screen, all of
    # it accumulating. Measured rather than reasoned about: the list moves by
    # only thirty-nine columns, and the first time this was asked a single
    # widen and narrow had left ten rows behind on top of what it started with.
    #
    # Asked as "no more than it started with" rather than for a number. A
    # review is opened once and its comments read many times, so what matters
    # is that a cycle does not add -- and the pane starts with whatever the
    # reveal left in it, which is not this test's business.
    ghist_after=$(tmux -L "$gsock" display-message -p -t "$glist" '#{history_size}')
    assert_ok "$((ghist_after > ghist_before))" \
      'and a widen and a narrow leave the list no more scrollback than they found' \
      "$ghist_after rows, from $ghist_before" "$ghist_after rows, up from $ghist_before"
    ghdr=$(tmux -L "$gsock" list-panes -t "$gwin" -F '#{pane_id} #{pane_start_command}' |
      grep 'review.sh header' | cut -d' ' -f1)
    assert_eq 'nor the header above it, which moves with it' 0 \
      "$(tmux -L "$gsock" display-message -p -t "${ghdr:-$glist}" '#{history_size}')"
    tmux -L "$gsock" capture-pane -p -S - -E - -t "$gdiff" >"$gtmp/closed.txt"
    assert_ok "$(cmp -s "$gtmp/before.txt" "$gtmp/closed.txt" && echo 0 || echo 1)" \
      'with its scrollback still untouched' 'the same scrollback' 'rows folded'

    # The border the reader drags, against the pane that is paid for out of it.
    #
    # These two had never met in a test, and they did not work. The comments
    # pane takes its cells from the commit list by restating the whole layout,
    # and the layout it restated described the list at its share of the window
    # -- so the moment the reader had dragged that border anywhere else, tmux
    # no longer recognised the window being described, the restatement was
    # refused, and the pane did not widen. Silently, every tick, until the
    # reader dragged back onto 80 or overshot and let the clamp put them there.
    #
    # 285 wide: the diff is pinned at 202 and the pane reserves 40, so with it
    # open the list has 41 to live in and no more. A drag narrower than that is
    # kept, and the cells come out of the strip the diff is not drawing on; a
    # drag wider is squeezed to 41 and handed back when the pane collapses.
    gsettle() {
      local _
      for _ in $(seq 1 80); do
        [[ $(tmux -L "$gsock" display-message -p -t "$1" '#{pane_width}') == "$2" ]] && return 0
        sleep 0.25
      done
      return 0
    }
    # All three in one string, because what matters is that they still add up to
    # the window: a geometry is asserted whole or the one pane that drifted is
    # the one the assertion did not name.
    gwidths() {
      printf '%s/%s/%s' \
        "$(tmux -L "$gsock" display-message -p -t "$glist" '#{pane_width}')" \
        "$(tmux -L "$gsock" display-message -p -t "$gdiff" '#{pane_width}')" \
        "$(tmux -L "$gsock" display-message -p -t "$ggut" '#{pane_width}')"
    }

    # Dragged wider than the open pane leaves room for. 285 less the 60 the
    # list takes, its border, the marks and theirs.
    tmux -L "$gsock" resize-pane -x 60 -t "$glist"
    gsettle "$glist" 60
    assert_eq 'the border moves with the pane still at the marks' '60/222/1' "$(gwidths)"

    tmux -L "$gsock" send-keys -t "$glist" C
    gsettle "$ggut" 40
    assert_eq 'C opens it anyway, squeezing the list to what is left' '41/202/40' \
      "$(gwidths)"
    tmux -L "$gsock" capture-pane -p -S - -E - -t "$gdiff" >"$gtmp/dragged.txt"
    assert_ok "$(cmp -s "$gtmp/before.txt" "$gtmp/dragged.txt" && echo 0 || echo 1)" \
      'with the diff still exactly as delta drew it' 'the same scrollback' 'rows folded'

    tmux -L "$gsock" send-keys -t "$glist" C
    gsettle "$ggut" 1
    assert_eq 'and collapsing returns the drag, not the share' '60/222/1' "$(gwidths)"

    # Dragged inside the 41 instead, where nothing has to be taken from the list
    # at all: the diff is sitting on 244 and only has to keep the 202 it
    # rendered at, so the thirty-nine come out of the forty-two it is not
    # drawing on and the border does not move.
    tmux -L "$gsock" resize-pane -x 38 -t "$glist"
    gsettle "$glist" 38
    assert_eq 'dragged inside what the open pane leaves' '38/244/1' "$(gwidths)"
    # How many rows the list draws at this width, taken here rather than
    # written down: 38 columns is narrow enough that the legend wraps on its
    # own, and how many rows that comes to is the reader's business and not
    # this test's. What is this test's business is that opening the pane does
    # not add to it.
    grows_before=$(tmux -L "$gsock" capture-pane -p -t "$glist" | grep -c .)

    tmux -L "$gsock" send-keys -t "$glist" C
    gsettle "$ggut" 40
    assert_eq 'the pane opens without moving the border at all' '38/205/40' "$(gwidths)"
    tmux -L "$gsock" capture-pane -p -S - -E - -t "$gdiff" >"$gtmp/kept.txt"
    assert_ok "$(cmp -s "$gtmp/before.txt" "$gtmp/kept.txt" && echo 0 || echo 1)" \
      'and the diff untouched there too' 'the same scrollback' 'rows folded'
    # Counted rather than measured. A row built for a width the pane does not
    # have wraps, and a wrapped row is still a row of at most the pane's width,
    # so nothing about one gives it away except that there are more of them
    # than there were. This is the assertion that catches the row-building
    # width and the layout disagreeing about where the border went: the layout
    # leaves the border at 38 and a frame built for 41 folds into 39.
    assert_eq 'and the list drew the same rows it drew before' "$grows_before" \
      "$(tmux -L "$gsock" capture-pane -p -t "$glist" | grep -c .)"

    tmux -L "$gsock" send-keys -t "$glist" C
    gsettle "$ggut" 1
    assert_eq 'and the border is still where the reader put it' '38/244/1' "$(gwidths)"

    # And from wherever else it was pressed. The toggle is offered in the list
    # as well as the diff, and a reader who opens the comments from the list is
    # put back in the list when they close them -- not in the diff, which they
    # were not in to begin with. Slept on rather than waited for: what has to
    # settle is the loop noticing which pane is active, and no pane width
    # changes to wait on in the meantime.
    tmux -L "$gsock" select-pane -t "$glist"
    sleep 1
    tmux -L "$gsock" send-keys -t "$glist" C
    gsettle "$ggut" 40
    assert_eq 'opened from the list, the reader still lands in the comments' \
      "$ggut" "$(gactive)"
    tmux -L "$gsock" send-keys -t "$glist" C
    gsettle "$ggut" 1
    assert_eq 'and closing returns them to the list they opened it from' \
      "$glist" "$(gactive)"
  fi
  tmux -L "$gsock" kill-server 2>/dev/null
fi
rm -f "$gstore"
rm -rf "$gtmp"
rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$gsock"
unset -f gview gsettle gwidths gactive
unset gsock gtmp gstore gpane gwin gdiff glist ggut ghdr gbefore
unset ghist_before ghist_after grows_before

section 'review.sh: the dispatcher'
# The process that holds the header pane open. Given no tty there is nothing to
# hold, so it returns rather than blocking -- which is what lets it be run here
# at all.
hdr_out=$("$plugin/scripts/review.sh" header </dev/null 2>&1)
assert_eq 'header returns when there is no tty to hold open' 0 "$?"
assert_match 'it hides the cursor it would otherwise leave in the pane' \
  '\[\?25l' "$hdr_out"
assert_match 'and puts it back on the way out' '\[\?25h' "$hdr_out"

"$plugin/scripts/review.sh" >/dev/null 2>&1
assert_eq 'no arguments exits 64' 64 "$?"
usage_text=$("$plugin/scripts/review.sh" 2>&1)
assert_match 'usage names every mode' 'open .*diff .*sidebar .*quit .*nav .*jump .*key .*retarget' \
  "$(tr '\n' ' ' <<<"$usage_text")"
literal=0; [[ $usage_text != *'\n'* ]] || literal=1
assert_ok "$literal" 'usage has no literal backslash-n' 'real newlines' "$usage_text"

section 'dwidth: measured against tmux rather than assumed'
# Every glyph in this plugin was counted as two cells for months, and no test
# caught it: they all matched the string that was written rather than the
# column it landed in. This one asks tmux itself. Swap a glyph for one the font
# draws wider, or move to a Nerd Font that is not the Mono variant, and this is
# what says so before the panes go out of alignment.
dsock=review-width-$$
if ! want_live; then
  skip 'dwidth measured against tmux' 'live sections are out of scope'
elif ! tmux -L "$dsock" -f /dev/null new-session -d -x 40 -y 6 'sleep 60' 2>/dev/null; then
  no 'a throwaway tmux server could be started' 'a server' 'none'
else
  # Where the cursor comes to rest after printing the argument, which is the
  # number of cells tmux gave it. Polled rather than slept on: respawn-pane
  # returns before the command inside it has run.
  advance() {
    local i x=''
    tmux -L "$dsock" respawn-pane -k -t 0 "printf %s '$1'; sleep 30" 2>/dev/null
    for ((i = 0; i < 60; i++)); do
      x=$(tmux -L "$dsock" display -p -t 0 '#{cursor_x}' 2>/dev/null)
      [[ -n $x && $x != 0 ]] && break
      sleep 0.05
    done
    printf '%s' "$x"
  }
  # A control at each width, so a harness that has stopped measuring anything
  # cannot pass by answering the same number every time.
  assert_eq 'tmux gives an ascii character one cell' 1 "$(advance a)"
  assert_eq 'and a wide one two' 2 "$(advance 中)"
  for glyph in "$comment_glyph" '' '󰚩' '󰻟'; do
    dwidth "$glyph"
    assert_eq "dwidth agrees with tmux about $glyph" "$(advance "$glyph")" "$REPLY"
  done
  tmux -L "$dsock" kill-server 2>/dev/null
  unset -f advance
  unset glyph
fi
rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$dsock"
unset dsock

section 'end to end: a comment is written, stepped onto, and deleted'
# The keys, against a real review, with nothing stubbed but the editor. Every
# other test of this queue sets cm_row by hand and never presses anything --
# which is how both halves of "d then y deletes nothing" got in: y was dropped
# before it reached the read that was waiting for it, and the comment written on
# the reader's own row was the one comment j would not land on. Neither is
# visible until a key is actually pressed.
#
# Two things this needs that the other live sections do not:
#
# A client on a pty. display-popup answers "no current client" on a detached
# server, so the editor never runs and the comment is never written. script(1)
# is what allocates one; its arguments differ between BSD and GNU, so the shape
# that works here is found rather than assumed.
#
# An editor that does not wait for anyone. EDITOR is set on the server, which is
# where the popup's shell reads it from, and points at a script that writes the
# file it is handed -- the way git's own suite tests a command that opens an
# editor (t/test-lib-functions.sh, test_set_editor).
e2e_sock=review-e2e-$$
e2e_ed=$(mktemp "${TMPDIR:-/tmp}/review-e2e-editor.XXXXXX")
e2e_bodyfile=$(mktemp "${TMPDIR:-/tmp}/review-e2e-body.XXXXXX")
e2e_body='a comment written by the test'
printf '%s\n' "$e2e_body" >"$e2e_bodyfile"
# The body is copied from a file rather than written into the script, so that
# nothing here has to survive two rounds of quoting to reach the editor.
cat >"$e2e_ed" <<EOF
#!/usr/bin/env bash
/bin/cat $(printf '%q' "$e2e_bodyfile") >"\$1"
EOF
chmod +x "$e2e_ed"

# A client on a pty, which is the one step here with nothing to poll before it.
#
# BSD script takes the command as trailing arguments and GNU wants -c; neither
# fails in a way worth reading, so both are tried and the test is whether a
# client turns up. Retried as a whole because it is a race against a server
# that has just started, and a test that fails once in a while for that is
# worse than one that fails for a reason.
e2e_waitc() {
  local _
  for _ in $(seq 1 20); do
    (($(tmux -L "$e2e_sock" list-clients 2>/dev/null | grep -c .) > 0)) && return 0
    sleep 0.25
  done
  return 1
}

# The pty is sized from inside itself before tmux is ever attached to it.
#
# script builds one at the default 80x24, and tmux sizes a window to its
# smallest client -- so attaching one shrank the review to 80 columns, at which
# there is no room to reserve for the comments pane and it is never created.
# That is the hazard the control client is kept clear of, arriving through the
# door opened to make display-popup work at all.
#
# Sized here rather than held still with window-size manual: that option killed
# the server outright when the review opened, and a window that is the size it
# says it is beats one that has been told to ignore its clients.
e2e_attach() {
  local try sized="stty cols 285 rows 78 2>/dev/null; exec $*"
  for try in 1 2 3; do
    script -q /dev/null sh -c "$sized" >/dev/null 2>&1 &
    E2E_PTY=$!
    e2e_waitc && return 0
    kill "$E2E_PTY" 2>/dev/null || true
    script -qc "sh -c $(printf '%q' "$sized")" /dev/null >/dev/null 2>&1 &
    E2E_PTY=$!
    e2e_waitc && return 0
    kill "$E2E_PTY" 2>/dev/null || true
  done
  return 1
}

# The session holds a command of its own rather than a login shell: the client
# is attached and detached a few times getting this far, and a shell that takes
# a hangup with it takes the session and everything below.
if ! want_live; then
  skip 'end to end: a comment is written, stepped onto, and deleted' \
    'live sections are out of scope'
elif ! tmux -L "$e2e_sock" -f /dev/null new-session -d -x 285 -y 78 -c "$repo" \
  'sleep 600' 2>/dev/null; then
  skip 'end to end: a comment is written, stepped onto, and deleted' \
    'no throwaway tmux server could be started'
else
  tmux -L "$e2e_sock" set-option -g history-limit 50000
  tmux -L "$e2e_sock" set-environment -g EDITOR "$e2e_ed"
  e2e_clients=0
  e2e_attach tmux -L "$e2e_sock" attach -t 0 && e2e_clients=1
  if ((e2e_clients == 0)); then
    # Without one, display-popup answers "no current client", the editor never
    # runs and there is nothing to comment on. That is the machine being unable
    # to host the test, not the plugin being wrong, so it is skipped and said.
    skip 'end to end: a comment is written, stepped onto, and deleted' \
      'no client could be attached over a pty'
  else
    e2e_pane=$(tmux -L "$e2e_sock" display-message -p '#{pane_id}')
    tmux -L "$e2e_sock" run-shell -b -t "$e2e_pane" \
      "$plugin/scripts/review.sh open $e2e_pane HEAD~1..HEAD"
    e2e_win=''
    for _ in $(seq 1 240); do
      e2e_win=$(tmux -L "$e2e_sock" list-windows -F '#{window_id} #{window_name}' 2>/dev/null |
        grep review | cut -d' ' -f1)
      [[ -n $e2e_win ]] && break
      sleep 0.25
    done
    [[ -n $e2e_win ]] ||
      skip 'end to end: a comment is written, stepped onto, and deleted' \
        'the review window did not open in time'
  fi

  if [[ -n ${e2e_win:-} ]]; then
    e2e_diff=$(tmux -L "$e2e_sock" show-options -w -t "$e2e_win" -qv @review_diff_pane)
    e2e_list=$(tmux -L "$e2e_sock" show-options -w -t "$e2e_win" -qv @review_list_pane)
    # On the diff being done, and then on the pane having been paid for: the
    # width the comments pane needs is taken out of the diff, and C says there
    # is no room until it has been.
    for _ in $(seq 1 200); do
      [[ $(tmux -L "$e2e_sock" show-options -w -t "$e2e_diff" -qv @review_loaded 2>/dev/null) == 1 ]] &&
        break
      sleep 0.25
    done

    e2e_store=$(comment_file "$repo" 'HEAD~1..HEAD')
    /bin/rm -f "$e2e_store"
    e2e_count() { comment_count "$e2e_store"; }
    # Keys go straight to the list: the bindings that route them from the diff
    # live in .tmux.conf, and this server was started with -f /dev/null.
    tmux -L "$e2e_sock" copy-mode -t "$e2e_diff"
    sleep 0.8
    tmux -L "$e2e_sock" send-keys -t "$e2e_list" c
    for _ in $(seq 1 60); do (($(e2e_count) >= 1)) && break; sleep 0.25; done
    assert_eq 'c writes one through the editor and queues it' 1 "$(e2e_count)"

    # A second, somewhere else in the diff, so that deleting one leaves the
    # other -- an emptied queue and a queue with the wrong record gone look the
    # same when there is only ever one in it.
    tmux -L "$e2e_sock" send-keys -X -t "$e2e_diff" -N 15 cursor-up 2>/dev/null || true
    sleep 0.8
    tmux -L "$e2e_sock" send-keys -t "$e2e_list" c
    for _ in $(seq 1 60); do (($(e2e_count) >= 2)) && break; sleep 0.25; done
    assert_eq 'and a second one from another row' 2 "$(e2e_count)"

    # The marks come up on their own once something is queued -- C is what
    # widens them, not what creates them -- so the pane is waited for first and
    # widened second. Waiting on C to produce it waits for something that has
    # already happened.
    e2e_gut=''
    for _ in $(seq 1 60); do
      e2e_gut=$(tmux -L "$e2e_sock" list-panes -t "$e2e_win" -F '#{pane_id} #{pane_start_command}' 2>/dev/null |
        grep -i gutter | cut -d' ' -f1)
      [[ -n $e2e_gut ]] && break
      sleep 0.25
    done
    # Reports what was there rather than just that it was not the pane, because
    # the answer to "why is there no comments pane" is always in the layout and
    # in what the window says it reserved for one.
    assert_ok "$([[ -n $e2e_gut ]] && echo 0 || echo 1)" \
      'a queued comment brings the marks up on its own' 'a gutter pane' \
      "reserved=$(tmux -L "$e2e_sock" show-options -w -t "$e2e_win" -qv @review_gutter_w) queued=$(e2e_count) panes=[$(tmux -L "$e2e_sock" list-panes -t "$e2e_win" -F '#{pane_id}:#{pane_width}:#{pane_start_command}' 2>/dev/null | sed 's#[^ ]*/scripts/review.sh#review.sh#' | tr '\n' ' ')]"
    if [[ -n $e2e_gut ]]; then
      tmux -L "$e2e_sock" send-keys -t "$e2e_list" C
      for _ in $(seq 1 60); do
        [[ $(tmux -L "$e2e_sock" display-message -p -t "$e2e_gut" '#{pane_width}' 2>/dev/null) == 40 ]] &&
          break
        sleep 0.25
      done
      assert_eq 'and C widens them to the whole pane' 40 \
        "$(tmux -L "$e2e_sock" display-message -p -t "$e2e_gut" '#{pane_width}' 2>/dev/null)"
    fi
  fi

  if [[ -n ${e2e_gut:-} ]]; then
    tmux -L "$e2e_sock" select-pane -t "$e2e_gut"
    sleep 0.8
    # Amber is the colour of the comment being read and of nothing else, so its
    # arrival in the pane is the reader having landed on one.
    e2e_amber() {
      tmux -L "$e2e_sock" capture-pane -p -e -t "$e2e_gut" 2>/dev/null | grep -c '224;175;104'
    }
    assert_eq 'with none stepped onto, nothing is drawn as being read' 0 "$(e2e_amber)"
    tmux -L "$e2e_sock" send-keys -t "$e2e_gut" j
    for _ in $(seq 1 40); do (($(e2e_amber) > 0)) && break; sleep 0.25; done
    # This is the half that a strict comparison broke: the comment is on the row
    # the reader is standing on, and j would step over it to nothing.
    assert_ok "$(($(e2e_amber) > 0 ? 0 : 1))" 'j lands on a comment'

    tmux -L "$e2e_sock" send-keys -t "$e2e_gut" d
    sleep 1.5
    # And this is the other half: d asks, and the y that answers is pressed in
    # this pane rather than in the one that asked.
    tmux -L "$e2e_sock" send-keys -t "$e2e_gut" y
    for _ in $(seq 1 60); do (($(e2e_count) <= 1)) && break; sleep 0.25; done
    assert_eq 'd and then y take exactly one of them out of the queue' 1 "$(e2e_count)"
    assert_eq 'and what is left is still a whole record' 1 \
      "$(comment_load "$e2e_store"; printf '%s' "${#cm_body[@]}")"
    assert_eq 'with its body intact' "$e2e_body" "$(comment_load "$e2e_store"; printf '%s' "${cm_body[0]}")"
    unset -f e2e_amber e2e_count
  fi

  [[ -n ${e2e_store:-} ]] && /bin/rm -f "$e2e_store" "$e2e_store.tmp"
  kill "${E2E_PTY:-0}" 2>/dev/null || true
  tmux -L "$e2e_sock" kill-server 2>/dev/null || true
fi
/bin/rm -f "$e2e_ed" "$e2e_bodyfile" "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$e2e_sock"
unset -f e2e_attach e2e_waitc
unset e2e_sock e2e_ed e2e_bodyfile e2e_body e2e_pane e2e_win e2e_diff e2e_list
unset e2e_store e2e_gut
unset e2e_clients E2E_PTY

section 'end to end: = collapses the commit under the cursor, and = brings it back'
# Against a real review, with nothing stubbed. The sections above check the
# pieces -- the render, the swap, the item under a row -- and this checks the
# promise they are all there to keep: that putting a fold back leaves the pane
# exactly as delta drew it, since every row the plugin follows the reader by is
# counted in that pane.
#
# No client is needed. Nothing here opens a popup, and the keys go straight to
# the list, the way the end-to-end section above sends them.
fold_sock=review-fold-$$
if ! want_live; then
  skip 'end to end: = collapses and brings back' 'live sections are out of scope'
elif ! tmux -L "$fold_sock" -f /dev/null new-session -d -x 285 -y 78 -c "$repo" \
  'sleep 600' 2>/dev/null; then
  skip 'end to end: = collapses and brings back' 'no throwaway tmux server could be started'
else
  tmux -L "$fold_sock" set-option -g history-limit 50000
  fold_pane=$(tmux -L "$fold_sock" display-message -p '#{pane_id}')
  tmux -L "$fold_sock" run-shell -b -t "$fold_pane" \
    "$plugin/scripts/review.sh open $fold_pane HEAD~1..HEAD"
  fold_win=''
  for _ in $(seq 1 240); do
    fold_win=$(tmux -L "$fold_sock" list-windows -F '#{window_id} #{window_name}' 2>/dev/null |
      grep review | cut -d' ' -f1)
    [[ -n $fold_win ]] && break
    sleep 0.25
  done
  if [[ -z $fold_win ]]; then
    skip 'end to end: = collapses and brings back' 'the review window did not open in time'
  else
    fold_diff=$(tmux -L "$fold_sock" show-options -w -t "$fold_win" -qv @review_diff_pane)
    fold_list=$(tmux -L "$fold_sock" show-options -w -t "$fold_win" -qv @review_list_pane)
    for _ in $(seq 1 200); do
      [[ $(tmux -L "$fold_sock" show-options -w -t "$fold_diff" -qv @review_loaded 2>/dev/null) == 1 ]] &&
        break
      sleep 0.25
    done
    # The map is built on the turn after the list hears the diff has landed.
    sleep 1
    fold_cap() { tmux -L "$fold_sock" capture-pane -p -e -S - -E - -t "$fold_diff" 2>/dev/null; }
    fold_title() { tmux -L "$fold_sock" display-message -p -t "$fold_diff" '#{pane_title}'; }
    fold_before=$(fold_cap | cksum)
    fold_title_before=$(fold_title)

    # The diff was handed over with its cursor on the first row, which is the
    # commit's own.
    #
    # Pressed again if nothing comes of it. The list drops keys for as long as it
    # is still holding its placeholder, which can outlast @review_loaded by the
    # second its subscription takes to say so -- and a dropped key changes
    # nothing, so pressing it again cannot overshoot.
    for _ in 1 2 3; do
      tmux -L "$fold_sock" send-keys -t "$fold_list" =
      for _ in $(seq 1 16); do
        [[ $(fold_cap | strip) == *'▸'* ]] && break 2
        sleep 0.25
      done
    done
    fold_mid=$(fold_cap | strip | grep .)
    assert_match 'the commit row is still the first row' '^commit [0-9a-f]{7,}' "$fold_mid"
    assert_match 'and one row stands in for everything under it' \
      $'^[^\n]*\n    ▸ [^\n]+$' "$fold_mid"
    assert_eq 'with the diff still being read in copy-mode' 1 \
      "$(tmux -L "$fold_sock" display-message -p -t "$fold_diff" '#{pane_in_mode}')"

    # Pressed again on the same terms as the first, though by now the list has
    # long left its placeholder: a key it dropped here would read as a fold
    # that does not come back, which is the one thing this is checking.
    for _ in 1 2 3; do
      tmux -L "$fold_sock" send-keys -t "$fold_list" =
      for _ in $(seq 1 16); do
        [[ $(fold_cap | cksum) == "$fold_before" ]] && break 2
        sleep 0.25
      done
    done
    assert_eq 'the second = puts back exactly what delta drew, escapes and all' \
      "$fold_before" "$(fold_cap | cksum)"
    assert_eq 'and the pane keeps the title it had' "$fold_title_before" "$(fold_title)"
    unset -f fold_cap fold_title
  fi
  tmux -L "$fold_sock" kill-server 2>/dev/null || true
fi
/bin/rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$fold_sock"
unset fold_sock fold_pane fold_win fold_diff fold_list fold_before fold_mid fold_title_before

section 'end to end: a fold longer than the view, swapped early and settled'
# The section above folds a diff that fits on the screen, which never takes the
# early swap: there is nothing below the view to wait for. This one is a commit
# of 400 changed lines in a repository made for it, so opening it again after a
# collapse writes far more rows than the view holds. The reader is put on the
# rows that have landed, and then on the whole grid once the rest has -- and the
# pane still has to come back exactly as delta drew it.
early_sock=review-early-$$
early_repo=$(mktemp -d)
early_trace=$(mktemp)
if ! want_live; then
  skip 'end to end: a fold longer than the view' 'live sections are out of scope'
elif ! (cd "$early_repo" && git init -q && seq 1 400 >lines.txt && seq 1 400 >more.txt &&
  git add lines.txt more.txt &&
  git -c commit.gpgsign=false -c user.name=t -c user.email=t@example.com commit -qm one &&
  seq 1 400 | sed 's/$/ changed/' >lines.txt && seq 1 400 | sed 's/$/ changed/' >more.txt &&
  git -c commit.gpgsign=false -c user.name=t -c user.email=t@example.com commit -qam two); then
  skip 'end to end: a fold longer than the view' 'the fixture repository could not be made'
elif ! tmux -L "$early_sock" -f /dev/null new-session -d -x 285 -y 78 -c "$early_repo" \
  'sleep 600' 2>/dev/null; then
  skip 'end to end: a fold longer than the view' 'no throwaway tmux server could be started'
else
  tmux -L "$early_sock" set-option -g history-limit 50000
  tmux -L "$early_sock" set-environment -g REVIEW_TRACE "$early_trace"
  early_pane=$(tmux -L "$early_sock" display-message -p '#{pane_id}')
  tmux -L "$early_sock" run-shell -b -t "$early_pane" \
    "$plugin/scripts/review.sh open $early_pane HEAD~1..HEAD"
  early_win=''
  for _ in $(seq 1 240); do
    early_win=$(tmux -L "$early_sock" list-windows -F '#{window_id} #{window_name}' 2>/dev/null |
      grep review | cut -d' ' -f1)
    [[ -n $early_win ]] && break
    sleep 0.25
  done
  if [[ -z $early_win ]]; then
    skip 'end to end: a fold longer than the view' 'the review window did not open in time'
  else
    early_diff=$(tmux -L "$early_sock" show-options -w -t "$early_win" -qv @review_diff_pane)
    early_list=$(tmux -L "$early_sock" show-options -w -t "$early_win" -qv @review_list_pane)
    for _ in $(seq 1 200); do
      [[ $(tmux -L "$early_sock" show-options -w -t "$early_diff" -qv @review_loaded 2>/dev/null) == 1 ]] &&
        break
      sleep 0.25
    done
    sleep 1
    early_cap() { tmux -L "$early_sock" capture-pane -p -e -S - -E - -t "$early_diff" 2>/dev/null; }
    early_before=$(early_cap | cksum)
    # Collapsed first: that render is two rows, all of them in the view.
    for _ in 1 2 3; do
      tmux -L "$early_sock" send-keys -t "$early_list" =
      for _ in $(seq 1 16); do
        [[ $(early_cap | strip) == *'▸'* ]] && break 2
        sleep 0.25
      done
    done
    # Opened again: four hundred rows and more, with a view of 78.
    : >"$early_trace"
    for _ in 1 2 3; do
      tmux -L "$early_sock" send-keys -t "$early_list" =
      for _ in $(seq 1 16); do
        [[ $(early_cap | cksum) == "$early_before" ]] && break 2
        sleep 0.25
      done
    done
    sleep 0.5
    assert_match 'the reader was put on the view before the rest had landed' \
      'fold-early' "$(cat "$early_trace")"
    assert_eq 'and the pane is back exactly as delta drew it' "$early_before" "$(early_cap | cksum)"
    # Settled: copy-mode on the whole grid, not the part the early swap saw, and
    # the reader still on the commit row at the top of it.
    assert_eq 'on the whole grid, with the reader still at the top of it' '1 0 0' \
      "$(tmux -L "$early_sock" display-message -p -t "$early_diff" \
        '#{==:#{@review_hist_base},#{history_size}} #{e|-:#{@review_hist_base},#{scroll_position}} #{copy_cursor_y}')"

    # And from the middle, where goto-line has real distance to work out: the
    # view's top on row 10, the cursor thirty rows down it inside the first
    # file's hunk. = collapses that hunk with the whole second file still below
    # the view, so the reader is put on it early -- and the view keeps its top,
    # with the cursor gone up to the hunk's box.
    early_base=$(tmux -L "$early_sock" display-message -p -t "$early_diff" '#{@review_hist_base}')
    tmux -L "$early_sock" send-keys -X -t "$early_diff" goto-line $((early_base - 10)) ';' \
      send-keys -X -t "$early_diff" top-line ';' \
      send-keys -X -N 30 -t "$early_diff" cursor-down
    sleep 0.5
    early_box=$(early_cap | strip | grep -nE '^(─)+┐' | head -1 | cut -d: -f1)
    early_box=$((early_box - 1))
    : >"$early_trace"
    for _ in 1 2 3; do
      tmux -L "$early_sock" send-keys -t "$early_list" =
      for _ in $(seq 1 16); do
        grep -q fold-swapped "$early_trace" && break 2
        sleep 0.25
      done
    done
    sleep 0.5
    assert_match 'from the middle the reader is put on the view early too' \
      'fold-early' "$(cat "$early_trace")"
    assert_eq 'and settled with the view where it was and the cursor on the box' \
      "10 $((early_box - 10))" \
      "$(tmux -L "$early_sock" display-message -p -t "$early_diff" \
        '#{e|-:#{@review_hist_base},#{scroll_position}} #{copy_cursor_y}')"
    unset -f early_cap
  fi
  tmux -L "$early_sock" kill-server 2>/dev/null || true
fi
/bin/rm -rf "$early_repo" "$early_trace" "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$early_sock"
unset early_sock early_repo early_trace early_pane early_win early_diff early_list early_before
unset early_base early_box

printf '\n\e[1m%s\e[0m  \e[32m%d passed\e[0m' 'total' "$passed"
((skipped)) && printf '  \e[33m%d skipped\e[0m' "$skipped"
if ((failed)); then
  printf '  \e[31m%d failed\e[0m\n' "$failed"
  exit 1
fi
printf '\n'
