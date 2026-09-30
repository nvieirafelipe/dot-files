#!/usr/bin/env bash
# Tests for scripts/agent-status.sh, scripts/agent-spinner.sh and
# scripts/agent-focus.sh.
#
# Run: tests/agent_status_test.sh, or run_tests from the plugin root.
#
# All three dispatch only when run, not when sourced, so everything that needs
# no tmux server is exercised directly and the rest is stubbed: tmux, ps and
# git are shell functions here, which take precedence over the commands of the
# same name. What is left -- the detach, the notification itself -- is the part
# that only means anything against a live server and a live Notification
# Center, and is covered by the dispatcher smoke test at the end.
#
# The fixture variables are read by the functions under test rather than by
# this file, and the colours and glyphs belong to the script it sources; the
# stubs are reached indirectly. SC2218 because a section that stubs a function
# puts that definition after the sections which call the real one, which reads
# from here as a function used before it is defined. SC2319 because the status
# assert_ok is handed is a condition's on purpose -- see the note on it below.
# shellcheck disable=SC2034,SC2154,SC1091,SC2317,SC2218,SC2319

set -uo pipefail

# -P so this works when run through the symlink install.sh puts in
# ~/.tmux/plugins: the script under test is always the one in the checkout this
# file belongs to, not whatever the link was followed from.
here=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)
plugin=$(cd "$here/.." && pwd)
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

# A repository under $1 with two committed files, a and b, and an identity to
# commit as.
turn_repo() {
  local repo
  repo=$(mktemp -d "$1/repo.XXXXXX")
  git -C "$repo" init -q -b main
  git -C "$repo" config user.email t@example.com
  git -C "$repo" config user.name Test
  # The user's own config signs every commit; this identity has no key.
  git -C "$repo" config commit.gpgsign false
  printf 'one\ntwo\n' >"$repo/a"
  printf 'x\n' >"$repo/b"
  git -C "$repo" add a b
  git -C "$repo" commit -qm init
  printf '%s' "$repo"
}

# The codepoint of a string's first character, so a glyph assertion says which
# glyph it means rather than pasting a private-use character no one can read in
# a diff.
codepoint() { printf '%d' "'$1"; }

# shellcheck source-path=SCRIPTDIR source=../scripts/agent-status.sh
source "$plugin/scripts/agent-status.sh"
# agent-status.sh sets -e for its own sake; the runner has to survive a failing
# assertion and report it.
set +e

# Globals the functions under test read off their caller. Undeclared, set -u
# would object to the first one that is not written before it is read.
payload=''
window='@1'
pane='%1'
seq_now=0

section 'oneline: one line, clipped to a budget'
assert_eq 'a short string is itself' 'hello' "$(printf 'hello' | oneline 20)"
assert_eq 'runs of whitespace collapse' 'a b c' "$(printf 'a  \t b\n\nc' | oneline 20)"
assert_eq 'leading and trailing space go' 'a b' "$(printf '  a b  ' | oneline 20)"
assert_eq 'at the budget it is left alone' 'abcde' "$(printf 'abcde' | oneline 5)"
assert_eq 'over it, the tail becomes an ellipsis' 'abcd…' "$(printf 'abcdef' | oneline 5)"
assert_eq 'and no space is left before it' 'abc…' "$(printf 'abc def' | oneline 5)"
assert_eq 'nothing in is nothing out' '' "$(printf '' | oneline 20)"
# The reason for ${#text} over the byte length: a multi-byte character cut in
# half is not a character at all.
clipped=$(printf 'héllo wörld' | oneline 5)
assert_eq 'characters are counted, not bytes' 5 "${#clipped}"
unset clipped
assert_eq 'and an emoji survives the cut whole' '😀😀…' \
  "$(printf '😀😀😀😀' | oneline 3)"

section 'duration: the units a glance can read'
assert_eq 'seconds under a minute' 0s "$(duration 0)"
assert_eq 'still seconds at 59' 59s "$(duration 59)"
assert_eq 'a minute is minutes and seconds' 1m0s "$(duration 60)"
assert_eq '93 seconds' 1m33s "$(duration 93)"
assert_eq 'still minutes at 3599' 59m59s "$(duration 3599)"
assert_eq 'an hour is hours and minutes' 1h0m "$(duration 3600)"
assert_eq '3771 seconds' 1h2m "$(duration 3771)"

section 'format_shortstat: git summary, banner sized'
stat_of() { printf '%s\n' "$1" | format_shortstat; }
assert_eq 'insertions, deletions and files' \
  '🟢+12 🔴-4 · 3 files' \
  "$(stat_of ' 3 files changed, 12 insertions(+), 4 deletions(-)')"
assert_eq 'insertions alone' '🟢+12 · 1 file' \
  "$(stat_of ' 1 file changed, 12 insertions(+)')"
assert_eq 'deletions alone' '🔴-4 · 1 file' \
  "$(stat_of ' 1 file changed, 4 deletions(-)')"
assert_eq 'a clean tree says nothing at all' '' "$(stat_of '')"
unset -f stat_of

section 'turn snapshot: what this turn changed, and nothing before it'
snap_home=$(mktemp -d)
snap=$snap_home/turn

out=$(turn_shortstat "$snap")
status=$?

assert_eq 'with no snapshot there is nothing to say' '' "$out"
assert_eq 'and it says so by failing' 1 "$status"

repo=$(turn_repo "$snap_home")
snapshot_turn "$repo" "$snap"

out=$(turn_shortstat "$snap")
status=$?

assert_eq 'a turn that changed nothing in a clean tree says nothing' '' "$out"
assert_eq 'and that is an answer, not a failure' 0 "$status"

repo=$(turn_repo "$snap_home")
snapshot_turn "$repo" "$snap"

printf 'three\n' >>"$repo/a"

assert_eq 'an edit the turn made to a clean file is counted' \
  ' 1 file changed, 1 insertion(+)' "$(turn_shortstat "$snap")"

repo=$(turn_repo "$snap_home")
printf 'before the turn\n' >>"$repo/a"
snapshot_turn "$repo" "$snap"

out=$(turn_shortstat "$snap")

assert_eq 'what was uncommitted before the turn is not the turn'"'"'s' '' "$out"

repo=$(turn_repo "$snap_home")
printf 'before the turn\n' >>"$repo/a"
snapshot_turn "$repo" "$snap"

printf 'during it\nand again\n' >>"$repo/a"

assert_eq 'an already dirty file the turn edits counts only the turn'"'"'s lines' \
  ' 1 file changed, 2 insertions(+)' "$(turn_shortstat "$snap")"

repo=$(turn_repo "$snap_home")
printf 'staged before the turn\n' >>"$repo/b"
git -C "$repo" add b
snapshot_turn "$repo" "$snap"

out=$(turn_shortstat "$snap")

assert_eq 'nor is what was staged before it' '' "$out"

repo=$(turn_repo "$snap_home")
snapshot_turn "$repo" "$snap"

