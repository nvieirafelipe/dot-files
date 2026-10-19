# Implement Phase Details

## Verify after each step

After completing each step, run verification before moving on:

```bash
mix compile --warnings-as-errors && \
mix format --check-formatted && \
mix dialyzer && \
mix credo --strict && \
mix test <relevant_test_files>
```

Do NOT proceed to the next step until the current one passes.

## 3-strike failure protocol

Never repeat the exact same failing action. Escalate:

1. **Diagnose and fix** — read the error, identify root cause,
   apply targeted fix. Log error and attempt in the worklog.
2. **Alternative approach** — different method, different data
   flow, different test setup. Mutate, don't retry.
3. **Broader rethink** — question assumptions, re-read the
   plan, search for similar patterns in the codebase.

**After 3 strikes** — write a diagnostic to the worklog
(error, all 3 attempts, root cause hypothesis) and ask the
user for guidance.

## Commit after each step

After a step passes verification, mark it done in `plan.md`
(`- [ ]` → `- [x]`), then commit the changes as a
logical unit. Each commit should contain only the code related
to that step and must pass compilation, tests, and formatting
on its own.

Stage files deliberately — group related changes and avoid
mixing unrelated work in a single commit.

Commit message format:
```
{High-level explanation of what the change accomplishes}
```

Do NOT prefix commits with the issue number (e.g.
`issue-NN`). The issue number is already in the branch name
and will appear in the final squash-merge commit. Individual
commits should only describe what they do.

Keep it concise and focused on the "why", not a list of files.
If a step touches multiple concerns (e.g. migration + context
+ tests), they belong in one commit as one logical change.

### Link commits to Deciduous

After each commit, if `deciduous` is on PATH and the project
has a `.deciduous/` directory, link the work to the decision
graph:

```bash
deciduous add action "{step description}" -c 90 --commit HEAD
```

Then link the action to the current Goal:

```bash
deciduous nodes -t goal | tail -1
deciduous link <goal_id> <action_id> -r "{why this step}"
```

Record the result as an outcome linked from the action, and
mark both completed:

```bash
deciduous add outcome "{result}" -c 90 --commit HEAD
deciduous link <action_id> <outcome_id> -r "{result of this step}"
deciduous status <action_id> completed
deciduous status <outcome_id> completed
```

This connects implementation work to the decisions that
drove it. In server mode the calls reach the server before
each command exits; in git mode, run `deciduous sync` and
commit `.deciduous/graph.json` by path. Skip silently if
`deciduous` is not available.

## Rebase before PR

Before moving to the PR phase, review the commit history.
**Show the user the current commit log and your proposed
rebase plan before executing.** Include:

- Which commits will be squashed
- The proposed final commit order
- The rebase command(s) to run

Wait for explicit approval before running `git rebase`.

Reorganize commits into a logical order that makes the PR
easier to review. Squash fixups, reorder steps if a different
sequence tells a clearer story, and ensure every commit in
the final history passes tests independently.

### Backup ref before any history rewrite (MANDATORY)

Every rewrite gets an escape hatch created BEFORE it runs.
This covers `git rebase` (interactive or not), `git commit
--amend`, `--fixup` + autosquash, `git reset --hard`, and
`git filter-*`. Reflog recovery works but costs a detour;
a named ref costs one command.

```bash
BASE_BRANCH="origin/master"   # or the PR's base branch

# --git-common-dir points at the MAIN repo's .git from inside a worktree too,
# which --show-toplevel does not. The snippets live in the main checkout.
MAIN_ROOT="$(cd "$(git rev-parse --git-common-dir)/.." && pwd)"
SNIPPETS_DIR="$MAIN_ROOT/.snippets/$ISSUE"

git branch "backup/$(git rev-parse --abbrev-ref HEAD)-$(date +%s)"
git log --oneline "$BASE_BRANCH"..HEAD >| "$SNIPPETS_DIR/pre-rewrite-log.txt"
git diff "$BASE_BRANCH"...HEAD >| "$SNIPPETS_DIR/pre-rewrite.diff"
```

