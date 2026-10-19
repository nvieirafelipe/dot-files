---
name: codeberg-workflow
description: >
  Guides implementation of Codeberg issues through plan, implement, and PR
  phases with a Playbill LiveBook notebook acting as the solution verifier
  (executable proof-of-work, inspired by simonw/showboat). The verifier uses
  ExUnit-driven cells whose recorded outputs gate the PR on two conditions:
  zero diffs vs the committed baseline, and zero ExUnit failures. Use when
  starting work on a Codeberg issue, following an implementation plan, or
  preparing a pull request on a Gitea-compatible forge.
disable-model-invocation: true
argument-hint: <issue-link-or-number>
allowed-tools: "Bash, Read, Write, Edit, Glob, Grep, Agent, Skill"
hooks:
  PreToolUse:
    - matcher: "Write|Edit|Bash"
      hooks:
        - type: command
          command: |
            ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
            ISSUE=$(grep "^$PPID " "$ROOT/.claude/.codeberg-workflow" 2>/dev/null | awk '{print $2}')
            [ -n "$ISSUE" ] && [ -f "$ROOT/.snippets/$ISSUE/plan.md" ] && head -40 "$ROOT/.snippets/$ISSUE/plan.md"
            exit 0
    - matcher: "Bash"
      hooks:
        - type: command
          command: |
            ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
            ISSUE=$(grep "^$PPID " "$ROOT/.claude/.codeberg-workflow" 2>/dev/null | awk '{print $2}')
            [ -z "$ISSUE" ] && exit 0
            INPUT=$(cat)
            CMD=$(echo "$INPUT" | grep -o '"command":"[^"]*"' | head -1 | sed 's/"command":"//;s/"$//')
            echo "$CMD" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+commit([[:space:]]|$)' || exit 0
            STAGED=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -E '\.(ex|exs)$')
            [ -z "$STAGED" ] && exit 0
            # Format the whole project, not just staged files — Quokka's
            # autosort plugin can reorder fields in unstaged files too
            # (e.g. when a map literal matches one in a staged file) and
            # the later `mix format --check-formatted` run will catch
            # those. Formatting everything keeps the repo self-consistent.
            mix format 2>/dev/null
            # Re-stage the staged .ex/.exs files so formatter changes are
            # part of the commit. Only touch already-staged paths; we do
            # not auto-stage unrelated files the formatter may have
            # touched.
            echo "$STAGED" | xargs git add 2>/dev/null
            # Belt + braces: verify the whole tree (not just staged) is
            # clean. If something unstaged is still dirty, block the
            # commit with a clear message — prevents the shipping-a-
            # broken-format bug where --check-formatted passes because
            # only staged files were fixed but unstaged ones stayed
            # dirty and surface on the NEXT commit.
            if ! mix format --check-formatted >/dev/null 2>&1; then
              echo '[codeberg-workflow] Pre-commit: mix format --check-formatted STILL dirty after auto-fix — likely unstaged files need a separate format run.' >&2
              mix format --check-formatted 2>&1 | tail -20 >&2
              exit 2
            fi
            echo '[codeberg-workflow] Pre-commit: auto-formatted staged Elixir files and re-staged.' >&2
            exit 0
        - type: command
          command: |
            ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
            ISSUE=$(grep "^$PPID " "$ROOT/.claude/.codeberg-workflow" 2>/dev/null | awk '{print $2}')
            [ -z "$ISSUE" ] && exit 0
            INPUT=$(cat)
            CMD=$(echo "$INPUT" | grep -o '"command":"[^"]*"' | head -1 | sed 's/"command":"//;s/"$//')
            echo "$CMD" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+commit([[:space:]]|$)' || exit 0
            STAGED=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -E '\.(ex|exs)$')
            [ -z "$STAGED" ] && exit 0
            HITS=""
            scan() {
              local name="$1" pattern="$2"
              local found
              found=$(echo "$STAGED" | xargs grep -nE "$pattern" 2>/dev/null | grep -v 'lint:ignore')
              [ -n "$found" ] && HITS="$HITS\n[$name]\n$found\n"
            }
            scan "per-field-assertion"    '^\s*assert\s+\w+\.\w+\s*=='
            scan "tagged-tuple-assertion" 'assert\s+\{:ok,\s*\w+\}\s*='
            scan "inline-map-fixture"     'assert.*=\s*%\{'
            scan "length-equals"          'length\(.+\)\s*==\s*[0-9]+'
            scan "mock-returns-bare-ok"   'expect\(.*,.*fn.*->\s*:ok\s*end\)'
            scan "legacy-atom-list"       '@\w+\s+\[:\w+(,\s*:\w+)+\]'
            if [ -n "$HITS" ]; then
              printf '[codeberg-workflow] Semantic lint FAILED:%b\nSee references/semantic-lint.md. Override with `# lint:ignore <name>`.\n' "$HITS" >&2
              exit 2
            fi
            exit 0
        - type: command
          command: |
            ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
            ISSUE=$(grep "^$PPID " "$ROOT/.claude/.codeberg-workflow" 2>/dev/null | awk '{print $2}')
            [ -z "$ISSUE" ] && exit 0
            INPUT=$(cat)
            CMD=$(echo "$INPUT" | grep -o '"command":"[^"]*"' | head -1 | sed 's/"command":"//;s/"$//')
            # Gate only pushes that target the `codeberg` remote, plus PR
            # creation (which always targets the forge). A `git push` to any
            # other remote (e.g. a github mirror) is left ungated.
            if echo "$CMD" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+push([[:space:]]|$)'; then
              # Strip the `git push` prefix and flags, then take the first
              # non-flag token — the remote name. Bail unless it is codeberg.
              REMOTE=$(echo "$CMD" \
                | sed -E 's/.*git[[:space:]]+push[[:space:]]+//' \
                | tr ' ' '\n' | grep -vE '^-' | head -1)
              [ "$REMOTE" = "codeberg" ] || exit 0
            elif ! echo "$CMD" | grep -qE '(tea[[:space:]]+pulls[[:space:]]+create|gh[[:space:]]+pr[[:space:]]+create)'; then
              exit 0
            fi
            NOTEBOOK="$ROOT/.snippets/$ISSUE/plan.livemd"
            FAILED=""
            mix compile --warnings-as-errors >/dev/null 2>&1 || FAILED="$FAILED compile"
            mix format --check-formatted >/dev/null 2>&1 || FAILED="$FAILED format"
            mix credo --strict >/dev/null 2>&1 || FAILED="$FAILED credo"
            mix test >/dev/null 2>&1 || FAILED="$FAILED test"
            mix dialyzer >/dev/null 2>&1 || FAILED="$FAILED dialyzer"
            if [ -f "$NOTEBOOK" ]; then
              if ! playbill verify "$NOTEBOOK" >/dev/null 2>&1; then
                FAILED="$FAILED playbill-verify"
              elif grep -qE '[1-9][0-9]* failure' "$NOTEBOOK"; then
                # baseline itself reports ExUnit failures — the gate is the
                # second pass condition; see references/solution-verifier.md.
                FAILED="$FAILED plan-livebook-exunit-failures"
              fi
            else
              FAILED="$FAILED plan-livebook-missing"
            fi
            REVIEW="$ROOT/.snippets/$ISSUE/review.md"
            if [ ! -f "$REVIEW" ]; then
              FAILED="$FAILED review-missing"
            else
              STATUS=$(awk '/^## Status/{f=1;next} f && NF{print; exit}' "$REVIEW")
              [ "$STATUS" = "APPROVED" ] || FAILED="$FAILED review-not-approved"
              REVIEW_MTIME=$(stat -f %m "$REVIEW" 2>/dev/null || stat -c %Y "$REVIEW")
              HEAD_TIME=$(git log -1 --format=%ct HEAD 2>/dev/null)
              [ -n "$REVIEW_MTIME" ] && [ -n "$HEAD_TIME" ] && [ "$HEAD_TIME" -gt "$REVIEW_MTIME" ] && FAILED="$FAILED review-stale"
            fi
            if [ -n "$FAILED" ]; then
              echo "[codeberg-workflow] Pre-push/PR gate FAILED:$FAILED. Fix before retrying. See references/quality-enforcement.md." >&2
              exit 2
            fi
            exit 0
  PostToolUse:
    - matcher: "Write|Edit"
      hooks:
        - type: command
          command: |
            ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
            ISSUE=$(grep "^$PPID " "$ROOT/.claude/.codeberg-workflow" 2>/dev/null | awk '{print $2}')
            [ -n "$ISSUE" ] && [ -f "$ROOT/.snippets/$ISSUE/worklog.md" ] && echo '[codeberg-workflow] Update worklog.md with what you just changed.'
            exit 0
        - type: command
          command: |
            ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
            ISSUE=$(grep "^$PPID " "$ROOT/.claude/.codeberg-workflow" 2>/dev/null | awk '{print $2}')
            [ -z "$ISSUE" ] && exit 0
            INPUT=$(cat)
            FILE=$(echo "$INPUT" | grep -o '"file_path":"[^"]*"' | head -1 | sed 's/"file_path":"//;s/"$//')
            echo "$FILE" | grep -qE '\.livemd$' || exit 0
            echo "[codeberg-workflow] Notebook edited: $FILE. Run 'playbill verify' to re-capture baseline."
            exit 0
    - matcher: "Bash"
      hooks:
        - type: command
          command: |
            ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
            ISSUE=$(grep "^$PPID " "$ROOT/.claude/.codeberg-workflow" 2>/dev/null | awk '{print $2}')
            [ -z "$ISSUE" ] && exit 0
            INPUT=$(cat)
            CMD=$(echo "$INPUT" | grep -o '"command":"[^"]*"' | head -1 | sed 's/"command":"//;s/"$//')
            echo "$CMD" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+commit([[:space:]]|$)' || exit 0
            FAILED=""
            mix compile --warnings-as-errors >/dev/null 2>&1 || FAILED="$FAILED compile"
            mix format --check-formatted >/dev/null 2>&1 || FAILED="$FAILED format"
            mix credo --strict >/dev/null 2>&1 || FAILED="$FAILED credo"
            mix test >/dev/null 2>&1 || FAILED="$FAILED test"
            if [ -n "$FAILED" ]; then
              echo "[codeberg-workflow] Post-commit quality gate FAILED:$FAILED" >&2
              echo "Next priority: fix the failing check(s) before any other work." >&2
              echo "Do not start a new step, do not respond to new requests, do not" >&2
              echo "commit again until 'mix compile --warnings-as-errors && mix format" >&2
              echo "--check-formatted && mix credo --strict && mix test' all pass." >&2
              exit 2
            fi
            exit 0
        - type: command
          command: |
            ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
            ISSUE=$(grep "^$PPID " "$ROOT/.claude/.codeberg-workflow" 2>/dev/null | awk '{print $2}')
            [ -z "$ISSUE" ] && exit 0
            INPUT=$(cat)
            CMD=$(echo "$INPUT" | grep -o '"command":"[^"]*"' | head -1 | sed 's/"command":"//;s/"$//')
            echo "$CMD" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+rebase' || exit 0
            BASE=$(git for-each-ref --format='%(upstream:short)' "$(git symbolic-ref -q HEAD)" 2>/dev/null)
            BASE=${BASE:-origin/main}
            ISSUE_NUM=$(echo "$ISSUE" | sed 's/^issue-//')
            echo "[codeberg-workflow] Post-rebase scan vs $BASE:"
            git log --oneline "$BASE"..HEAD 2>/dev/null
            FOREIGN=$(git log --format='%h %s' "$BASE"..HEAD 2>/dev/null | grep -vE "(issue-$ISSUE_NUM|#$ISSUE_NUM)" || true)
            if [ -n "$FOREIGN" ]; then
              echo "[codeberg-workflow] WARNING: commits not mentioning issue-$ISSUE_NUM detected. Verify none are foreign before pushing." >&2
            fi
            exit 0
  Stop:
    - hooks:
        - type: command
          command: |
            ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
            ISSUE=$(grep "^$PPID " "$ROOT/.claude/.codeberg-workflow" 2>/dev/null | awk '{print $2}')
            [ -z "$ISSUE" ] && exit 0
            PLAN="$ROOT/.snippets/$ISSUE/plan.md"
            if [ -f "$PLAN" ]; then
              UNCHECKED=$(grep -c '\- \[ \]' "$PLAN" 2>/dev/null || echo 0)
              [ "$UNCHECKED" -gt 0 ] && echo "[codeberg-workflow] $UNCHECKED unchecked steps remain in plan.md. Verify all work is complete before stopping."
            fi
            ISSUE_NUM=$(echo "$ISSUE" | sed 's/^issue-//')
            TODOS=$(grep -rnE "TODO.*(issue-$ISSUE_NUM|#$ISSUE_NUM)" lib/ test/ 2>/dev/null | wc -l | tr -d ' ')
            [ "$TODOS" -gt 0 ] && echo "[codeberg-workflow] $TODOS TODO comment(s) reference issue-$ISSUE_NUM. Resolve before closing."
            exit 0