printf 'new\nfile\n' >"$repo/c"

assert_eq 'a file the turn creates is counted' \
  ' 1 file changed, 2 insertions(+)' "$(turn_shortstat "$snap")"

repo=$(turn_repo "$snap_home")
printf 'left lying around\n' >"$repo/scratch"
snapshot_turn "$repo" "$snap"

out=$(turn_shortstat "$snap")

assert_eq 'an untracked file that was already there is not' '' "$out"

repo=$(turn_repo "$snap_home")
printf 'build/\n' >"$repo/.gitignore"
git -C "$repo" add .gitignore
git -C "$repo" commit -qm ignore
snapshot_turn "$repo" "$snap"

mkdir "$repo/build"
printf 'artefact\n' >"$repo/build/out"

assert_eq 'nor is anything the turn writes where git is told to look away' '' \
  "$(turn_shortstat "$snap")"

repo=$(turn_repo "$snap_home")
snapshot_turn "$repo" "$snap"

rm "$repo/a"

assert_eq 'a file the turn deletes is counted as its lines going' \
  ' 1 file changed, 2 deletions(-)' "$(turn_shortstat "$snap")"

repo=$(turn_repo "$snap_home")
printf 'before the turn\n' >>"$repo/b"
snapshot_turn "$repo" "$snap"

printf 'three\n' >>"$repo/a"
git -C "$repo" commit -qam 'the turn commits'

assert_eq 'what the turn committed is still what the turn did' \
  ' 1 file changed, 1 insertion(+)' "$(turn_shortstat "$snap")"

repo=$(turn_repo "$snap_home")
snapshot_turn "$repo" "$snap"
printf 'the last turn\n' >>"$repo/a"
snapshot_turn "$repo" "$snap"

out=$(turn_shortstat "$snap")

assert_eq 'the next turn starts from where the last one left off' '' "$out"

repo=$(turn_repo "$snap_home")
snapshot_turn "$repo" "$snap"
plain=$(mktemp -d "$snap_home/plain.XXXXXX")
snapshot_turn "$plain" "$snap"

out=$(turn_shortstat "$snap")
status=$?

assert_eq 'a turn outside any repository has nothing to say' '' "$out"
assert_eq 'and is no snapshot at all, not the last one'"'"'s left over' 1 "$status"

repo=$(mktemp -d "$snap_home/unborn.XXXXXX")
git -C "$repo" init -q -b main
out=$(snapshot_turn "$repo" "$snap" 2>&1)
status=$?

printf 'first\n' >"$repo/a"

assert_eq 'a repository with nothing committed yet is snapshotted quietly' '0:' \
  "$status:$out"
assert_eq 'and the first file the turn writes is counted' \
  ' 1 file changed, 1 insertion(+)' "$(turn_shortstat "$snap")"

repo=$(turn_repo "$snap_home")
mkdir "$repo/app"
printf 'app\n' >"$repo/app/main"
git -C "$repo" add app
git -C "$repo" commit -qm app
snapshot_turn "$repo/app" "$snap"

printf 'at the root\n' >"$repo/root"

assert_eq 'an agent started in a subdirectory still answers for the whole repository' \
  ' 1 file changed, 1 insertion(+)' "$(turn_shortstat "$snap")"

repo=$(turn_repo "$snap_home")
worktree=$snap_home/worktree
git -C "$repo" worktree add -q -b story "$worktree"
printf 'before the turn\n' >>"$worktree/b"
snapshot_turn "$worktree" "$snap"

printf 'three\n' >>"$worktree/a"

assert_eq 'a linked worktree, whose .git is a file, answers the same way' \
  ' 1 file changed, 1 insertion(+)' "$(turn_shortstat "$snap" 2>&1)"

repo=$(turn_repo "$snap_home")
printf 'secret\n' >"$repo/locked"
chmod 000 "$repo/locked"
out=$(snapshot_turn "$repo" "$snap" 2>&1)
status=$?
chmod 600 "$repo/locked"

turn=$(turn_shortstat "$snap")
turn_status=$?

assert_eq 'a snapshot git cannot finish is given up quietly' '0:' "$status:$out"
assert_eq 'and leaves no snapshot to be read half taken' ':1' "$turn:$turn_status"
unset turn turn_status

repo=$(turn_repo "$snap_home")
snapshot_turn "$repo" "$snap"
rm -rf "$repo"

out=$(turn_shortstat "$snap" 2>&1)
status=$?

assert_eq 'a repository gone since the turn began is answered quietly' '1:' "$status:$out"

# macOS sweeps its temporary directory of files left untouched for days, one file
# at a time and leaving the directories, so a window idle over a long weekend can
# come back to a snapshot with its stored content gone from under it.
repo=$(turn_repo "$snap_home")
printf 'before the turn\n' >>"$repo/a"
snapshot_turn "$repo" "$snap"
find "$snap/objects" -type f -delete
printf 'during it\n' >>"$repo/a"

out=$(turn_shortstat "$snap" 2>&1)
status=$?

assert_eq 'and so is a snapshot the system has swept' '1:' "$status:$out"

# Every path under .git with its modification time to the nanosecond and its
# size, so a file written, created or merely touched shows up as a difference.
git_state() { find "$1/.git" -exec stat -f '%N %Fm %z' {} + | sort; }

# Staged content is already stored in the repository, so git writing it again
# would find it there -- which is the case where it refreshes the stored copy's
# time rather than writing its own.
repo=$(turn_repo "$snap_home")
printf 'staged\n' >>"$repo/a"
git -C "$repo" add a
printf 'dirty\n' >>"$repo/b"
printf 'loose\n' >"$repo/scratch"
before=$(git_state "$repo")

snapshot_turn "$repo" "$snap"
printf 'turn\n' >>"$repo/a"
printf 'new\n' >"$repo/c"
turn_shortstat "$snap" >/dev/null

assert_eq 'nothing in the repository is written, created or touched' "$before" \
  "$(git_state "$repo")"

# A split index keeps most of its entries in a shared file beside it, and git
# writes a new one of those wherever it writes the index -- which, for the copy,
# would be in the repository. Reading the copy still refreshes the shared file's
# time, so only what exists is compared here, not when it was touched.
repo=$(turn_repo "$snap_home")
git -C "$repo" config core.splitIndex true
git -C "$repo" update-index --split-index
printf 'dirty\n' >>"$repo/a"
# Enough of the index changing that git would rather write a new shared file
# than carry the changes beside the old one.
printf 'loose\n' >"$repo/scratch"
before=$(find "$repo/.git" | sort)

snapshot_turn "$repo" "$snap"
printf 'turn\n' >>"$repo/b"
turn_shortstat "$snap" >/dev/null

assert_eq 'a repository that splits its index gains no file from the snapshot' \
  "$before" "$(find "$repo/.git" | sort)"

# With the built-in file-system monitor on, the first git to read the index
# starts a daemon, and the daemon keeps its socket and cookies in the repository.
repo=$(turn_repo "$snap_home")
git -C "$repo" config core.fsmonitor true
printf 'dirty\n' >>"$repo/a"
before=$(find "$repo/.git" | sort)

