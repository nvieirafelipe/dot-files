# tmux-agent-status

What the coding agent in each tmux window is doing, in the window's own tab.

Several agents run at once across windows, and nothing said which were working,
which were waiting on an answer, and which had finished. The tab says so now: a
marker for the harness, a glyph for the state, a spinner while a turn is in
flight, and a desktop notification when one finishes or needs you — carrying the
prompt, the reply, how long the turn took and what changed in the repository.
Clicking the banner jumps to the pane that raised it.

| State     | Tab shows                    | Set by                                  |
|-----------|------------------------------|-----------------------------------------|
| `working` | a spinner, in yellow         | the harness, when a turn starts          |
| `waiting` | a speech bubble, in cyan     | the harness, when it needs an answer     |
| `done`    | a tick, in green             | the harness, when the turn ends          |
| `idle`    | the harness marker, dimmed   | reconcile, for an agent between turns    |
| `clear`   | nothing                      | the harness, at session start and end    |

Claude Code and Codex both draw the robot -- it is what an agent is -- and are
told apart by colour: Codex in OpenAI's green, Claude in orange. The spinner
turns in that same colour rather than the state's, since a frame that is moving
already says the turn is in flight, so the whole label names the harness and two
of them side by side are distinguishable at a glance.

## How it is wired

The plugin writes window options; the status format reads them. Nothing here
draws the bar, because where the label goes is the bar's business:

    @agent_state          the bare state name, for the format to switch on
    @agent_state_colour   the state's colour, for the spinner to redraw in
    @agent_glyph          the harness marker
    @agent_status         the label for an inactive tab
    @agent_status_active  the label for the active tab, whose background differs

Paste the label into whatever draws your windows. With tmux-nova:

    set -g @nova-pane '#I  #W#{?@agent_state, #{?window_active,#{@agent_status_active},#{@agent_status}},}'

The agent's own lifecycle hooks call `bin/agent-status`, which is what actually
sets those options. For Claude Code, in `~/.claude/settings.json`:

    "UserPromptSubmit": [{ "hooks": [{ "type": "command",
      "command": "~/.local/bin/agent-status --agent claude working 2>/dev/null || true" }]}]

and the same for `Notification` → `waiting`, `Stop` → `done`, `SessionStart` →
`clear`. Codex takes the same commands in `~/.codex/hooks.json`, with
`PermissionRequest` in place of `Notification`.

The plugin's own entry point binds four tmux hooks: selecting a window or a pane
drops a `waiting` or `done` glyph that has now been looked at, and attaching or
switching session re-derives any state that has drifted. State is only ever
written by events, so a lost event or an agent killed mid-turn would otherwise
leave a tab wrong until its next prompt.

## Requirements

- tmux 3.2 or newer (user options in formats, hook arrays)
- bash 5 or newer — the macOS system bash is 3.2, so `brew install bash`
- `jq`, for the hook payloads
- macOS, for the notifications: `terminal-notifier` if it is installed,
  `osascript` otherwise
- a Nerd Font, for the harness and state glyphs

## Install

With [tpm](https://github.com/tmux-plugins/tpm):

    set -g @plugin '<user>/tmux-agent-status'

Or clone it and run the entry point yourself:

    run '~/.tmux/plugins/tmux-agent-status/agent-status.tmux'

Then link `bin/agent-status` onto `PATH` — the hook configurations call it by
name — and copy `sounds/*.aiff` into `~/Library/Sounds` if you want the bell.

## Options

    set -g @agent-notify off              # no banners at all
    set -g @agent-notify-sound-done       'Glass'
    set -g @agent-notify-sound-waiting    'Ping'   # 'none' for silence
    set -g @agent-notify-terminals        'iTerm2,Ghostty'
    set -g @agent-notify-app              'Ghostty'

`@agent-notify-terminals` is what counts as "you can see the terminal": a banner
is suppressed only when a client is showing that window *and* one of these apps
is in front. `@agent-notify-app` names the app a click should raise, when
finding it gets the wrong answer. Without it, the click walks up from the tmux
client to the first `.app` bundle and, failing that, raises the bundle id the
client inherited in `__CFBundleIdentifier` — iTerm2 runs its shells under a
daemon outside its bundle, so the walk alone never finds it.

The glyphs, colours and limits are in `scripts/variables.sh` rather than being
options. Every option read is a round trip to the server, and this runs on a
hook the harness allows five seconds.

## Why it is shaped the way it is

The hard part was cost, not state. Both harnesses kill a hook after five
seconds, and this was taking six to twelve — so the hook was killed part way and
the status never landed.

Only the payload is read in the foreground, because it arrives on a pipe the
caller closes the moment the hook returns; everything after that re-runs
detached and the hook returns at once. Detaching costs the ordering the harness
gave by waiting, so each run carries its caller's timestamp and refuses to write
over a newer one, under a per-window lock.

Every write goes out as one chained `tmux` invocation rather than one call per
option: a process costs tens of milliseconds here, and there were forty-two of
them. The spinner pushes frames with `refresh-client -S` rather than being
polled, because `#()` jobs only re-run once per `status-interval`.

What a finished turn changed is measured from the working tree as the turn found
it, not from `HEAD`. Against `HEAD`, whatever was already uncommitted when the
prompt went in was reported as the turn's own work, including by turns that
changed nothing. So `working` takes a snapshot, and `done` diffs the working
tree against it: everything the turn did, committed or not, including files it
created, and nothing from before. The snapshot is git's own staging pointed at
`$TMPDIR`: a copy of the index and an object store of its own. The repository
is never written. It costs about 60ms when a turn starts, off the agent's path,
and about 45ms before the banner.

## Tests

    ./run_tests
    ./run_coverage --missing

They stub `tmux`, `git`, `ps` and `terminal-notifier` — as shell functions where
the script is sourced, and as executables on `PATH` where it has to be run for
real — and source the three scripts, each of which dispatches only when run and
not when sourced. The turn snapshot is the exception: it runs against real
throwaway repositories, because the thing it must never do is write to one.

Coverage is every line, and `tmux/check.sh` fails below it. `run_coverage`
counts a command that runs over several lines once, as reached when bash names
any of its lines, because xtrace names only one: the first for the `awk` and
`jq` programs, the last for a `$( )` continued with a backslash.