---

STARTER_CHARACTER = 📋🍵

## Prerequisites

This skill depends on the following skills being available:

- `tea` — fetch issue details and manage PRs on Codeberg
- `using-playbill` — generate LiveBook notebooks
- `nvieirafelipe-elixir-xp` — **required on every issue**;
  personal Elixir XP rules (testing, coding, docs, commits/PR)
  for personal repos. Overrides `elixir-crafting` on conflict.
- `elixir-crafting` — generic XP/Elixir discipline, used by
  `nvieirafelipe-elixir-xp` under the hood
- `elixir` domain skills (`ecto`, `phoenix`, `otp`, `oban`)
  — implementation guidance per domain
- `deciduous` (optional) — decision graph tracking
- `mermaid-master` — diagram generation with type selection
  and preview

## Setup

Extract the issue number from `$ARGUMENTS`. Accept Codeberg URLs
(`codeberg.org/{owner}/{repo}/issues/{N}`), `{owner}/{repo}#{N}`,
or plain numbers (`#N`, `N`). If `$ARGUMENTS` is empty, ask the
user for the issue link or number before proceeding. Store as
`ISSUE_NUMBER` for the session.

Determine the repository owner and name from the git remote:

```bash
tea login ls
git remote get-url origin
```

Store as `REPO_OWNER` and `REPO_NAME` for the session.

