# dotfiles

Terminal setup: tmux, git, neovim, Ghostty and iTerm2, on Tokyo Night Storm.

Two things here are more than configuration and have their own docs below: a
git review workflow that runs inside tmux, and an agent status indicator that
shows what Claude Code or Codex is doing in the tmux tab name.

## Install on a new machine

```sh
git clone git@github.com:nvieirafelipe/dot-files.git ~/Developer/dot-files
cd ~/Developer/dot-files
brew bundle          # or let install.sh do it
./install.sh
```

`install.sh` is idempotent -- safe to re-run. It installs the Brewfile, links
this repo into place, copies the notification sounds and the delta syntax theme,
and installs the tmux plugins through TPM. It prints what it linked and what is
left to do by hand:

- **iTerm2** -- Settings > Profiles, select "Tokyo Night Storm (dotfiles)", set as default
- **Codex** -- run `/hooks` and trust the entries under User config
- **tmux** -- `tmux source-file ~/.tmux.conf`

## Reviewing code

`git review` prints the diff of whatever is outstanding, on any branch. It
resolves the base from `origin/HEAD`, so the same command means "the commits
this branch has that the base does not" on a feature branch and "everything
unpushed" on the base branch itself.

```sh
git review              # outstanding commits
git review 3            # the last three
git review main         # since a base -- any rev
git review a1b2..c3d4   # an explicit range
git review --wip        # uncommitted
git review --staged     # staged
git review --stash 'stash@{0}'
```

`glogp` is `git review`, `glogw` is `git review --wip`.

### The review window

`prefix + g` opens a two-pane window: the commit list on the left, the diff on
the right. The tab appears at once, with a placeholder, and the diff is revealed
when it has finished rendering.

The list follows the diff. Whichever commit the diff cursor is inside is the one
highlighted, so there is only ever one idea of where the reader is.

| key | in the diff | in the list |
| --- | --- | --- |
| `n` / `N` | next/previous stop, file or commit | same |
| `]` / `[` | next/previous file | same |
| `}` / `{` | next/previous commit | -- |
| `j` / `k` | a line | a commit |
| `PgUp` / `PgDn` | a page of the diff | a page of commits |
| `gg` / `G` | -- | first/last commit |
| `enter` | -- | the picker, from the range line |
| `q` | close the window | close the window |

`prefix + h` and `prefix + l` move between the two panes. Focusing the list
parks the diff cursor at the top of its view, so a jump from there lands its
header at the top of the pane. The legend at the bottom lists the keys of
whichever pane has the focus.

### Reviewing something else

Moving up off the first commit selects the range line -- the one thing on screen
that names what is being reviewed. `enter` there, and only there, offers
everything else that can be reviewed:

```
 review
 enter chooses, esc goes back
 ─────────────────────────────────────────────
 outstanding                      base..HEAD
 last n commits                   asks
 a range                          asks
 ─────────────────────────────────────────────
 uncommitted                      working tree
 staged                           index
 ─────────────────────────────────────────────
 master                           since
 split-backup                     since
 ─────────────────────────────────────────────
 stash@{0}                        WIP on master: …
```

`j` goes back to the first commit. Branches and stashes are read when the picker
is opened, so they are current even under a long-lived review. Choosing a commit range replaces the window and
keeps the window `q` returns to. Choosing the working tree, the index or a stash
opens a popup instead -- none of them has commits to list, so a sidebar would
have nothing to show.

`prefix + G` shows uncommitted work in a popup instead -- there are no commits
to list, so there is nothing for a sidebar to do.

`prefix + Space` then `g` reaches the same things from the which-key menu,
including `j` for a submenu of the jumps.

### How the diff is displayed

The diff does not go through `less`. `less` is a full-screen application, so
tmux cannot see where inside it the reader is. It is written into the pane's own
scrollback and scrolled with copy-mode instead, which exposes
`#{scroll_position}` and `#{copy_cursor_y}` -- and that is what lets the list
highlight the right commit rather than guess at one.

The cost of that is delta's `navigate`, which implements `n`/`N` by handing
`less` a search pattern. `n`, `N`, `]`, `[`, `}` and `{` replace it.

## Agent status

The tmux tab name shows what an agent in that window is doing: a robot glyph
for the harness, a spinner while it works, a question mark while it waits for
input, a tick when it finishes. Claude Code drives it through
`~/.claude/settings.json` hooks and Codex through `~/.codex/hooks.json`.

A finished turn also raises a desktop notification carrying the prompt, the
reply, how long the turn took and the git delta. Clicking it focuses the pane
the agent is in.

It is a plugin of its own, `tmux-agent-status/`, with its own README, options
and tests — the only parts that stay here are the two lines of `.tmux.conf` that
say which sounds to use, and the nova window format that says where the label
goes.

## Development

```sh
tmux/check.sh                     # shellcheck, bash -n, then the tests
tmux-review/run_tests             # the review plugin's tests alone
tmux-agent-status/run_tests       # the agent status plugin's tests alone
tmux/rebuild-which-key.sh         # after editing tmux/which-key.yaml
```

`tmux/check.sh` covers every script in the repo and exits non-zero if any step
fails, including when one of the tools it needs cannot run.

The which-key menu is generated from `tmux/which-key.yaml`, and the plugin's own
rebuild-on-every-load is off -- it costs 1.4s of each tmux start for a file that
changes only when the yaml does. Run `tmux/rebuild-which-key.sh` after editing
it, then `prefix + R`.

Each plugin has its own suite and its own `run_coverage`, and both sit around
92% of the lines their scripts can reach. The review tests cover the range
`git-review` resolves, the widths the sidebar settles on, how a row is laid out,
which commit sits under the cursor, what a keypress resolves to, and what the
renderers put on screen. The agent status tests cover what each state writes,
which turn wins when two land at once, what a notification says, and what the
spinner does with a window whose agent has gone.

Every script in both dispatches only when run, not when sourced, which is what
lets the tests reach the functions inside them.
