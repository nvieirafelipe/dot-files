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

section 'dwidth: a glyph is two cells'
dwidth 'abc'; assert_eq 'ascii is one cell a character' 3 "$REPLY"
dwidth 'héllo'; assert_eq 'an accent is still one cell' 5 "$REPLY"
dwidth '󰚩'; assert_eq 'a nerd glyph is two' 2 "$REPLY"
dwidth ' ab'; assert_eq 'and counts alongside the rest' 5 "$REPLY"
dwidth ''; assert_eq 'empty is nothing' 0 "$REPLY"

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
  'diff  jk line  n/N any  ][ file  }{ commit  c comment  s send' "$(strip <<<"$REPLY")"
render_legend 30 diff legend_diff_tiers
assert_eq 'narrowest diff form at 30' 'diff  n/N any  c comment' "$(strip <<<"$REPLY")"
render_legend 101 agent legend_session_tiers
assert_match 'the agent row names the comment keys' \
  'enter agent.*c comment.*s send' "$(strip <<<"$REPLY")"
render_legend 101 list legend_list_tiers
assert_match 'list form names the page and end keys' 'PgUp/PgDn page.*gg/G first/last' "$(strip <<<"$REPLY")"
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
assert_eq 'an unbound letter is nothing' '' "$(key_of 'z')"
assert_eq 'an unknown sequence is nothing' '' "$(key_of '\e[Z')"
read_key </dev/null
assert_eq 'no input at all reports the tick' 1 "$?"
unset -f key_of

section 'the range line is a row of the list'
range='base..HEAD'
shas=(c0 c1 c2)
subs=(s0 s1 s2)
whens=('1 hour ago' '1 hour ago' '1 hour ago')
authors=(A A A)
needs_clear=0
build_rows 60
git() { :; }

# Not `plain`: review.sh has a local array of that name, and shellcheck reads
# the two as one variable across the source.
rendered=$(render 0 60 20 list 1 | strip)
assert_match 'its legend is shown instead of the list one' 'range  enter pick' "$rendered"
assert_eq 'and the list legend is not' 0 "$(grep -c 'list  jk commit' <<<"$rendered")"
sel=$(render 0 60 20 list 1 | grep -F -- "$active" | strip)
assert_match 'the range row is the highlighted one' 'base\.\.HEAD' "$sel"
assert_eq 'and it is the only one' 1 "$(render 0 60 20 list 1 | grep -cF -- "$active")"
sel=$(render 0 60 20 list 0 | grep -F -- "$active" | strip)
assert_match 'without it the first commit is highlighted' 'c0' "$sel"
assert_eq 'and the range row is not' 0 \
  "$(render 0 60 20 list 0 | grep -F -- "$active" | grep -c 'base')"

# steer decides when the range line is selected; the two moves it can make from
# there are stubbed, since both of them talk to tmux.
select_index() { stub_index=$1; }
jump() { stub_jump="$*"; }
height=20
pub_commits='2 40'; pub_files='5 9'; pub_stops='2 5 9 40'
stub_index=''; stub_jump=''

# Two rows sit above the list: the range and, under it, the agent a comment
# would go to. Walking up off the first commit reaches the nearer one first.
on_range=0; on_session=0
steer p k 0 100 100 0
assert_eq 'moving up off the first commit selects the agent row' 1 "$on_session"
assert_eq 'and not the range, which is another row up' 0 "$on_range"
steer p k 0 100 100 0
assert_eq 'moving up again reaches the range' 1 "$on_range"
assert_eq 'and leaves the agent row' 0 "$on_session"
assert_eq 'neither move touched the diff' '' "$stub_jump"
steer p k 0 100 100 0
assert_eq 'nothing sits above the range' 1 "$on_range"
steer p j 0 100 100 0
assert_eq 'moving down goes back to the agent row' 1 "$on_session"
assert_eq 'not straight to the list' '' "$stub_index"
steer p j 0 100 100 0
assert_eq 'and again lands on the first commit' 0 "$stub_index"
assert_eq 'leaving the agent row' 0 "$on_session"

on_range=1; on_session=0
steer p n 0 100 100 0
assert_eq 'any other key leaves the range line' 0 "$on_range"
on_range=0; on_session=1
steer p n 0 100 100 0
assert_eq 'and the agent row too' 0 "$on_session"

on_range=0; on_session=0
stub_jump=''
steer p k 2 100 100 0
assert_eq 'moving up from further down reaches neither' 0 "$on_session"
assert_eq 'nor the range' 0 "$on_range"
assert_match 'it just moves a commit' 'prev' "$stub_jump"

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
for key in first last page_up page_down k; do
  on_range=1; stub_index=''; stub_jump=''
  steer p "$key" 0 100 100 0
  assert_eq "$key does nothing from the range line" '1  ' \
    "$on_range $stub_index $stub_jump"