Create `.snippets/issue-{ISSUE_NUMBER}/` in the **main
repository root** if it does not exist. This directory must
always live in the main repo, never inside a worktree. Store
the absolute path as `SNIPPETS_DIR` for the session.

Ensure `.snippets/` and `.claude/.codeberg-workflow` are in
the user's global gitignore:

```bash
grep -qxF '.snippets/' ~/.gitignore 2>/dev/null || echo '.snippets/' >> ~/.gitignore
grep -qxF '.claude/.codeberg-workflow' ~/.gitignore 2>/dev/null || echo '.claude/.codeberg-workflow' >> ~/.gitignore
```

Register this session in `.claude/.codeberg-workflow` (one
line per concurrent session, keyed by `$PPID`):

```bash
echo "$PPID issue-{ISSUE_NUMBER}" >> "$(git rev-parse --show-toplevel)/.claude/.codeberg-workflow"
```

Create the worklog file at `{SNIPPETS_DIR}/worklog.md` if it
does not exist, initialized with a session recovery block:

```
# Worklog: issue-{ISSUE_NUMBER}

## Session state
- **Current phase:** {Plan/Implement/PR}
- **Current step:** {N of M, or "planning"}
- **Last action:** {what was done last}
- **Next action:** {what to do next}
- **Blockers:** {any, or "none"}

## Error log

| Step | Error | Attempt | Resolution |
|------|-------|---------|------------|

## Progress
```