snapshot_turn "$repo" "$snap"
printf 'turn\n' >>"$repo/b"
turn_shortstat "$snap" >/dev/null
after=$(find "$repo/.git" | sort)
git -C "$repo" fsmonitor--daemon stop >/dev/null 2>&1

assert_eq 'nor does one that watches its files with a daemon' "$before" "$after"
unset after

rm -rf "$snap_home"
unset -f git_state
unset before snap_home snap repo out status plain worktree

section 'state_style: a glyph and a colour per state'
state_style working
assert_eq 'working is the play glyph' 61515 "$(codepoint "$glyph")"
assert_eq 'in the yellow of an in-flight turn' '#e0af68' "$colour"
state_style waiting
assert_eq 'waiting is the comment glyph' 61557 "$(codepoint "$glyph")"
assert_eq 'in cyan' '#7dcfff' "$colour"
state_style 'done'
assert_eq 'done is the tick' 61452 "$(codepoint "$glyph")"
assert_eq 'in green' '#9ece6a' "$colour"
state_style idle
assert_eq 'idle draws no state glyph at all' '' "$glyph"
assert_eq 'only a dimmed colour for the marker' '#a9b1d6' "$colour"
state_style clear
assert_eq 'a state that names no style is refused' 1 "$?"
state_style wat
assert_eq 'and so is a typo' 1 "$?"

section 'agent_style: which harness this is'
agent_style codex
# The same robot as every other harness: what tells them apart is the colour,
# which is OpenAI's own green.
assert_eq 'codex draws the robot like the rest' 984745 "$(codepoint "$agent_glyph")"
assert_eq 'in OpenAI green' '#10a37f' "$agent_colour"
agent_style claude
assert_eq 'claude takes the default marker' 984745 "$(codepoint "$agent_glyph")"
assert_eq 'in orange' '#ff9e64' "$agent_colour"
assert_eq 'so the glyph alone cannot tell them apart' \
  "$(agent_style codex; printf '%s' "$agent_glyph")" \
  "$(agent_style claude; printf '%s' "$agent_glyph")"
agent_style ''
assert_eq 'so does an unnamed agent' 984745 "$(codepoint "$agent_glyph")"

section 'render_label: what the tab actually shows'
label=$(render_label M '#ff9e64' P '#e0af68')
assert_eq 'marker and glyph, each in its own colour' \
  '#[fg=#ff9e64]M#[fg=#e0af68]  P ' "$label"
assert_eq 'two cells between the glyphs, so they do not touch' 2 \
  "$(awk -F'#\\[fg=#e0af68\\]' '{ match($2, /^ */); print RLENGTH }' <<<"$label")"
assert_match 'and one after, to clear the separator' ' $' "$label"
assert_eq 'an idle label is the marker alone' '#[fg=#a9b1d6]M#[fg=#a9b1d6] ' \
  "$(render_label M '#a9b1d6' '' '#a9b1d6')"

section 'field: one key out of the hook payload'
payload='{"cwd":"/r/x","prompt":"do the thing","n":3}'
assert_eq 'a string field' /r/x "$(field cwd)"
assert_eq 'a field with spaces' 'do the thing' "$(field prompt)"
assert_eq 'a number' 3 "$(field n)"
assert_eq 'a key that is not there' '' "$(field nope)"
payload='not json at all'
assert_eq 'a payload that is not JSON is not an error' '' "$(field cwd)"
payload=''
assert_eq 'and neither is no payload' '' "$(field cwd)"

section 'transcript_reply: the last thing the agent said'
transcript=$(mktemp)
{
  printf '%s\n' 'sion":"abc"}'
  printf '%s\n' '{"type":"user","message":{"content":[{"type":"text","text":"ignore me"}]}}'
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"text","text":"first turn"}]}}'
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"text","text":"let me check\n\nthe answer is 42"}]}}'
} >"$transcript"
assert_eq 'the closing paragraph of the last assistant block' 'the answer is 42' \
  "$(transcript_reply "$transcript")"
: >"$transcript"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"text","text":"   "}]}}' >>"$transcript"
assert_eq 'a block of only whitespace does not count as a reply' '' \
  "$(transcript_reply "$transcript")"
assert_eq 'a transcript that is not there is not an error' '' \
  "$(transcript_reply "$transcript.gone")"
assert_eq 'and neither is no path at all' '' "$(transcript_reply '')"
rm -f "$transcript"

section 'agent_in_window: what is actually running'
panes=''
# shellcheck disable=SC2086  # the panes are separate words, which is the point
tmux() { [[ $1 == list-panes ]] || return 0; printf '%s\n' $panes; }
panes='zsh codex vim'
assert_eq 'codex by name' codex "$(agent_in_window '@1')"
panes='zsh claude'
assert_eq 'claude by name' claude "$(agent_in_window '@1')"
# Claude Code symlinks `claude` at ~/.local/share/claude/versions/<version>, so
# the basename tmux reports is the version rather than a name.
panes='zsh 1.2.34'
assert_eq 'and claude by version number' claude "$(agent_in_window '@1')"
panes='zsh vim less'
assert_eq 'nothing running is empty, not an error' '' "$(agent_in_window '@1')"
panes=''
assert_eq 'a window with no panes says the same' '' "$(agent_in_window '@1')"
unset -f tmux

section 'clear_status: every option, in one invocation'
calls=0
tmux() { calls=$((calls + 1)); printf '%s\n' "$*"; }
seq_now=0
out=$(clear_status; printf 'calls=%d' "$calls")
assert_eq 'one tmux invocation, not ten' 'calls=1' "${out##*$'\n'}"
for opt in @agent_status @agent_status_active @agent_state @agent_state_colour \
  @agent_glyph @agent_glyph_colour @agent_started @agent_prompt @agent_head \
  @agent_cwd; do
  case $out in
    *"-u $opt"*) ok "$opt is unset" ;;
    *) no "$opt is unset" "-u $opt" "$out" ;;
  esac
done
assert_match 'unstamped, the sequence goes too' '\-u @agent_seq' "$out"
seq_now=1700000000123456
out=$(clear_status)
assert_match 'stamped, it survives the wipe' '@agent_seq 1700000000123456' "$out"
assert_eq 'and is not also unset' 0 "$(grep -c -- '-u @agent_seq' <<<"$out")"
seq_now=0
unset -f tmux

section 'add_opt: the writes are chained, not spawned'
set_cmd=()
add_opt @agent_state working
assert_eq 'the first write carries no separator' \
  'set-option -w -t @1 @agent_state working' "${set_cmd[*]}"
add_opt @agent_state_colour '#e0af68'
assert_eq 'the second is chained onto it' \
  'set-option -w -t @1 @agent_state working ; set-option -w -t @1 @agent_state_colour #e0af68' \
  "${set_cmd[*]}"
set_cmd=()