done
on_range=1
steer p n 0 100 100 0
assert_eq 'a diff movement still works, and leaves the range line' 0 "$on_range"
restore_review

section 'the picker: what it offers and how it moves'
declare -a pick_kind pick_label pick_extra pick_payload
load_pick_items 'base..HEAD'
assert_eq 'the range being reviewed is the first item' range "${pick_kind[0]}"
assert_eq 'and it is labelled as the outstanding one' outstanding "${pick_label[0]}"
assert_eq 'it carries the range in the second column' 'base..HEAD' "${pick_extra[0]}"
assert_match 'the working tree is offered' 'wip' "${pick_kind[*]}"
assert_match 'the index is offered' 'staged' "${pick_kind[*]}"
assert_match 'a range can be typed' 'prompt-range' "${pick_kind[*]}"
assert_match 'a commit count can be typed' 'prompt-count' "${pick_kind[*]}"
assert_match 'branches are offered' 'since' "${pick_extra[*]}"
branch_payloads=0
for i in "${!pick_kind[@]}"; do
  [[ ${pick_extra[i]} == since && -n ${pick_payload[i]} ]] && branch_payloads=1
done
assert_eq 'every branch carries the ref to review against' 1 "$branch_payloads"
assert_eq 'the arrays stay the same length' \
  "${#pick_kind[@]} ${#pick_kind[@]} ${#pick_kind[@]}" \
  "${#pick_label[@]} ${#pick_extra[@]} ${#pick_payload[@]}"

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
# height 16 leaves eight rows for the list: three header rows -- the range, the
# agent a comment would go to, and the count -- three rules, the stat and one
# key row.
out=$(render 0 60 16 diff | strip)
assert_match 'header names the range' 'base\.\.HEAD' "$out"
assert_match 'the agent row is drawn under it' 'no agent selected' "$out"
assert_match 'header counts the commits' '10 commits' "$out"
assert_match 'shows the slice when the list overflows' '1-8' "$out"
assert_match 'starts at the first commit' 'c0' "$out"
assert_eq 'last visible row is the eighth' 1 "$(grep -c ' c7 ' <<<"$out")"
assert_eq 'the ninth is off screen' 0 "$(grep -c ' c8 ' <<<"$out")"
out=$(render 9 60 16 diff | strip)
assert_match 'selection at the end clamps the slice' '3-10' "$out"
assert_eq 'the first is now off screen' 0 "$(grep -c ' c0 ' <<<"$out")"
assert_match 'the last is on screen' 'c9' "$out"
out=$(render 5 60 16 diff | strip)
assert_match 'selection in the middle is centred' '2-9' "$out"
out=$(render 0 60 40 diff | strip)
assert_eq 'no slice indicator when everything fits' 0 "$(grep -c '1-10' <<<"$out")"

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
assert_eq 'and the tail is everything after it' 'c1..HEAD' "${chunks[1]}"
# A one-commit range has nothing to split, and splitting it would buy an empty
# second chunk for a git, a delta and a settle.
git() { [[ $* == 'rev-list --reverse base..HEAD' ]] && printf 'c1\n'; }
chunks=(); plan_chunks 'base..HEAD'
assert_eq 'one commit has nothing to split' 1 "${#chunks[@]}"
assert_eq 'so the whole range goes in one' 'base..HEAD' "${chunks[0]}"
chunks=(); plan_chunks 'HEAD'
assert_eq 'and neither has a range without ..' 'HEAD' "${chunks[0]}"
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
assert_match 'the list is told to stop waiting' "send-keys -t {left-of} z" "$reveal_args"
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
width=80; height=40; on_range=0; searching=0; on_session=0; spin=5
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
restore_review; unset hold_calls

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
assert_eq 'sidebar carries the geometry too' 'sidebar(%1 base..HEAD 220 55)' \
  "$(dispatch sidebar '%1' 'base..HEAD' 220 55)"
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
  return 0
}
calls() { open_calls=$(cat "$open_log"); : >"$open_log"; }
gr_resolve_range() { REPLY='base..HEAD'; return 0; }
self='/plugin/review.sh'
open '%0'
cd "$open_cwd" || :
calls
assert_match 'the diff pane is a new window named for the range' \
  'new-window .*-n base\.\.HEAD review' "$open_calls"
assert_match 'and it is handed the width delta must render at' \
  'review\.sh diff base\.\.HEAD 142' "$open_calls"