Update the **Session state** block every time the phase or
step changes. This block is the first thing to read when
resuming an issue in a new conversation.

### Deciduous context recovery

Skip this section silently when `deciduous` is not on PATH or the
project has no `.deciduous/` directory. The project runs in one of
two modes, and the steps differ:

- **Server mode:** `.deciduous/config.toml` has a `[remote]`
  section. The graph lives on a graph server and
  `.deciduous/deciduous.db` is a local cache of it.
- **Git mode:** no `[remote]`. The graph lives in the tracked
  `.deciduous/graph.json`, and `deciduous sync` reconciles it with
  the local database.

When starting or resuming work, refresh the local copy, then read
the graph's state:

```bash
if grep -q '^\[remote\]' .deciduous/config.toml 2>/dev/null; then
  deciduous remote pull   # server mode: refresh the cache from the server
else
  deciduous sync          # git mode: fold graph.json into the local database
fi
deciduous pulse
```

`deciduous pulse` shows active goals, coverage gaps, and graph
health. Do this **before** reading the worklog: the graph may hold
rationale lost to context compaction.

**Worktrees.** Each worktree keeps its own `.deciduous/deciduous.db`.
Never symlink it to another checkout's database: since deciduous
1.0.11 the local database follows the branch's `graph.json` on
every checkout, so one file cannot serve two branches.
UNVERIFIED: the exact failure when two checkouts share one file
(inferred from the 1.0.11 changelog, not reproduced). In server
mode, a worktree whose `config.toml` has no
`[remote]` sends its writes to the main checkout's server. If the
worktree's tracked `config.toml` lacks `[remote]`, run
`deciduous remote init <url> --workspace <name>` in it once, or
`deciduous update` stops with exit 1 at its server step. In git
mode, the worktree's database follows its own branch's
`graph.json` and needs no setup.