Write the log and diff into the story's `.snippets/` directory
in the **main repo**, never `/tmp` and never a session
scratchpad. `/tmp` collides when two sessions rebase at once,
which happens; a scratchpad can be cleared between turns, and a
backup that disappears is not a backup.

After the rewrite, prove it changed only the history and not
the tree:

```bash
git diff "$BASE_BRANCH"...HEAD >| "$SNIPPETS_DIR/post-rewrite.diff"
diff "$SNIPPETS_DIR/pre-rewrite.diff" "$SNIPPETS_DIR/post-rewrite.diff" \
  && echo "tree identical"
```

An empty `diff` is the expected result for a pure reorder,
squash, or message edit. If it is not empty, the rewrite
changed content: show the user both diffs and stop.

When the rewrite deliberately changes content (a fixup folded
into its originating commit), the difference must be exactly
that fixup's diff and nothing else. Say which commit absorbed
it and show the delta.

Delete the backup ref only after the PR merges:
`git branch -D backup/<name>`.

### Post-rebase verification (MANDATORY)

After every `git rebase`, run a verification gate before
doing anything else. **Never push without passing this
gate.**

```bash
BASE_BRANCH="origin/main"  # or the PR's base branch
git log --oneline "$BASE_BRANCH"..HEAD
git diff --stat "$BASE_BRANCH"..HEAD
```

Verify:

1. **Commit count** — the number of commits matches what
   you expect (same as before the rebase, minus any
   squashed commits). If there are MORE commits than
   expected, the rebase introduced foreign commits.
2. **Commit messages** — every commit message relates to
   the current issue. Flag any commit mentioning a
   different issue number.
3. **Changed files** — `git diff --stat` should only show
   files relevant to this issue. Unexpected files mean
   foreign changes leaked in.

**If any check fails:** do NOT push. Show the user the
unexpected commits or files, run `git rebase --abort` or
`git reset --hard` to the pre-rebase state (you must save
the pre-rebase commit hash before starting), and ask for
guidance.

**Pre-rebase safety:** before running any rebase, save the
current HEAD:

```bash
PRE_REBASE_HEAD=$(git rev-parse HEAD)
```

This allows reverting with `git reset --hard
$PRE_REBASE_HEAD` if the post-rebase verification fails.

### Rebase target restriction

Only rebase onto the PR's base branch (typically
`origin/master` or `origin/main`). **Never rebase onto
another feature branch** unless the user explicitly requests
a stacked PR and confirms the target branch name. If a user
says "rebase with X" where X is a feature branch, confirm:

> You asked to rebase onto `{branch}`, which is a feature
> branch (not master/main). This will make all commits from
> that branch ancestors of this branch. Proceed?

## Track progress

Update `{SNIPPETS_DIR}/worklog.md` after every code change,
not only at step boundaries:

```
## Step N: {Description}
- {What was changed and why} ({files touched})
- {Next change...}
- Verification: {pass/fail} — {what was run}
- Deviations from plan: {any, or "none"}
```

If a deviation from the plan occurs and `deciduous` is
available, run `deciduous archaeology pivot <old_decision_id>
"<what was learned>" "<new approach>"`. It creates the
observation, revisit and new decision, and marks the old
approach superseded. Record the Options you
considered for the new approach — not just the pivot itself
— so the graph captures the full decision space at each
inflection point.

## Testing conventions

Before writing any new test, read existing test files for the
module being changed. Match the project's patterns for:
- Factory module paths and function names
- Error tuple formats
- Setup block conventions

Rules:
- Always use factories to prepare test data, never inline structs
  or direct Repo calls in test setup