section 'take_lock: detached runs take turns'
TMPDIR=$(mktemp -d)
export TMPDIR
agent_lock=''
take_lock '@1'
assert_eq 'the lock is named after the window' "$TMPDIR/agent-status_1.lock" "$agent_lock"
assert_ok "$([[ -d $agent_lock ]]; echo $?)" 'and it is a real directory'
# A window id is %-prefixed and a session name can hold anything; neither is
# safe in a path.
rmdir "$agent_lock"
take_lock '%12:my session'
assert_eq 'anything that is not a letter or a digit is flattened' \
  "$TMPDIR/agent-status_12_my_session.lock" "$agent_lock"
rmdir "$agent_lock"
# A run killed mid-flight leaves its lock behind. It has to be stealable, or
# the window's status stays wedged for the rest of the session.
stale=$TMPDIR/agent-status_9.lock
mkdir "$stale"
printf '%s' "$((EPOCHSECONDS - 3600))" >"$stale/at"
take_lock '@9'
assert_eq 'an abandoned lock is taken over rather than waited out' "$stale" "$agent_lock"
assert_eq 'and the taker stamps it as its own' "$EPOCHSECONDS" "$(<"$agent_lock/at")"
release_lock
assert_ok "$([[ ! -e $stale ]]; echo $?)" 'releasing it leaves nothing behind'
# A lock that is genuinely held is waited for, not stolen. One try is enough to
# show it gives up rather than taking it; sixty would be three seconds of test.
mkdir "$stale"
printf '%s' "$EPOCHSECONDS" >"$stale/at"
agent_lock=''
lock_tries=1 take_lock '@9'
assert_eq 'a lock still held is left alone' '' "$agent_lock"
assert_ok "$([[ -d $stale ]]; echo $?)" 'and is still there afterwards'
rm -rf "$stale"
trap - EXIT
rm -rf "$TMPDIR"
unset TMPDIR

section 'frontmost_app: what macOS has in front'
lsappinfo() {
  case $1 in
    front) printf '%s\n' "$front_asn" ;;
    info)  printf '"LSDisplayName"="%s"\n' "$front_name" ;;
  esac
}
front_asn='ASN:0x0-0x12345:' front_name=Ghostty
assert_eq 'the name of the frontmost app' Ghostty "$(frontmost_app)"
front_asn=''
assert_eq 'nothing in front is empty, not an error' '' "$(frontmost_app)"
lsappinfo() { return 1; }
assert_eq 'and a machine without lsappinfo says the same' '' "$(frontmost_app)"
unset -f lsappinfo

section 'notify: who gets told, and what the banner says'
# The whole notification path, with what it reaches for stubbed: tmux for the
# window options, git for the commits, the turn's snapshot for what changed,
# date so an elapsed time is reproducible, and terminal-notifier for the banner
# itself. command -v finds a shell function, so the real binary is never
# consulted. The snapshot has sections of its own above, against real
# repositories; here it only has to answer.
declare -A wopt=() gopt=()
notified=''
tmux() {
  local last=${*: -1}
  case $1 in
    show-option)
      case " $* " in
        *' -w '*) printf '%s\n' "${wopt[$last]-}" ;;
        *)        printf '%s\n' "${gopt[$last]-}" ;;
      esac ;;
    display-message) printf '%s\n' "${dm_reply-}" ;;
  esac
}
git() {
  case "$*" in
    *'rev-parse --git-dir'*) return "${git_is_repo:-0}" ;;
    *'cat-file -e'*)         return "${git_knows_head:-0}" ;;
    *'rev-list --count'*)    printf '%s\n' "${git_commits-}" ;;
  esac
}
turn_shortstat() { printf '%s\n' "${turn_stat-}"; }
date() { printf '%s\n' "${fake_now:-1000}"; }
terminal-notifier() { notified=$(printf '%s\n' "$@"); }
osascript() { notified=osascript; }
# The argv terminal-notifier was called with, one word per line: everything
# between a flag and the next one is that flag's value -- which for -message is
# two lines, the reply and what changed.
notified_field() {
  awk -v f="$1" '$0 == f { seen = 1; next } seen && /^-/ { exit } seen { print }' <<<"$notified"
}

state='done' agent=claude pane='%1' window='@1'
notify_off='' win_viewers=0 terminal_apps='' win_name_f=win session_f=sess
payload='' dm_reply='' git_is_repo=0 git_knows_head=0 git_commits='' turn_stat=''
wopt=() gopt=()

notify_off=off
notify finished
assert_eq 'notifications off means nothing is raised' '' "$notified"
notify_off=''

# Suppressed only when a client is showing the window AND the terminal is the
# app in front -- tmux knows the first, lsappinfo the second.
lsappinfo() { case $1 in front) printf 'ASN\n' ;; info) printf '"LSDisplayName"="Ghostty"\n' ;; esac; }
win_viewers=1 terminal_apps=$'Ghostty\niTerm2'
notified=''
notify finished
assert_eq 'the window on screen in the front terminal says nothing' '' "$notified"
terminal_apps=$'iTerm2\nkitty'
notified=''
notify finished
assert_match 'the same window behind a browser still notifies' 'terminal-notifier|-title' \
  "${notified:-terminal-notifier}"
assert_ok "$([[ -n $notified ]]; echo $?)" 'a buried terminal is not "looking at it"'
# No client is showing it at all: there is nothing to look at, so the frontmost
# app is not even consulted.
lsappinfo() { printf 'should not be reached\n'; }
win_viewers=0
notified=''
notify finished
assert_ok "$([[ -n $notified ]]; echo $?)" 'an unwatched window always notifies'
unset -f lsappinfo

section 'notify: a finished turn reports what it did'
state='done' fake_now=1300
wopt=([@agent_started]=1000 [@agent_prompt]='rewrite the parser' [@agent_head]=abc123 [@agent_cwd]=/r/x)
git_commits=2 turn_stat=' 3 files changed, 12 insertions(+), 4 deletions(-)'
payload='{"last_assistant_message":"done, all green"}'
notified=''
notify finished
assert_eq 'the title carries session, agent and elapsed' 'sess · claude · 5m0s' \
  "$(notified_field -title)"
assert_eq 'the subtitle is the prompt that started it' '👤 rewrite the parser' \
  "$(notified_field -subtitle)"
assert_eq 'the body is the reply, then what changed' \
  '🤖 done, all green
2 commits · 🟢+12 🔴-4 · 3 files' "$(notified_field -message)"
assert_eq 'banners for one window replace each other' 'tmux-agent-@1' "$(notified_field -group)"
assert_match 'and clicking one focuses the pane that raised it' \
  'agent-focus\.sh .%1.' "$(notified_field -execute)"
assert_eq 'the done sound, since none is set' Glass "$(notified_field -sound)"

git_commits=1
notified=''
notify finished
assert_match 'one commit is singular' '^1 commit ·' "$(notified_field -message | tail -1)"
git_commits=0 turn_stat=''
notified=''
notify finished
assert_eq 'a turn that changed nothing says only what it said' '🤖 done, all green' \
  "$(notified_field -message)"
