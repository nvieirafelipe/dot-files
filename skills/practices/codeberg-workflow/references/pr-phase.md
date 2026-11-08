# PR Phase Details

## Review

Read `plan.md`, `worklog.md`, and `plan.livemd`. Compare
planned vs actual work. Identify:

- Completed steps
- Deviations from the plan and their reasons
- Any trade-offs made during implementation

## Solution verifier gate — two pass conditions

The notebook is the **solution verifier** for the issue. See
[solution-verifier.md](solution-verifier.md) for the full
contract. The gate has two orthogonal pass conditions; both
must hold before any PR action.

### Pass condition 1 — zero diffs vs baseline

Playbill records each executed cell's output directly into
the `.livemd` file as a fenced block immediately following
the cell. That recorded output IS the baseline; the baseline
lives in git alongside the notebook.

```bash
playbill verify "{SNIPPETS_DIR}/plan.livemd"
```

`playbill verify` re-executes every cell against the current
branch code and diffs the fresh output against the output
recorded in the file. Any cell whose fresh output differs
from its recorded output is a diff. Three things can cause a
diff:

- **Regression** — the implementation changed behavior the
  verifier captured earlier. Fix the code, re-run, commit.
- **Intentional refinement** — the verifier's recording was
  wrong and the new output is actually correct. Re-capture
  via `playbill exec`, commit the new baseline, and append a
  paragraph to the Solution Critique explaining why.
- **Stale recording** — the cell was last captured against an
  older branch state. Re-run `playbill verify` to recapture,
  commit.

Never push a notebook with unexplained diffs.

### Pass condition 2 — zero ExUnit failures in the baseline

Every AC verifier cell ends with `ExUnit.run()`, which prints
a summary line like `1 test, 0 failures, ...`. The gate fails
if any cell's recorded output reports `N failures` with N ≥ 1
— even when there are zero diffs, a baseline of "1 failure"
is itself failing.

```bash
grep -nE '[1-9][0-9]* failure' "{SNIPPETS_DIR}/plan.livemd"
```

If grep returns any line, the baseline is failing. Fix the
implementation (or correct the assertion if the plan's
expected value was wrong), re-run `playbill exec` to update
the baseline, commit.

### Both conditions together

- Diffs prove **stability** — the recorded output is
  reproducible.
- Zero failures prove **correctness** — the recorded output
  IS green.

Both must hold. The pre-push hook installed by
[`scripts/install-pre-push-hook.sh`](../scripts/install-pre-push-hook.sh)
enforces both locally.

Re-read the **Solution Critique** note. If any item is `TODO`
or unclear, fill it in before proceeding — the critique is
what tells reviewers the implementation is the *right*
solution, not just a working one.

## Project verification gate (MANDATORY)

Before creating or pushing a PR, run the full verification
suite:

```bash
mix compile --warnings-as-errors && \
mix format --check-formatted && \
mix dialyzer && \
mix credo --strict && \
mix test
```

**All checks must pass.** If any check fails, fix the issue
and re-run the full suite before proceeding. Do NOT skip
this gate — a PR with failing checks wastes reviewer time
and delays the issue.

If a fix requires code changes, commit them following the
same conventions from the implement phase (focused commit
message, logical grouping). Update the worklog with what
was fixed.

## Guided review

The `guided-pr-review` skill reviews the branch, and its report
is the reviewer gate's artifact: the pre-push hook reads
`{SNIPPETS_DIR}/guided-review/review.md`, as
[reviewer-gate.md](reviewer-gate.md) describes. The skill reads
the issue, the plan, and the standards before the code, checks
every finding against evidence, and ends in a fix list. Run it
once the two gates above pass; reviewing code that fails them
wastes the review.

1. Commit everything first, so the review covers the
   committed tip and the skill makes no `-wip` snapshot.
2. Run `guided-pr-review` in local mode with these inputs:
   - **Base:** `origin/{BASE}`, the branch the worktree was
     cut from. Pass it explicitly: the skill looks up a base
     and fetches PRs with `gh`, which does not reach Codeberg.
     In a resumed session, read it from the branch's upstream
     while the branch is unpushed
     (`git rev-parse --abbrev-ref '@{upstream}'`), otherwise
     from `git symbolic-ref --short refs/remotes/origin/HEAD`.
   - **Output directory:** `{SNIPPETS_DIR}/guided-review/`,
     the path the gate reads.
   - **Spec:** the issue, fetched as in
     [plan-phase.md](plan-phase.md), and the acceptance
     criteria in `plan.md`. The recorded outputs in
     `plan.livemd` are evidence for the report's Tests and
     verification section.
   - **Standards:** `nvieirafelipe-elixir-xp` and the standards
     checklist in [reviewer-gate.md](reviewer-gate.md), so each
     item there ends up as a finding or under "Checked, no
     issue found".
   - **Mode:** `full`. For a diff of about 100 changed lines or
     fewer, which guided-pr-review's size guidance says reads
     in one sitting, offer `quick`, which skips the verifier
     pass. In both modes, run the Spec and Standards readers as
     fresh sub-agents: this session wrote the code.