assert_match 'the list is split off it at its final width' \
  'split-window -hb -l 77' "$open_calls"
assert_match 'and told the window geometry, so it need ask tmux nothing' \
  'sidebar %7 base\.\.HEAD 220 55' "$open_calls"
assert_match 'the split, the focus and the zoom are one invocation' \
  "split-window .*; select-pane -t {left} ; resize-pane -Z -t {left}" "$open_calls"
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
unset -f tmux open_info calls
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
open() { retarget_calls+="[open $*]"; }
retarget_pane='%7'; retarget_calls=''; retarget '@9' 'HEAD~5..HEAD'
assert_match 'the new review is opened over the old pane' \
  'open %7 HEAD~5\.\.HEAD @4' "$retarget_calls"
assert_match 'and the window it replaces is closed afterwards' \
  'kill-window -t @9' "$retarget_calls"
retarget_pane=''; retarget_calls=''; retarget '@9' 'HEAD~5..HEAD'
assert_eq 'a window that is not a review is left alone' '' "$retarget_calls"
unset -f tmux; restore_review; unset retarget_calls retarget_pane

section 'keypress: the key goes to the list, whichever pane is focused'
key_calls=''
tmux() {
  case $1 in
    show-options) printf '%s' "$key_dpane" ;;
    list-panes) printf '%s\n%s\n' '%7' '%8' ;;
    *) key_calls+="[$*]" ;;
  esac
  return 0
}
key_dpane='%7'; key_calls=''; keypress '@9' c
assert_eq 'the pane that is not the diff gets it' '[send-keys -t %8 c]' "$key_calls"
key_dpane=''; key_calls=''; keypress '@9' c
assert_eq 'a window with no diff pane recorded takes no key' '' "$key_calls"
# A window whose only pane is the diff has no list to hand anything to.
tmux() {
  case $1 in
    show-options) printf '%%7' ;;
    list-panes) printf '%%7\n' ;;
    *) key_calls+="[$*]" ;;
  esac
  return 0
}
key_calls=''; keypress '@9' c
assert_eq 'and neither does one with no list' '' "$key_calls"
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
git() { diff_events+="[git ${*: -1}]"; }
tmux() { diff_events+="[tmux $*]"; }
TMUX_PANE='%7'
diff_chunks=(c1 'c1..HEAD'); diff_events=''
diff_pane_cmd 'base..HEAD' 142 </dev/null
assert_match 'the first commit is written before anything else' \
  '^\[git c1\]\[reveal\]' "$diff_events"
assert_match 'the reader is handed the pane before the rest arrives' \
  'reveal\]\[git c1\.\.HEAD\]' "$diff_events"
assert_eq 'and the view is settled once, after the last chunk' 1 \
  "$(grep -c '\[settle\]' <<<"$diff_events")"
assert_match 'the list is told the diff has landed' '@review_loaded 1' "$diff_events"
assert_match 'and woken, in the same invocation' 'send-keys -t {left-of} z' "$diff_events"
assert_match 'the pane closes the review when it is dismissed' 'quit %7' "$diff_events"
# One chunk means one pass and nothing appended behind the reader, so there is
# no stranded grid to re-enter.
diff_chunks=('base..HEAD'); diff_events=''
diff_pane_cmd 'base..HEAD' 142 </dev/null
assert_eq 'a review small enough not to be split does not settle' 0 \
  "$(grep -c '\[settle\]' <<<"$diff_events")"
assert_eq 'and reveals once' 1 "$(grep -c '\[reveal\]' <<<"$diff_events")"
unset -f git tmux
restore_review
unset diff_events diff_chunks

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
pick_payload=('HEAD~4..HEAD' '' '' 'stash@{2}' '' '' '')
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
assert_match 'a count is asked for at the prompt' \
  "command-prompt -p review the last n commits: -I 1" "$pick_args"
assert_match 'and answered by retargeting this window' \
  'run-shell "/plugin/review.sh retarget @9 %%"' "$pick_args"
pick_args=''; apply_pick '%7' '@9' 5
assert_match 'a range is asked for with a sensible default' \
  "command-prompt -p review: -I origin/HEAD" "$pick_args"
pick_args=''; apply_pick '%7' '@9' 6
assert_eq 'the row that says no agent is running does nothing' '' "$pick_args"
unset -f tmux; restore_review; unset pick_args