git_is_repo=1   # not a repository at all
payload='{}'
notified=''
notify finished
assert_eq 'an agent with nothing to report still finishes' '🤖 finished' \
  "$(notified_field -message)"

# Claude Code sends a transcript instead of the reply.
transcript=$(mktemp)
printf '%s\n' \
  '{"type":"assistant","message":{"content":[{"type":"text","text":"first"}]}}' \
  '{"type":"assistant","message":{"content":[{"type":"text","text":"checking\n\nall tests pass"}]}}' \
  >"$transcript"
payload=$(printf '{"transcript_path":"%s"}' "$transcript")
notified=''
notify finished
assert_eq 'the reply is dug out of the transcript when there is no message' \
  '🤖 all tests pass' "$(notified_field -message)"
rm -f "$transcript"
payload=''

section 'notify: an agent waiting on an answer'
state=waiting
payload='{"message":"may I run the migration?"}'
gopt=([@agent-notify-sound-waiting]=Ping)
notified=''
notify ''
assert_eq 'the body is what it is asking' '💬 may I run the migration?' \
  "$(notified_field -message)"
assert_eq 'with its own sound, so the two are tellable apart unheard' Ping \
  "$(notified_field -sound)"
assert_eq 'and the elapsed time so far' 'sess · claude · 5m0s' "$(notified_field -title)"
payload='{}'
notified=''
notify ''
assert_eq 'a request with no description still says something' \
  '💬 waiting for your input' "$(notified_field -message)"
gopt=([@agent-notify-sound-waiting]=none)
notified=''
notify ''
assert_eq 'a sound of none is silent' '' "$(notified_field -sound)"
assert_ok "$([[ -n $notified ]]; echo $?)" 'but the banner is still raised'

# Without terminal-notifier there is still osascript, which cannot be granted
# notification permission but is better than nothing.
unset -f terminal-notifier
osa_flag=$(mktemp)
osascript() { printf 'osascript' >"$osa_flag"; }
# An empty PATH, because terminal-notifier is installed here and command -v
# would find the real one. The stubs are functions, so they survive it.
(PATH='' notify 'needs you')
assert_eq 'osascript is the fallback' osascript "$(<"$osa_flag")"
rm -f "$osa_flag"
unset -f tmux git date osascript notified_field turn_shortstat
unset wopt gopt notified
state='' payload=''

section 'agent-spinner.sh: the frames and who they are drawn for'
# shellcheck source-path=SCRIPTDIR source=../scripts/agent-spinner.sh
source "$plugin/scripts/agent-spinner.sh"
set +e
assert_eq 'eight frames, so the turn is smooth' 8 "$frame_count"
assert_ok "$(agent_present 'zsh claude vim'; echo $?)" 'claude counts as present'
assert_ok "$(agent_present 'codex'; echo $?)" 'so does codex'
assert_ok "$(agent_present 'zsh 1.2.34'; echo $?)" 'and a version number'
assert_eq 'an ordinary shell does not' 1 "$(agent_present 'zsh vim less'; echo $?)"
assert_eq 'nor does something merely dotted' 1 "$(agent_present 'foo.bar.baz'; echo $?)"
assert_eq 'nor an empty window' 1 "$(agent_present ''; echo $?)"
# The spinner turns in the agent's colour, not the state's: with both harnesses
# drawing the same robot, that colour is the only thing saying which is running.
assert_eq 'the frame turns in the agent colour' \
  '#[fg=#ff9e64]M#[fg=#ff9e64]  F ' "$(frame_label M '#ff9e64' '#e0af68' F)"
assert_eq 'and codex turns in its own' \
  '#[fg=#10a37f]M#[fg=#10a37f]  F ' "$(frame_label M '#10a37f' '#e0af68' F)"
assert_eq 'a marker with no colour of its own falls back to the state colour' \
  '#[fg=#e0af68]M#[fg=#e0af68]  F ' "$(frame_label M '' '#e0af68' F)"

# One tick of the loop, with tmux stubbed and the sleep taken out. The second
# call returns a window that is no longer working, which is how the loop is
# meant to end -- so this also covers the exit condition.
section 'agent-spinner.sh: a tick'
# The tick counter lives in a file, not a variable: list-windows is read
# through a process substitution, so a stub that counted in the shell would
# count in a subshell and the loop would never see its second answer.
ticks=$(mktemp)
spin_log=$(mktemp)
sleep() { :; }
tmux() {
  local n
  case $1 in
    list-windows)
      n=$(<"$ticks"); printf '%s' $((n + 1)) >"$ticks"
      ((n == 0)) && printf '%s\n' "$spin_rows" || printf '%s\n' "$spin_rows_after"
      ;;
    *) printf '%s\n' "$*" >>"$spin_log" ;;
  esac
}
spin_tick() { printf '0' >"$ticks"; : >"$spin_log"; spin; }
spin_rows='@3|working|#e0af68|M|#ff9e64|zsh claude '
spin_rows_after='@3|done|#9ece6a|M|#ff9e64|zsh claude '
spin_tick
spin_writes=$(<"$spin_log")
assert_match 'the working window is repainted' 'set-option -w -t @3 @agent_status ' "$spin_writes"
assert_match 'both the inactive and the active label' \
  '@agent_status_active #\[fg=#ff9e64\]M#\[fg=#ff9e64\]  ' "$spin_writes"
assert_match 'and the bar is told to redraw' 'refresh-client -S' "$spin_writes"
assert_eq 'the writes and the redraw go out together, in one call' 1 \
  "$(grep -c . "$spin_log")"

# A harness killed mid-turn never fires its Stop hook, so the state says
# working while nothing is running. The tick re-derives rather than spinning a
# glyph for an agent that has gone.
fake_dir=$(mktemp -d)
cat >"$fake_dir/agent-status.sh" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$fake_dir/calls"
STUB
chmod +x "$fake_dir/agent-status.sh"
saved_script_dir=$script_dir
script_dir=$fake_dir
spin_rows='@4|working|#e0af68|M|#ff9e64|zsh vim '
spin_rows_after='@4|done|#9ece6a|M|#ff9e64|zsh vim '
spin_tick
assert_eq 'a window whose agent has gone is reconciled' 'reconcile @4' \
  "$(cat "$fake_dir/calls" 2>/dev/null)"
assert_eq 'and nothing is painted for it' '' "$(<"$spin_log")"
script_dir=$saved_script_dir
rm -rf "$fake_dir"

# No windows at all means the server has gone, and the loop must not outlive it.
tmux() { case $1 in list-windows) : ;; *) printf '%s\n' "$*" >>"$spin_log" ;; esac; }
spin
assert_ok $? 'a server that has gone ends the loop rather than looping on it'
rm -f "$ticks" "$spin_log"
unset -f tmux sleep spin_tick