3. Show the user the verdict, the paths to `review.md` and
   `review.html`, and the fix list. Apply only the fixes the
   user names, and commit them by the implement-phase
   conventions. The commit hooks run as usual.
4. If code changed, run the solution verifier gate and the
   project verification gate again. Then run the skill's
   snapshot again, update the report's heads table, and record
   each fix's outcome in its review log.
5. Last, after the final commit, end the report with the
   `## Status` section [reviewer-gate.md](reviewer-gate.md)
   specifies, set from the verdict, and render it again. The
   pre-push hook rejects a report older than HEAD.

## Create or detect PR

First, check if a PR already exists for the current branch:

```bash
tea pulls ls --state open --output json | jq '.[] | select(.head.name == "'$(git branch --show-current)'")'
```

**If a PR already exists:** log it in the worklog under the
current step as `- **PR detected:** {url}` and skip creation.
Then check whether the description needs updating (see
"Update PR description" below).

**If no PR exists**, prepare to create one:

Search the repository for a PR template. Look for files
at `.gitea/pull_request_template.md`,
`.github/pull_request_template.md`, or
`docs/pull_request_template.md`.

If a template is found, use it as the structure for the PR
description. Fill in each section using data from `plan.md`,
`worklog.md`, and `plan.livemd`.

If no template is found, write a `pr-description.md` in
`{SNIPPETS_DIR}` with a summary, list of changes, and testing
notes.

**Avoid slop in the description.** PR body is async chat
with reviewer, not essay. Read
[no-slop-pr.md](no-slop-pr.md) before drafting:

- Lead with a one-sentence summary of the change.
- 3–6 bullets max for the diff shape.
- Test plan = reviewer's verification checklist, not a
  diary of what you ran.
- Cut: parent-issue history paragraphs, "scope / out of
  scope" essays, restated commit messages, AI-attribution
  footers, filler ("great question", "let me break down",
  "in conclusion"), and architecture lectures that belong
  in the code or in `plan.md`.

Run the [no-slop-pr.md](no-slop-pr.md) **Self-check before
submitting** list against the draft before showing it to
the user.

**Before pushing or creating the PR, present this summary
and wait for the user to approve:**

> **Branch:** `{current branch name}`
> **PR title:** {title}
> **Base branch:** {base}
> **Closes:** issue #{ISSUE_NUMBER}
> **Description preview:** (first 5 lines)

Do NOT push or run `tea pulls create` until the user confirms.

Create the PR using the filled template or the generated
description. Include `Closes #{ISSUE_NUMBER}` in the PR
body to auto-close the issue on merge:

```bash
tea pulls create \
  --base main \
  --head "$(git branch --show-current)" \
  --title "{PR title}" \
  --description "$(cat <<'EOF'
{PR description}

Closes #{ISSUE_NUMBER}
EOF
)"
```

Log the new PR in the worklog as
`- **PR created:** {url}`.

## Update PR description

Whether the PR was just created or already existed, compare
its current description against `plan.md`, `worklog.md`, and
`plan.livemd`. If the description is missing sections,
outdated, or incomplete, update it using tea or the Gitea
API:

```bash
tea api /repos/{REPO_OWNER}/{REPO_NAME}/pulls/{PR_NUMBER} \
  --method PATCH \
  --data '{"body": "{updated description}"}'
```

Log description updates in the worklog as
`- **PR description updated:** {what changed}`.

## Sync Deciduous graph

After the PR is created, if `deciduous` is on PATH and the
project has a `.deciduous/` directory, confirm the graph is
saved. In server mode (`[remote]` in `.deciduous/config.toml`):

```bash
deciduous remote status   # or: make deciduous-status
```

Read its `Log:` line: `0 write(s) waiting, 0 rejected` means every
write reached the server. The command also exits 1 when the local
cache differs from the server with nothing waiting; that is cache
drift, not lost work. In git mode, run
`deciduous sync` and commit `.deciduous/graph.json` by path if
it changed. The `docs/` graph export no longer exists.

See [development-workflow.md](development-workflow.md) for
the full list of `make deciduous-*` targets.

## Cleanup

After the PR is created, run the **session deregister**
command and remind the user about the worktree:

```bash
# session deregister
ROOT="$(git rev-parse --show-toplevel)"
sed -i '' "/^$PPID /d" "$ROOT/.claude/.codeberg-workflow"
[ ! -s "$ROOT/.claude/.codeberg-workflow" ] && rm -f "$ROOT/.claude/.codeberg-workflow"
```

Tell the user:
- This session has been deregistered from
  `.claude/.codeberg-workflow`
- The worktree `issue-{ISSUE_NUMBER}-{ISSUE_SLUG}` can be
  deleted once the PR is merged — remind them to run
  `git worktree unlock <worktree-path> && git worktree remove <worktree-path>`
  when ready

Do not delete the worktree automatically — the user may need
it for PR review feedback.