- Never mock modules unless they implement a behaviour
- **Full-struct equality in assertions.** Build the expected value
  via a factory and compare the whole struct/tuple (`assert call()
  == {:ok, expected}`); never pattern-match a subset of fields.
  Pattern-match only what genuinely cannot be predicted
  (auto-generated ids/timestamps), and only to seed the expected
  factory build.
- **Author a data-map factory from raw literals, not by
  transforming another factory's struct.** When a factory's output
  is a plain map (a DB round-tripped shape, an event/metadata `data`
  payload), do NOT derive it by building a sibling struct factory
  and flattening/`Map.take`/`Map.merge`-ing it to reach the shape.
  Duplicate the raw literal, expose `data_attrs` via
  `Map.pop(attrs, :data_attrs, %{})` + `Map.merge` for per-scenario
  overrides, and wrap through the existing entity factory's
  `build/2` (`Factory.Entity.<Thing>.build(:variant, data: data)`),
  not a raw struct literal. Keep it one function. Reuse a sibling
  `data_*` factory ONLY when its shape matches byte-for-byte (dump
  both and diff): a factory mirroring a different source drifts on
  keys and encodings (Decimal struct vs string, atom vs string
  value, `charge` vs `elements`), and `params_for`/`to_raw` each
  shift the encoding their own way — if it needs overrides to
  match, it is not a match.

## Documentation conventions

Docstrings & moduledocs:
- Max 98 characters per line — this applies *inside*
  `@moduledoc` / `@doc` heredoc bodies too, not just code.
  `mix format` does NOT reflow string contents, so wrap prose
  to fill up to 98 chars before breaking (break without
  splitting words). Do not wrap at a narrower default width.
- Every module reference in a docstring uses
  `#{inspect(Module.Name)}` — never a bare `Module.Name`
  literal (breaks when the module is renamed)

## Turn solution verifier failures green

The Plan phase stubbed out a **solution verifier** section in
`{SNIPPETS_DIR}/plan.livemd`: one ExUnit cell per acceptance
criterion (each cell's recorded output reports `N failures`
until the implementation is written), plus a Solution Critique
placeholder. During implementation, write the code that turns
each cell's failures into zero failures and capture the new
output as proof-of-work. See
[solution-verifier.md](solution-verifier.md) for the full
contract and the two pass conditions.

**Update verifier cells incrementally**, not at the end:
- As soon as a step makes a criterion exercisable, re-run that
  cell. The ExUnit assertion now passes; the cell's recorded
  output flips from `N failures` to `0 failures`.
- Cover happy path AND at least one negative path per
  criterion when the criterion involves error handling or
  validation. Each path is one `test "..."` inside the AC
  cell's test module.
- Verifier cells must be self-contained — build inputs and
  `expected` via factories (no inline `%{...}` / `%Module{...}`
  literals, no prod builders). If a factory variant doesn't
  exist for the shape under test, **add one** before updating
  the cell.
- Use repo-specific assertion helpers when they apply (e.g.
  helpers that handle autogen fields, Ecto `__meta__` state,
  decimal precision). Research before writing — see the
  "Research repo assertion helpers" sub-section in
  [plan-phase.md](plan-phase.md).
- Run `playbill verify` (or `playbill exec` on the changed
  cell) to capture the new output. The captured `0 failures`
  line is the proof-of-work signature for that criterion.

When the final criterion turns green, replace the **Solution
Critique** placeholder with a real critique answering:
- Does captured output prove every acceptance criterion?
- What alternatives were rejected, and why? If `deciduous` is
  on PATH, run `deciduous nodes -t option` and read the
  rejected rows (STATUS column `rejected`).
- What trade-offs remain?
- What future regressions would this verifier catch?

Run `playbill verify` one final time. Zero diffs == baseline
established. Confirm `grep -nE '[1-9][0-9]* failure'
"{SNIPPETS_DIR}/plan.livemd"` returns nothing (the second pass
condition). Commit the notebook so the baseline lives in git
history.

Tell the user the verifier is passing and can be opened in
LiveBook for interactive review.