section 'agent-spinner.sh: --ensure-running'
started=''
spinner_pid=''
tmux() {
  case $1 in
    show-option) printf '%s\n' "$spinner_pid" ;;
    set-option) started=$* ;;
  esac
}
# $$ is this shell, which is certainly alive: a spinner is already running.
spinner_pid=$$
ensure_running
assert_eq 'a live spinner is left alone' '' "$started"
unset -f tmux

section 'agent-focus.sh: which terminal is hosting the client'
# shellcheck source-path=SCRIPTDIR source=../scripts/agent-focus.sh
source "$plugin/scripts/agent-focus.sh"
set +e
# tmux's client_pid is the shell, not the terminal, so the app has to be found
# by walking up the process tree.
ps() {
  local want=${*: -1}
  case "$*" in
    *comm=*)
      case $want in
        100) printf '/bin/zsh\n' ;;
        200) printf '/private/var/folders/x/tmux-server\n' ;;
        300) printf '/Applications/Ghostty.app/Contents/MacOS/ghostty\n' ;;
        *) return 1 ;;
      esac ;;
    *ppid=*)
      case $want in
        100) printf '  200\n' ;;
        200) printf '  300\n' ;;
        300) printf '    1\n' ;;
        *) return 1 ;;
      esac ;;
  esac
}
assert_eq 'the app two levels up is the one raised' Ghostty "$(app_from_pid 100)"
assert_eq 'starting from the app itself works too' Ghostty "$(app_from_pid 300)"
assert_eq 'a tree with no bundle in it names nothing' '' "$(app_from_pid 999)"
assert_eq 'and neither does pid 1' '' "$(app_from_pid 1)"
unset -f ps

section 'agent-focus.sh: focusing the pane that asked'
focus_log=$(mktemp)
open_log=$(mktemp)
focus_reset() { : >"$focus_log"; : >"$open_log"; }
tmux() {
  printf '%s\n' "$*" >>"$focus_log"
  case $1 in
    display-message) printf '%s\n' "$focus_session" ;;
    list-clients)
      case "$*" in
        *client_activity*) printf '%s\n' "$focus_clients" ;;
        *client_pid*) printf '%s\n' "$focus_client_pids" ;;
      esac ;;
    show-option) printf '%s\n' "$focus_app_option" ;;
  esac
}
open() { printf '%s\n' "$*" >>"$open_log"; }
ps() {
  local want=${*: -1}
  case "$*" in
    *comm=*) [[ $want == 300 ]] && printf '/Applications/Ghostty.app/Contents/MacOS/ghostty\n' ;;
    *ppid=*) [[ $want == 300 ]] && printf '  1\n' ;;
  esac
}
focus_session=work
focus_clients=$'100 /dev/ttys002\n900 /dev/ttys001'
focus_client_pids=$'/dev/ttys001 300\n/dev/ttys002 400'
focus_app_option=''
focus_reset
(main '%7') >/dev/null 2>&1
focus_calls=$(<"$focus_log")
assert_match 'the client that was used last is the one switched' \
  'switch-client -c /dev/ttys001 -t work' "$focus_calls"
assert_match 'the window is selected by the target it was given' 'select-window -t %7' "$focus_calls"
assert_match 'and so is the pane, which switch-client would not have done' \
  'select-pane -t %7' "$focus_calls"
assert_eq 'the terminal hosting that client is raised' '-a Ghostty' "$(<"$open_log")"

focus_reset
focus_app_option=iTerm2
(main '%7') >/dev/null 2>&1
assert_eq '@agent-notify-app overrides the search' '-a iTerm2' "$(<"$open_log")"

focus_reset
focus_session=''
(main '%7') >/dev/null 2>&1
assert_eq 'a target that has gone switches nothing' 0 \
  "$(grep -c 'switch-client' "$focus_log")"
assert_eq 'and raises nothing' '' "$(<"$open_log")"
assert_match 'but says so in the log' 'target gone: %7' "$(tail -1 "$log")"
rm -f "$focus_log" "$open_log"
unset -f tmux open ps focus_reset

out=$("$plugin/scripts/agent-focus.sh" 2>&1)
assert_eq 'no target at all is a usage error' 1 "$?"
assert_match 'which says what one looks like' 'usage: agent-focus.sh' "$out"

# Notification Center runs this with a PATH that has no Homebrew in it, which
# is how an unqualified tmux went missing in the first place. There is no
# terminal to complain to, so it complains to the log. In a subshell because
# main exits, and after the stubs are gone so `command -v tmux` has nowhere
# left to find one.
(PATH='' main '%7') >/dev/null 2>&1
assert_eq 'a machine with no tmux on PATH still exits cleanly' 0 "$?"
assert_match 'and leaves a reason behind' 'tmux not on PATH' "$(tail -1 "$log")"

section 'agent-status.sh: the states that act on what is there'
# These run the script rather than sourcing it: clear-transient ends in an
# exec, and main exits, so a real process is the only honest way to watch what
# each state does. The commands it reaches for are stubbed as executables on
# PATH, which also covers the paths the sourced tests cannot reach.
stub_dir=$(mktemp -d)
cat >"$stub_dir/tmux" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$STUB_LOG"
last=${*: -1}
case $1 in
  display-message)
    case "$*" in
      *'#{window_id}'*)             printf '%s\n' "${STUB_WINDOW:-@1}" ;;
      *'@nova-status-style-active'*) printf '%s\n' "${STUB_FACTS-}" ;;
      *'@agent-notify-terminals'*)   printf '%s\n' "${STUB_NOTIFY_FACTS-}" ;;
      *) printf '\n' ;;
    esac ;;
  show-option)
    case $last in
      @agent_state) printf '%s\n' "${STUB_STATE-}" ;;
      *) printf '\n' ;;
    esac ;;
  list-panes) printf '%s\n' ${STUB_PANES-} ;;
esac
STUB
cat >"$stub_dir/terminal-notifier" <<'STUB'
#!/usr/bin/env bash
printf 'notified %s\n' "$*" >>"$STUB_LOG"
STUB
chmod +x "$stub_dir/tmux" "$stub_dir/terminal-notifier"

export STUB_LOG=$stub_dir/log
# Exported, not merely set: the stub is a separate process and reads these out
# of its environment.
export STUB_WINDOW='@1' STUB_STATE='' STUB_PANES='' STUB_FACTS='' STUB_NOTIFY_FACTS=''
run_status() {
  : >"$STUB_LOG"
  env PATH="$stub_dir:$PATH" AGENT_STATUS_DETACHED=1 TMUX=/tmp/fake,1,0 \
    "$plugin/scripts/agent-status.sh" "$@" </dev/null >/dev/null 2>&1
}

run_status clear '%1'
assert_eq 'clear unsets every option in one invocation' 1 \
  "$(grep -c '^set-option -w' "$STUB_LOG")"
assert_match 'including the label itself' '\-u @agent_status' "$(cat "$STUB_LOG")"
assert_match 'and asks for a redraw' 'refresh-client -S' "$(cat "$STUB_LOG")"

