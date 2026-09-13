# tmux-review

Read a branch's diff in tmux, with the commit list beside it.

`prefix + g` splits a new window: delta's side-by-side diff of the range on the
right, a narrow commit list on the left. The list highlights whichever commit
the diff cursor is sitting in, so scrolling the diff moves the list with you and
`j`/`k` on the list scrolls the diff to that commit. `c` writes a comment about
the line — or the visual selection — under the cursor, and `s` hands everything
queued to a coding agent running in another window.

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

On the commit list: `j`/`k` step commits, `enter` picks the range to review,
`c`/`s`/`a` and `q` mean what they do in the diff.

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

The widths and colours are in `scripts/variables.sh` rather than being options.
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