section 'send_comments: to the agent that was chosen, if it is still there'
send_msgs=''
comment_send() { send_msgs+="[paste $1]"; return "$send_paste_rc"; }
tmux() {
  case $1 in
    display-message)
      [[ $2 == -p ]] && return "$send_pane_rc"
      send_msgs+="[say ${*:2}]"; return 0 ;;
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
  'press enter there to run it' "$send_msgs"
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
# show-option is how the entry point reads its two settable keys; everything
# else is the one call that binds.
if [[ $1 == show-option ]]; then
  printf '\n'
  exit 0
fi
printf '%s\n' "$*" >>"$TMUX_LOG"
FAKE
chmod +x "$fake_bin/tmux"
TMUX_LOG=$tmux_log PATH="$fake_bin:$PATH" "$plugin/review.tmux"
bound=$(cat "$tmux_log")
assert_eq 'the bindings are sent as one call, not a dozen' 1 "$(grep -c . <<<"$bound")"
assert_match 'prefix+g opens a review, in the background' \
  'bind-key g run-shell -b .*/scripts/review\.sh open #\{pane_id\}' "$bound"
assert_match 'prefix+G is the working tree, in a popup' \
  'bind-key G display-popup .*/bin/git-review --wip' "$bound"
assert_eq 'eleven keys are bound in copy-mode' 11 \
  "$(grep -o 'bind-key -T copy-mode-vi' <<<"$bound" | grep -c .)"
for k in ']' '\[' '}' '{' c s a n N q Enter; do
  matched=0; grep -q -- "bind-key -T copy-mode-vi $k " <<<"$bound" || matched=1
  assert_ok "$matched" "copy-mode $k is bound"
done
assert_match 'every one is guarded on the window being a review' \
  '@review' "$bound"
assert_match 'and on the pane being read rather than showing output' \
  'pane_mode},copy-mode' "$bound"
assert_match 'n falls back to search-again outside a review' \
  "send-keys -X search-again" "$bound"
assert_match 'and Enter to the yank that cancels' 'copy-pipe-and-cancel' "$bound"
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
printf '%s\n' "$*" >>"$TMUX_LOG"
FAKE
chmod +x "$fake_bin/tmux"
TMUX_LOG=$tmux_log PATH="$fake_bin:$PATH" "$plugin/review.tmux"
bound=$(cat "$tmux_log")
assert_match 'a key set by the user is the one bound' 'bind-key R run-shell' "$bound"
assert_match 'and so is the one for the working tree' 'bind-key W display-popup' "$bound"
/bin/rm -rf "$fake_bin"; /bin/rm -f "$tmux_log"
unset bound tmux_log fake_bin

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

section 'sidebar: the loop, driven by a scripted server'
# The loop only ever leaves on q or on the pane going away, so the harness
# scripts a finite run of ticks and lets read_state fail after the last -- which
# is the same signal it gets when the diff pane is closed.
#
# The tick index lives in a file: read_state reads the state through $(...), so
# a counter in a variable would be incremented in a subshell and lost.
sb_log=$(mktemp); sb_out=$(mktemp); sb_ix=$(mktemp); sb_ticks=$(mktemp)
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
    map_rows() { row_of=([c0]=5 [c1]=40); file_rows=(); file_names=(); mapped=1; }
    steer() { printf 'STEER %s\n' "$*" >>"$sb_log"; }
    preselect_agent() { printf 'PRESELECT %s\n' "$*" >>"$sb_log"; }
    load_pick_items() { pick_kind=(range); pick_label=(x); pick_extra=(''); pick_payload=(''); }
    load_pick_sessions() { pick_kind=(session); pick_label=(y); pick_extra=(''); pick_payload=("%5${US}y"); }
    pick_keys() { printf 'PICKKEYS %s\n' "$*" >>"$sb_log"; picking=0; }
    sidebar '%7' 'base..HEAD' 220 40
  ) <<<"$keys" >"$sb_out" 2>&1
  sb_seen=$(cat "$sb_log")
}

sidebar_run '' "$sb_normal" "$sb_normal"
assert_match 'the first frame is the placeholder, drawn before tmux is touched' \
  'LOADING 220 40 0' "$sb_seen"
assert_match 'and once the diff has landed, the list' 'RENDER 0 77 40 diff' "$sb_seen"
assert_match 'the list is sized from the window and the diff pane' \
  'RENDER 0 77 ' "$sb_seen"
assert_match 'an agent is guessed once the reader has the list' \
  'PRESELECT @9 main' "$sb_seen"

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

# a reaches the agent picker without having to walk the selection to its row.
sidebar_run 'a' "$sb_normal" "$sb_normal" "$sb_normal"
assert_match 'a opens the picker' 'PICKER 77 40 0' "$sb_seen"
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
    sidebar '%7' 'base..HEAD' 220 40
  ) </dev/null 2>&1
}
assert_match 'a range with nothing in it says so and waits' \
  'nothing to review' "$(sidebar_empty | strip)"