**Where the graph is saved.** In server mode, every `deciduous add`,
`link`, and `status` call is sent to the server before the command
exits; `deciduous remote status` confirms nothing is waiting, and
there is nothing to commit. In git mode, run `deciduous sync` and
commit `.deciduous/graph.json` by path in the same workflow as the
calls that changed it, never with `git add -A`. The pre-0.17 event
log (`.deciduous/sync/events/`) and the `docs/` graph export no
longer exist, so there is nothing else to stage.

**Auto-run deciduous post-commit, no approval prompt.** No hook
prompts for this step any more. After each `git commit` that
implements a plan step, run the commit-linking calls (see
[references/implement-phase.md](references/implement-phase.md))
directly without asking the user to approve them first. The user
opted into this auto-flow; only pause for explicit approval if the
commit message hints at a sensitive context (security, secrets, or
the user has previously asked you to skip deciduous for that
session). Outcome wording stays a terse summary derived from the
commit message: no transcripts, no PII.

### 5-question reboot test

When resuming an issue (new conversation or after `/clear`),
read the Session state block and verify you can answer:

- **Where am I?** → Current phase + step in worklog
- **Where am I going?** → Remaining steps in plan.md
- **What's the goal?** → Issue definition in plan.md
- **What have I learned?** → Exploration notes in worklog
- **What have I done?** → Progress entries in worklog

If any answer is unclear, re-read the corresponding file
before proceeding. Then re-register the new session PID
(the previous `$PPID` is stale):

```bash
echo "$PPID issue-{ISSUE_NUMBER}" >> "$(git rev-parse --show-toplevel)/.claude/.codeberg-workflow"
```

### Create worktree

Create a **persistent** git worktree to isolate work for this
issue. Derive `ISSUE_SLUG` from the issue title: lowercase,
spaces to hyphens, remove non-alphanumeric characters, truncate
to 50 characters.

The worktree lives in `.claude/worktrees/{BRANCH}` under the main
checkout, the directory Claude Code uses for its own worktrees,
but it must not be one of Claude Code's own. Claude Code deletes
the worktrees it creates: a clean, unnamed `--worktree` session's
worktree on exit without asking, and subagent and
background-session worktrees in a periodic sweep after
`cleanupPeriodDays`. Work has been lost that way. Both rules
cover only worktrees Claude Code created, and the sweep never
releases a lock it did not set
(https://code.claude.com/docs/en/worktrees, checked 2026-10-18
against Claude Code 2.1.302). So:

- Create it with `git worktree add`, then `git worktree lock` it.
- Never create it with `claude --worktree`/`-w`, EnterWorktree
  `name`, or subagent `isolation: "worktree"`.