# An agent that is running but whose state was never written -- a hook lost, or
# a session attached to after the fact.
STUB_STATE='' STUB_PANES='zsh claude' run_status reconcile '%1'
assert_match 'reconcile gives a running agent its idle marker' '@agent_state idle' \
  "$(cat "$STUB_LOG")"
# And the reverse: a state left behind by an agent that has exited.
STUB_STATE=working STUB_PANES='zsh vim' run_status reconcile '%1'
assert_match 'and clears a state whose agent has gone' '\-u @agent_state' "$(cat "$STUB_LOG")"
STUB_STATE=working STUB_PANES='zsh claude' run_status reconcile '%1'
assert_eq 'a state that matches what is running is left alone' 0 \
  "$(grep -c '^set-option -w' "$STUB_LOG")"

# Focus acknowledges the two states that were asking to be looked at.
STUB_STATE='done' STUB_PANES='zsh claude' run_status clear-transient '%1'
assert_match 'focus drops an acknowledged done' '\-u @agent_status' "$(cat "$STUB_LOG")"
STUB_STATE=working STUB_PANES='zsh claude' run_status clear-transient '%1'
assert_eq 'but leaves a turn that is still running' 0 \
  "$(grep -c -- '-u @agent_status' "$STUB_LOG")"
assert_match 'and reconciles on the way past' 'list-panes' "$(cat "$STUB_LOG")"

section 'agent-status.sh: a turn starting and finishing'
STUB_FACTS=$'#c0caf5\x1f/r/x\x1f'
run_status --agent claude working '%1'
log_text=$(cat "$STUB_LOG")
assert_match 'working records when the turn began' '@agent_started [0-9]' "$log_text"
assert_match 'the state, for the format to switch on' '@agent_state working' "$log_text"
assert_match 'the colour, for the spinner to redraw in' '@agent_state_colour #e0af68' "$log_text"
assert_match 'and the label the tab shows' '@agent_status #\[fg=#ff9e64\]' "$log_text"
assert_eq 'all of it in one invocation, not one per option' 1 \
  "$(grep -c '^set-option -w' "$STUB_LOG")"

payload_json='{"prompt":"fix the flake","cwd":"/r/x"}'
: >"$STUB_LOG"
printf '%s' "$payload_json" | env PATH="$stub_dir:$PATH" AGENT_STATUS_DETACHED=1 \
  TMUX=/tmp/fake,1,0 "$plugin/scripts/agent-status.sh" --agent claude working '%1' \
  >/dev/null 2>&1
assert_match 'the prompt comes off the hook payload' '@agent_prompt fix the flake' \
  "$(cat "$STUB_LOG")"

# The stamp is what keeps two detached runs in order: a run that finds a newer
# one already written leaves it alone.
STUB_FACTS=$'#c0caf5\x1f/r/x\x1f9999999999999999'
: >"$STUB_LOG"
env PATH="$stub_dir:$PATH" AGENT_STATUS_DETACHED=1 AGENT_STATUS_SEQ=1 \
  TMUX=/tmp/fake,1,0 "$plugin/scripts/agent-status.sh" --agent claude 'done' '%1' \
  </dev/null >/dev/null 2>&1
assert_eq 'a run overtaken by a newer one writes nothing' 0 \
  "$(grep -c '^set-option -w' "$STUB_LOG")"
STUB_FACTS=$'#c0caf5\x1f/r/x\x1f1'
: >"$STUB_LOG"
env PATH="$stub_dir:$PATH" AGENT_STATUS_DETACHED=1 AGENT_STATUS_SEQ=2 \
  TMUX=/tmp/fake,1,0 "$plugin/scripts/agent-status.sh" --agent claude 'done' '%1' \
  </dev/null >/dev/null 2>&1
assert_match 'while a newer one writes, and leaves its own stamp' '@agent_seq 2' \
  "$(cat "$STUB_LOG")"

# A window nobody is watching gets a banner; the notification path is exercised
# in full above, so this only checks that a finished turn reaches it.
STUB_FACTS=$'#c0caf5\x1f/r/x\x1f' STUB_NOTIFY_FACTS=$'\x1f\x1f0\x1fwin\x1fsess'
run_status --agent claude 'done' '%1'
assert_match 'a finished turn raises a banner' 'notified' "$(cat "$STUB_LOG")"
run_status --agent claude waiting '%1'
assert_match 'and so does one waiting on an answer, saying that is what it wants' \
  'notified .*-message 💬 waiting for your input' "$(cat "$STUB_LOG")"
STUB_NOTIFY_FACTS=$'\x1foff\x1f0\x1fwin\x1fsess'
run_status --agent claude 'done' '%1'
assert_eq 'unless notifications are off' 0 "$(grep -c notified "$STUB_LOG")"

# End to end, against a real repository: what the banner says a turn changed is
# what the turn changed, not whatever was lying uncommitted when it began.
turn_home=$(mktemp -d)
export TMPDIR=$turn_home
repo=$(turn_repo "$turn_home")
printf 'before the turn\n' >>"$repo/a"
STUB_FACTS=$'#c0caf5\x1f'"$repo"$'\x1f' STUB_NOTIFY_FACTS=$'\x1f\x1f0\x1fwin\x1fsess'
# One hook event, with the payload naming the repository the way the harness does.
turn_event() {
  : >"$STUB_LOG"
  printf '{"cwd":"%s"}' "$repo" | env PATH="$stub_dir:$PATH" AGENT_STATUS_DETACHED=1 \
    TMUX=/tmp/fake,1,0 "$plugin/scripts/agent-status.sh" --agent claude "$1" '%1' \
    >/dev/null 2>&1
}

turn_event working
printf 'three\n' >>"$repo/b"
turn_event 'done'

assert_match 'the banner counts the edit the turn made' '🟢\+1 · 1 file' "$(cat "$STUB_LOG")"

turn_event working
turn_event 'done'

assert_match 'a turn that changes nothing in a dirty tree still says it finished' \
  'notified .*-message 🤖 finished' "$(cat "$STUB_LOG")"
assert_eq 'and claims none of what it found uncommitted' 0 "$(grep -c '🟢\|🔴' "$STUB_LOG")"

# Looking at a window that is waiting on an answer clears its tab part way
# through the turn. The turn goes on, and so does what it is measured from.
turn_event working
printf 'four\n' >>"$repo/b"
STUB_STATE=waiting STUB_PANES='zsh claude' turn_event clear-transient
turn_event 'done'

assert_match 'looking at a waiting window mid-turn keeps what the turn is measured from' \
  '🟢\+1 · 1 file' "$(cat "$STUB_LOG")"

turn_event working
turn_event clear

assert_ok "$([[ ! -e $(turn_dir '@1') ]]; echo $?)" \
  'a new session starts with no snapshot left over from the last one'

unset -f turn_event
unset TMPDIR repo
rm -rf "$turn_home"

