# tmux-review

Read a branch's diff in tmux, with the commit list beside it.

`prefix + g` splits a new window: delta's side-by-side diff of the range on the
right, a narrow commit list on the left, and above the list a four-row pane
naming what is being reviewed — the range, the agent a comment would go to, and
the commits, churn and totals the range comes to. The list highlights
whichever commit the diff cursor is sitting in, so scrolling the diff moves the
list with you and `j`/`k` on the list scrolls the diff to that commit. `c`
writes a comment about the line — or the visual selection — under the cursor,
and `s` hands everything queued to a coding agent running in another window.

```
 origin/master..HEAD
 󰚩  claude · shell-startup-perf

 ████████░░  +2143 -742  12 commits
```

The header is a pane rather than rows of the list because it never scrolls: a
long review can be paged through without losing sight of what is being reviewed
or where the comments are going. The sidebar paints it through its tty, since
everything it shows is state the sidebar's own loop holds; the process living
there owns one thing only, which is the row its own cursor is on.

Comments that were never sent are not lost with the window. The queue is keyed
by the repository and the range, not by the window it was written in, and lives
in `$TMPDIR/tmux-review/` — so closing a review and opening the same one again
picks the queue back up, and anything abandoned for good is swept by the
system's own temp cleanup rather than kept forever or left in the repo.

The diff is dumped into the pane's own scrollback and read with copy-mode rather
than piped through a pager. A pager is a full-screen application, so tmux cannot
see where inside it the reader is; scrollback exposes `#{scroll_position}` and
`#{copy_cursor_y}`, which is what lets the list follow the diff at all.

## Keys

In any pane:

| Key            | Does                                                 |
|----------------|------------------------------------------------------|
| `prefix + g`   | review this branch's commits beside the diff         |
| `prefix + G`   | the uncommitted working tree, in a popup             |

In the diff, which is always in copy-mode:

| Key       | Does                                                      |
|-----------|-----------------------------------------------------------|
| `n` / `N` | next / previous stop point — or search match, after `/`    |
| `]` / `[` | next / previous file                                      |
| `}` / `{` | next / previous commit                                    |
| `c`       | comment on the line, or on the visual selection           |
| `a`       | choose which agent the comments go to                     |
| `s`       | send everything queued to that agent                      |
| `q`       | close the review, back to where it was opened from        |

On the commit list: `j`/`k` step commits, `PgUp`/`PgDn` a page, `gg`/`G` the
ends, and `c`/`s`/`a`/`q` mean what they do in the diff.

The header is a pane, so it is reached the way any pane is — `prefix + k` from
the list. The list cannot be walked up out of into it: `k` on the first commit
means the first commit, wherever the reader has been.

| Key       | On the header pane                                        |
|-----------|-----------------------------------------------------------|
| `j` / `k` | the agent row / the range row                             |
| `enter`   | open that row's picker, in the list pane, and follow it   |
| `q`       | close the review                                          |

`s` hands the queue to the chosen agent and brings that window forward with it —
the comments are pasted, not run, so the agent is left with the prompt on its
input line to be read before it goes.

## Requirements

- tmux 3.2 or newer (`display-popup`, user options in formats)
- bash 4.3 or newer — the macOS system bash is 3.2, so `brew install bash`
- git, and [delta](https://github.com/dandavison/delta) for the diff itself
- a Nerd Font, for the file and commit glyphs delta and the list draw

## Install

With [tpm](https://github.com/tmux-plugins/tpm), listed **last** so its
copy-mode bindings are not overwritten as the other plugins load:

    set -g @plugin 'tmux-plugins/tmux-yank'
    set -g @plugin '<user>/tmux-review'

Or clone it and run the entry point yourself, again after any other plugin:

    run '~/.tmux/plugins/tmux-review/review.tmux'

`bin/git-review` is a standalone command as well: git treats any `git-*` on
`PATH` as a subcommand, so linking it there gives you `git review` in a terminal
with no tmux involved.

## Options

    set -g @review-key 'g'        # opens a review
    set -g @review-wip-key 'G'    # opens the working tree in a popup

The widths, the height of the header pane and the colours are in
`scripts/variables.sh` rather than being options.
Every option read is a round trip to the server, and this plugin is built around
not making them: the sidebar takes a share of the window worked out in
arithmetic, so that neither pane has to wait on the other to learn how wide to
draw.

## Tests

    ./run_tests

They stub `tmux` and `git` as shell functions and source `scripts/review.sh`,
which dispatches only when run and not when sourced. A smoke test at the end
opens a real review on a throwaway server.

## Tracing

Set `REVIEW_TRACE` to a file and open a review to see where the time goes:

    tmux set-environment -g REVIEW_TRACE /tmp/review.trace

    awk '$2=="diff-start"{t=$1; n++; printf "\n--- review %d ---\n", n}
         {printf "%7.2fs  %s\n", $1-t, $2}' /tmp/review.trace

The file is appended to, so it holds every review the server has opened; each
block is measured from its own `diff-start`.