- Never launch `claude --worktree <name>` against it. That form
  reopens an existing directory, and the docs do not say whether
  its exit cleanup then applies to a worktree made by
  `git worktree add`.
- To move a session into it, start `claude` from inside it, or
  call EnterWorktree with `path`. ExitWorktree never removes a
  worktree entered by `path`.

**Show the user the computed branch name and ask for
confirmation before creating the worktree:**

> Branch name: `issue-{ISSUE_NUMBER}-{ISSUE_SLUG}`

Wait for explicit approval. If the user suggests a different
name, use that instead.

Create it under the main checkout's `.claude/worktrees/`, named
after the branch, and lock it. `--git-common-dir` finds the main
checkout even when this runs from inside another worktree, where
`--show-toplevel` would return that worktree:

```bash
MAIN_ROOT="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"
BRANCH="issue-${ISSUE_NUMBER}-${ISSUE_SLUG}"  # e.g. issue-42-add-due-dates-...
BASE="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')"
BASE="${BASE:-main}"   # fall back only if origin/HEAD is unset; confirm it is right
WORKTREE="$MAIN_ROOT/.claude/worktrees/$BRANCH"

# Keep the worktree out of the main checkout's `git status`
git -C "$MAIN_ROOT" check-ignore -q .claude/worktrees/ || echo '.claude/worktrees/' >> ~/.gitignore

git fetch origin "$BASE"
git worktree add "$WORKTREE" -b "$BRANCH" "origin/$BASE"
git worktree lock --reason "codeberg-workflow issue-${ISSUE_NUMBER}" "$WORKTREE"
cd "$WORKTREE"
```

Then confirm you are actually in it before the first edit:

```bash
git rev-parse --show-toplevel   # must be the worktree, not the main checkout
git rev-parse --abbrev-ref HEAD # must be $BRANCH, never main/master
```

If a worktree for this issue already exists (`git worktree list`),
`cd` into it instead of creating a new one, and lock it if
`git worktree list` does not show it as `locked`. One made before
this layout sits next to the main checkout
(`../<repo>-<branch>`); move it with
`git worktree move <old-path> "$WORKTREE"` (unlock it first if
locked) or keep using it where it is.

After creating a new worktree, copy untracked project-local
files into the worktree:

```bash
MAIN_ROOT="$(git -C <main-repo> rev-parse --show-toplevel)"
WORKTREE_ROOT="$(git rev-parse --show-toplevel)"

# Copy root .env files
cp "$MAIN_ROOT"/.env* "$WORKTREE_ROOT/" 2>/dev/null

# Copy .projections.json (root and per-app in umbrella)
find "$MAIN_ROOT" -name '.projections.json' -not -path '*/.git/*' -not -path '*/deps/*' -not -path '*/_build/*' | while read f; do
  rel="${f#$MAIN_ROOT/}"
  mkdir -p "$WORKTREE_ROOT/$(dirname "$rel")"
  cp "$f" "$WORKTREE_ROOT/$rel"
done
```

Do not copy or symlink `.deciduous/deciduous.db` into the worktree.
See "Deciduous context recovery" for the per-mode worktree setup.

### Check Playbill

Verify `playbill` is available by running `which playbill`.
If not found, tell the user to install it and do not proceed
until it is on the PATH.

## Phase detection

Check which phase to enter:

1. No `{SNIPPETS_DIR}/plan.md` exists, or plan.md exists but
   `worklog.md` or `plan.livemd` is missing →
   **Plan phase** (create or complete all three deliverables)
2. All three files exist and work is incomplete →
   **Implement phase**
3. All tasks in plan.md are done → **PR phase**

Tell the user which phase you detected and why.

## Plan phase

Fetch the issue, assess readiness, explore the codebase, write
the implementation plan, log decisions to Deciduous, and
generate the Playbill notebook — including the **solution
verifier skeleton** (placeholder cells per acceptance
criterion; `playbill verify` is expected to fail until
Implement phase fills them).