section 'agent-status.sh: the hook is not made to wait'
# The harnesses allow a hook five seconds and this has more than that to do, so
# the run that matters is the detached one -- everything above forces
# AGENT_STATUS_DETACHED to keep the work in the foreground where it can be
# watched. This is the fork itself: the caller gets its exit straight away, and
# the state lands a moment later.
: >"$STUB_LOG"
start=$SECONDS
printf '%s' '{"prompt":"go"}' | env PATH="$stub_dir:$PATH" TMUX=/tmp/fake,1,0 \
  "$plugin/scripts/agent-status.sh" --agent claude working '%1' >/dev/null 2>&1
assert_eq 'the caller is answered at once' 0 "$?"
assert_ok "$((SECONDS - start < 2 ? 0 : 1))" 'without waiting for any of the work'
for _ in $(seq 1 60); do
  grep -q '^set-option -w' "$STUB_LOG" && break
  sleep 0.05
done
assert_match 'and the state lands behind it' '@agent_state working' "$(cat "$STUB_LOG")"
assert_match 'carrying the payload the pipe had already closed on' '@agent_prompt go' \
  "$(cat "$STUB_LOG")"
assert_match 'stamped, so a slower run cannot overtake it' '@agent_seq [0-9]' \
  "$(cat "$STUB_LOG")"

# That run is still going -- starting the spinner is the last thing it does --
# and taking the stubs out from under it would drop its remaining calls through
# to the real tmux.
for _ in $(seq 1 60); do
  grep -q '@agent_spinner_pid' "$STUB_LOG" && break
  sleep 0.05
done

unset -f run_status
unset STUB_LOG STUB_WINDOW STUB_STATE STUB_PANES STUB_FACTS STUB_NOTIFY_FACTS
rm -rf "$stub_dir"

section 'the entry points'
# AGENT_STATUS_DETACHED, because stdin is a pipe here and a hook's payload
# arrives the same way: without it this forks itself into the background and
# exits 0 before it has looked at its arguments, which is the whole point of
# the detach.
out=$(AGENT_STATUS_DETACHED=1 "$plugin/scripts/agent-status.sh" </dev/null 2>&1)
assert_eq 'no arguments exits 1' 1 "$?"
assert_match 'usage names every state' \
  'working.*waiting.*done.*idle.*clear.*clear-transient.*reconcile' "$out"
literal=0; [[ $out != *'\n'* ]] || literal=1
assert_ok "$literal" 'usage has no literal backslash-n' 'a real newline' "$out"

# Called from a shell with no tmux around it -- which is what a hook does on a
# machine where tmux is not running -- it has to say nothing and succeed.
out=$(env -u TMUX -u TMUX_PANE AGENT_STATUS_DETACHED=1 \
  "$plugin/scripts/agent-status.sh" working </dev/null 2>&1)
assert_eq 'outside tmux it exits quietly' 0 "$?"
assert_eq 'and prints nothing' '' "$out"

out=$(env -u TMUX -u TMUX_PANE AGENT_STATUS_DETACHED=1 \
  "$plugin/bin/agent-status" --agent claude working </dev/null 2>&1)
assert_eq 'the command on PATH does the same' 0 "$?"
assert_eq 'saying nothing as well' '' "$out"
out=$(env -u TMUX AGENT_STATUS_DETACHED=1 "$plugin/bin/agent-status" </dev/null 2>&1)
assert_eq 'and refuses no arguments the same way' 1 "$?"
assert_match 'with the same usage' 'working.*waiting.*done' "$out"

# It is reached through a link on PATH nearly always, and a link is where a
# script that works out its own directory goes wrong: dirname on the link gives
# the directory the link is in, not the one it points at.
link_dir=$(mktemp -d)
ln -s "$plugin/bin/agent-status" "$link_dir/agent-status"
out=$(env -u TMUX AGENT_STATUS_DETACHED=1 "$link_dir/agent-status" </dev/null 2>&1)
assert_eq 'called through a symlink it still finds its own scripts' 1 "$?"
assert_match 'and answers with the usage rather than a missing file' 'working.*waiting' "$out"
rm -rf "$link_dir"

# A link can name its target relative to where the link is, and can name another
# link. Both are followed: the relative hop from the link's own directory, not
# from wherever the caller happens to be.
link_dir=$(mktemp -d)
ln -s "$plugin/bin/agent-status" "$link_dir/absolute"
ln -s absolute "$link_dir/agent-status"
out=$(cd / && env -u TMUX AGENT_STATUS_DETACHED=1 "$link_dir/agent-status" </dev/null 2>&1)
assert_eq 'a chain of links, the first of them relative, is followed to the end' 1 "$?"
assert_match 'and still ends at the usage' 'working.*waiting' "$out"
rm -rf "$link_dir"

# The entry point tmux loads. It must set the plugin's hooks and nothing else,
# and it must leave a hook the user already had alone.
hsock=agent-status-hooks-$$
if ! tmux -L "$hsock" -f /dev/null new-session -d 2>/dev/null; then
  no 'a throwaway tmux server could be started' 'a server' 'none'
else
  tmux -L "$hsock" set-hook -g after-select-window 'run-shell -b "mine"'
  TMUX=$(tmux -L "$hsock" display-message -p '#{socket_path},0,0') \
    "$plugin/agent-status.tmux"
  hooks=$(tmux -L "$hsock" show-hooks -g)
  assert_match 'clear-transient is bound to selecting a window' \
    'after-select-window\[50\].*agent-status.sh clear-transient' "$hooks"
  assert_match 'and to selecting a pane inside one' \
    'after-select-pane\[50\].*agent-status.sh clear-transient' "$hooks"
  assert_match 'reconcile is bound to attaching' \
    'client-attached\[50\].*agent-status.sh reconcile' "$hooks"
  assert_match 'and to switching session' \
    'client-session-changed\[50\].*agent-status.sh reconcile' "$hooks"
  assert_match 'every one of them is backgrounded' 'run-shell -b' "$hooks"
  assert_match 'a hook the user already had is left where it was' \
    'after-select-window\[0\] run-shell -b mine' "$hooks"
  # Reloading the configuration re-runs this file; it must not stack a second
  # copy of each hook.
  TMUX=$(tmux -L "$hsock" display-message -p '#{socket_path},0,0') \
    "$plugin/agent-status.tmux"
  assert_eq 'and a reload replaces its own hooks rather than adding to them' 1 \
    "$(tmux -L "$hsock" show-hooks -g | grep -c 'after-select-window\[50\]')"
  tmux -L "$hsock" kill-server 2>/dev/null
fi
# kill-server does not always take the socket file with it, so it is taken here.
/bin/rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$hsock"
# One socket file a run: 157 of them had built up beside the real server's.
assert_ok "$([[ ! -e ${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$hsock ]]; echo $?)" \
  'the throwaway server leaves no socket behind'

printf '\n\e[1m%s\e[0m  \e[32m%d passed\e[0m' 'total' "$passed"
if ((failed)); then
  printf '  \e[31m%d failed\e[0m\n' "$failed"
  exit 1
fi
printf '\n'