/bin/rm -f "$sb_log" "$sb_out" "$sb_ix" "$sb_ticks"
unset -f sidebar_run sidebar_empty sb_tick
unset sb_log sb_out sb_ix sb_ticks sb_seen sb_normal sb_loading sb_unfocus sb_cancelled

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

# No remote at all: nothing is outstanding, so the tip commit is the review.
assert_eq 'no base and nothing outstanding falls back to the tip' 'HEAD~1..HEAD' \
  "$(cd "$tmp" && "$review" --range)"

# With origin/HEAD recorded, the base is the remote branch.
(
  cd "$tmp" || exit 1
  git update-ref refs/remotes/origin/main "$(git rev-parse HEAD~2)"
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
) >/dev/null 2>&1
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
section 'opening a review window: both panes survive it'
socket=review-test-$$
# kill-server does not always take the socket file with it, and a suite that
# has been run a few hundred times leaves a few hundred of them behind.
trap 'rm -rf "$tmp" "$tmp_counts"; rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$socket"' EXIT
# -f /dev/null: a server that reads the real config spends half a minute
# letting TPM load every plugin, and none of them matter here.
if ! tmux -L "$socket" -f /dev/null new-session -d -x 120 -y 40 -c "$repo" 2>/dev/null; then
  no 'a throwaway tmux server could be started' 'a server' 'none'
else
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
    # Wait for the split, not for the diff: the failure this guards against
    # kills the pane within a second of it starting, and waiting on delta would
    # put half a minute into the suite for nothing.
    for _ in $(seq 1 60); do
      (($(tmux -L "$socket" list-panes -t "$win" -F x 2>/dev/null | grep -c x) >= 2)) && break
      sleep 0.25
    done
    sleep 2
    live=$(tmux -L "$socket" list-panes -t "$win" -F '#{pane_dead}' | grep -c '^0$')
    assert_eq 'both panes are alive' 2 "$live"

    sb=$(tmux -L "$socket" list-panes -t "$win" -F '#{pane_id} #{pane_start_command}' |
      grep sidebar | cut -d' ' -f1)
    assert_ok "$([[ -n $sb ]] && echo 0 || echo 1)" 'the list pane is one of them'
    if [[ -n $sb ]]; then
      drawn=$(tmux -L "$socket" capture-pane -p -t "$sb" | grep -c .)
      assert_ok "$([[ $drawn -gt 0 ]] && echo 0 || echo 1)" 'the list drew something'
      assert_match 'and it names the range being reviewed' 'HEAD~1\.\.HEAD' \
        "$(tmux -L "$socket" capture-pane -p -t "$sb")"
    fi
  fi
  tmux -L "$socket" kill-server 2>/dev/null
fi

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
trap 'rm -rf "$tmp" "$tmp_counts"; rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$socket" \
  "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$gsock"' EXIT

if ! tmux -L "$gsock" -f /dev/null new-session -d -x 200 -y 50 2>/dev/null; then
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
trap 'rm -rf "$tmp" "$tmp_counts"; rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$socket" \
  "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$gsock" \
  "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$hsock"' EXIT

if ! tmux -L "$hsock" -f /dev/null new-session -d -x 80 -y 24 \
     'seq 1 400; sleep 600' 2>/dev/null; then
  no 'a throwaway tmux server could be started' 'a server' 'none'
else
  hp=$(tmux -L "$hsock" display-message -p '#{pane_id}')
  live=0
  for _ in $(seq 1 40); do
    live=$(tmux -L "$hsock" display-message -p -t "$hp" '#{history_size}')
    ((live > 0)) && break
    sleep 0.25
  done
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

section 'review.sh: the dispatcher'
"$plugin/scripts/review.sh" >/dev/null 2>&1
assert_eq 'no arguments exits 64' 64 "$?"
usage_text=$("$plugin/scripts/review.sh" 2>&1)
assert_match 'usage names every mode' 'open .*diff .*sidebar .*quit .*nav .*jump .*key .*retarget' \
  "$(tr '\n' ' ' <<<"$usage_text")"
literal=0; [[ $usage_text != *'\n'* ]] || literal=1
assert_ok "$literal" 'usage has no literal backslash-n' 'real newlines' "$usage_text"

printf '\n\e[1m%s\e[0m  \e[32m%d passed\e[0m' 'total' "$passed"
if ((failed)); then
  printf '  \e[31m%d failed\e[0m\n' "$failed"
  exit 1
fi
printf '\n'