For full details on each sub-step (issue fetching, readiness
assessment, exploration budget, plan format, Deciduous
integration, Playbill notebook structure, and the plan phase
gate), see
[references/plan-phase.md](references/plan-phase.md). For the
solution-verifier mental model (inspired by
[simonw/showboat](https://github.com/simonw/showboat)), see
[references/solution-verifier.md](references/solution-verifier.md).

The Plan phase expects the issue body to follow the
WHY / WHAT / HOW / DEFINITION OF DONE / REFERENCES structure
documented in
[references/issue-template.md](references/issue-template.md).
If the body lacks one of those sections, has contradictions
between them, or contains `OPEN:` markers, reconcile **with
the user** and push an edit via `tea issues edit` before
writing `plan.md`. Canonical templates live in
[templates/](templates/) and should be seeded into any
Codeberg/Gitea repo that does not already have
`.gitea/ISSUE_TEMPLATE/`.

The Plan phase is **not complete** until all three files exist
and have been presented to the user:

1. `{SNIPPETS_DIR}/plan.md` — implementation plan
2. `{SNIPPETS_DIR}/worklog.md` — initialized worklog
3. `{SNIPPETS_DIR}/plan.livemd` — Playbill notebook (ExUnit-driven
   solution verifier)

## Implement phase

### Start implementation

Read `{SNIPPETS_DIR}/plan.md` and pick the next incomplete
step. Re-reading the plan before each step (and before design
decisions or deviations) pulls goals back into the attention
window. Tell the user which step you are working on.

Use the `nvieirafelipe-elixir-xp` skill on every issue — it is
the authoritative source for personal Elixir testing, coding,
documentation, and commit/PR rules, and it composes
`elixir-crafting` + `tdd` underneath. When its rules conflict
with `elixir-crafting`, `nvieirafelipe-elixir-xp` wins. Use the
relevant domain-specific elixir skills (ecto, phoenix, otp,
oban) for implementation guidance. Run the
`nvieirafelipe-elixir-xp` pre-PR self-review checklist before
moving to the PR phase.

For verification, failure protocol, commit workflow, progress
tracking, testing conventions, and Playbill notebook
verification, see
[references/implement-phase.md](references/implement-phase.md).

### Repeat

After each step, check the plan for the next incomplete step.
Also search for `TODO` comments containing `issue-{ISSUE_NUMBER}`
and resolve them in the relevant step or as a final step.
When all steps are done, suggest moving to the PR phase.

## PR phase

Review planned vs actual work, create or detect the PR,
update its description, and clean up the session.

For full details on review checklist, PR creation/detection,
description updates, and session cleanup,
see [references/pr-phase.md](references/pr-phase.md).

**Key rules (always apply):**
- Run the full project verification gate before creating or
  pushing a PR (`mix compile --warnings-as-errors`,
  `mix format --check-formatted`, `mix dialyzer`,
  `mix credo --strict`, `mix test`) — all must pass
- Do NOT push or run `tea pulls create` until the user confirms
- Before pushing, run the post-rebase verification gate
  (see [implement-phase.md](references/implement-phase.md))
- Run the **solution verifier gate** with both pass conditions:
  (1) `playbill verify "$SNIPPETS_DIR/plan.livemd"` producing
  zero diffs against the committed baseline, AND (2) the
  notebook's recorded outputs contain zero ExUnit failures
  (no `N failures` line with N ≥ 1). Confirm the Solution
  Critique has no remaining `TODO` items —
  see [solution-verifier.md](references/solution-verifier.md)
  for the explanation of both conditions and how the baseline
  comparison works
- Produce `{SNIPPETS_DIR}/review.md` via the
  `nvieirafelipe-elixir-xp` pre-PR checklist or an Elixir
  PR-review agent, resolve all
  findings, and set `## Status` to `APPROVED`. The pre-push
  hook blocks until this artifact exists and is not stale —
  see [reviewer-gate.md](references/reviewer-gate.md).
- **No slop in the PR description.** Treat the body as async
  chat with the reviewer, not an essay. Read
  [no-slop-pr.md](references/no-slop-pr.md) before drafting
  and run its **Self-check before submitting** list on the
  draft. Cut history paragraphs, restated commit messages,
  AI-attribution footers, filler, and architecture lectures.
- **Harvest new regexes.** During the review, scan the worklog
  Error log and the review findings for patterns repeated
  across this issue or prior ones. Append any pattern seen
  twice or more to the
  [semantic-lint.md backlog](references/semantic-lint.md#backlog).
  Promote on the next issue that touches the same area.

## Hook automation

This skill registers 10 Claude Code hooks that fire only when
the current `$PPID` is registered in `.claude/.codeberg-workflow`
(so they no-op outside active workflow sessions):

| Event | Trigger | Action |
|-------|---------|--------|
| PreToolUse Write/Edit/Bash | any | Inject first 40 lines of `plan.md` so goals stay in context |
| PreToolUse Bash | `git commit` | Auto-run `mix format` on staged `.ex/.exs`, re-stage |
| PreToolUse Bash | `git commit` | **Semantic lint** — regex scan for XP antipatterns. **Blocks on failure.** See [references/semantic-lint.md](references/semantic-lint.md). |
| PreToolUse Bash | `git push codeberg`, `tea pulls create`, `gh pr create` | Full gate (compile + format-check + credo + test + dialyzer + `playbill verify` on `plan.livemd` + **zero recorded ExUnit failures** in the notebook + **reviewer gate** on `review.md`). Only `git push` to the **`codeberg`** remote is gated — pushes to other remotes (e.g. a github mirror) skip it. **Blocks on failure.** See [references/reviewer-gate.md](references/reviewer-gate.md). |
| PostToolUse Write/Edit | any | Nudge to update `worklog.md` |
| PostToolUse Write/Edit | `*.livemd` touched | Nudge to re-run `playbill verify` |
| PostToolUse Bash | `git commit` | Quality gate (compile + format-check + credo + test). **Blocks on failure** with "next priority: fix before any other work". Dialyzer excluded for speed. |
| PostToolUse Bash | `git rebase` | Show `git log --oneline $BASE..HEAD`, flag commits not mentioning the issue |
| Stop | any | Warn about unchecked plan steps and remaining `TODO issue-{N}` comments |

See [references/quality-enforcement.md](references/quality-enforcement.md)
for the three-layer enforcement model (mechanical / semantic /
reviewer) and how the layers relate.

Hooks enforce the prose rules in the phase references — they
are belt-and-braces, not a replacement for reading the refs.
When a hook blocks (`exit 2`), treat fixing the failure as the
**highest-priority next action**. Do not start a new step, do
not respond to unrelated requests, do not commit again until
the gate passes.

## Gotchas

- **Branch naming**: The derived `ISSUE_SLUG` can produce
  unexpected names if the issue title contains special
  characters, abbreviations, or very long words. Always
  confirm the branch name with the user before creating it.
- **Wrong base branch**: Always verify the worktree was
  created from the correct base branch (usually `main` or
  `develop`) before starting work.
- **Push before confirmation**: Never push commits or create
  PRs without showing the user what will be pushed and to
  which remote/branch.
- **Foreign commits after rebase**: A rebase onto the base
  branch must NEVER introduce commits from other feature
  branches. After every rebase and before every push, run
  the post-rebase verification gate (see
  [implement-phase.md](references/implement-phase.md)).
  Show the user the full `git log --oneline <base>..HEAD`
  and confirm every commit belongs to this issue.
- **Rebase target**: Only rebase onto `origin/master` or
  `origin/main` (the PR base branch). Never rebase onto
  another feature branch without explicit user confirmation
  and a clear reason (e.g. stacked PRs).
- **Wrong tea login**: Before any tea operation, verify the
  active login matches the target Codeberg/Gitea instance
  with `tea login ls`. The git remote auto-detection usually
  handles this, but confirm if the user has multiple logins.

## Abandoning an issue

If an issue is canceled or work must stop before completion:

1. Update the worklog Session state with `**Current phase:**
   Abandoned` and a brief reason.
2. Run the **session deregister** command (see Cleanup above).
3. If a worktree was created, tell the user to remove it:
   `git worktree unlock <worktree-path> && git worktree remove <worktree-path>`
4. Do NOT delete the `.snippets/issue-{ISSUE_NUMBER}/` directory.
   The plan and worklog may be useful if work resumes later
   or for context in related issues.
