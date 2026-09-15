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
Once anything is queued a one-column strip appears beside the diff, marking
every line that carries a comment; `C` widens it to read them and narrows it
again, and `R` throws the queue away. `j`/`k` in that pane step the queue,
scrolling the diff to each comment and marking the one being read with a
speech balloon while the rest give way.

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

The comments pane is split off the right of the diff, and the cells it takes
are held back before delta runs rather than taken from the diff when it opens.
A pane narrowed below the width its content was rendered at folds every full
row onto a second line, and rows are what the whole plugin follows the reader
by. Ordinary wrapping is at least reversible; a row that exactly filled the
pane when it was written is not, because tmux cannot tell it from a row that
wrapped, and widening the pane joins it to the row below for good. So the
reserve is spent whether or not the pane is ever shown, as a strip of unused
cells at the right of the diff, and delta renders one column narrower again so
that no row ever sits flush against the edge. Those cells are what the column
widens into, so expanding and narrowing it only ever moves a border between two
panes that were both already paid for. On a narrow window there is nothing to
spare and the column is not offered at all.

Several comments can land on one row -- two notes about one line, or two that
could only be anchored as far as the same file header. The row shows the one
being read, or the first of them, and says which of how many it is; `j` and `k`
step between them there as they do anywhere else, so none is unreachable and
none is hidden from a queue that still holds it.

Splitting the column off the diff, and widening it, both resize the diff --
and tmux repositions a pane's copy-mode when the pane is resized, putting the
cursor on the top row and sliding the view under it. So the sidebar puts the
view back on the turn after any of its own resizes: writing the first comment
brings the marks up without the diff moving out from under the reader, and `C`
leaves them reading the same rows they were.

While the column is up the sidebar asks the server for the diff's position
rather than waiting to be told. A `refresh-client -B` subscription is
re-evaluated about once a second, which is fine for everything that follows the
reader's own keys -- those paint before the answer comes back -- but the marks
follow a scroll they do not drive, and a mark that arrives a second late has
visibly come loose from its line. The question goes down the control client
that is already attached, so it costs no process: 0.4ms against 5ms for a tmux
client of its own, and a scroll is followed in about five milliseconds instead
of a thousand.

Nothing is stored about where a comment sits. The queue keeps the commit, the
file and the line, and the row is worked out again each time from the diff on
screen -- which is what lets comments written in one review anchor in the next,
after a rebase has moved every one of them. Where the line number alone is
ambiguous, as it is between a removed line 10 and an added line 10, the quoted
text decides.

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
| `C`       | widen the comments column to read it, and narrow it again |
| `R`       | discard the whole queue, after asking                     |
| `a`       | choose which agent the comments go to                     |
| `s`       | send everything queued to that agent                      |
| `q`       | close the review, back to where it was opened from        |

`C` and `R` are only listed once something is queued, because until then there
is nothing to widen or to throw away. The column appears on its own when the
first comment is written and goes when the queue empties -- whether that is `s`
sending it or `R` discarding it. `R` asks first: the queue is keyed by the
repository and the range rather than by the window, so reopening the review
will not bring it back.

On the commit list: `j`/`k` step commits, `PgUp`/`PgDn` a page, `gg`/`G` the
ends, and `c`/`s`/`a`/`q` mean what they do in the diff.

The header is a pane, so it is reached the way any pane is — `prefix + k` from
the list. The list cannot be walked up out of into it: `k` on the first commit
means the first commit, wherever the reader has been.

| Key       | On the header pane                                        |
|-----------|-----------------------------------------------------------|
| `j` / `k` | the agent row / the range row                             |
| `enter`   | open that row's picker, in the list pane, and follow it   |
| `R`       | discard the queue, as it does anywhere else               |
| `q`       | close the review                                          |

The comments pane is reached the same way -- `prefix + l` from the diff. It
answers nothing itself: every key is handed to the list, which is where the
queue is. `j` and `k` mean the next and previous comment while the reader is
over there, and step the diff to it; everything else means what it does
anywhere else.

| Key       | On the comments pane                                      |
|-----------|-----------------------------------------------------------|
| `j` / `k` | the next / previous comment, scrolling the diff to it     |
| `C`       | narrow it back to the marks                               |
| `c` `s` `R` `q` | what they do everywhere else                        |

`s` hands the queue to the chosen agent and brings that window forward with it —
the comments are pasted, not run, so the agent is left with the prompt on its
input line to be read before it goes.

## Requirements

- tmux 3.2 or newer (`display-popup`, user options in formats)
- bash 4.3 or newer — the macOS system bash is 3.2, so `brew install bash`
- git, and [delta](https://github.com/dandavison/delta) for the diff itself
- a Nerd Font, for the file and commit glyphs delta and the list draw
- a `history-limit` larger than the diff runs to. The commit list is built by
  finding each commit's header in the diff pane's scrollback, so a range whose
  rendered diff is longer than the scrollback holds loses the headers off the
  top and the list never leaves its placeholder. tmux's own default of 2000 is
  short for this; 50000 is not.

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

The widths, the height of the header pane, the width reserved for the comments
pane and the colours are in `scripts/variables.sh` rather than being options.
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
