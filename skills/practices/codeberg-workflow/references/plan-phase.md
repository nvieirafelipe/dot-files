# Plan Phase Details

## Fetch issue details

Use the `tea` skill to fetch the issue:

```bash
tea issues --repo {REPO_OWNER}/{REPO_NAME} ls --state open --output json --fields index,title,body,labels,milestone,assignees | jq '.[] | select(.index == {ISSUE_NUMBER})'
```

Or view directly if tea supports it:

```bash
tea issues --repo {REPO_OWNER}/{REPO_NAME} ls --state open
```

Read the issue body, labels, milestone, and any comments.

If the issue references external resources (wiki pages, Notion
docs, etc.), ask the user to paste the content instead of
attempting to fetch them.

## Assess issue readiness

Check that the issue body follows the canonical
**WHY / WHAT / HOW / DEFINITION OF DONE / REFERENCES** structure
documented in [issue-template.md](issue-template.md). For each
section the planner expects:

- **Why?** — concrete symptom, cost of not fixing
- **What?** — user-observable outcome (no mechanism)
- **How?** — implementation strategy with decisions + rationale
- **Definition of done** — testable, observable bullets
- **Out of scope** — explicit deferrals
- **References** — external docs, related issues

Then scan for the readiness signals documented in
[issue-template.md](issue-template.md#common-gaps-to-catch-during-plan-phase-readiness-check):

1. Contradictions across sections (e.g. Why says "sync" but
   How says "async")
2. DoD bullets with no implementation slot in How?
3. Missing migration order when How? touches multiple tables
4. `OPEN:` markers — unanswered design questions
5. Missing Out-of-scope section
6. Empty References block when integrating a third-party API

If any gap is present, propose a reorganized body, present it
to the user, and push the edit via
`tea issues edit <N> --description "$(cat new-body.md)"` before
writing `plan.md`. The Codeberg issue is the canonical source
of truth — `plan.md` derives from it, not the other way
around.

If the repo has no `.gitea/ISSUE_TEMPLATE/`, offer to seed it
from [templates/](../templates/) on the next user-facing turn
that creates an issue.

## Explore the codebase

Search the repository for related code, patterns, and conventions.
Use the relevant skills (nvieirafelipe-elixir-xp, elixir-crafting,
elixir, elixir-lsp) based on what the issue
touches.
Understand the existing architecture before proposing changes.

Delegate exploration to a Task sub-agent. While it explores,
start drafting the plan structure from the issue description.

Exploration budget: the sub-agent should read at most 10-15
files directly relevant to the issue. Do not exhaustively
explore the codebase. Focus on:
- Modules directly named in the issue or acceptance criteria
- Existing patterns in the same domain area
- Test files for the modules being changed

**2-action save rule:** after every 2 search or file-read
operations during exploration, append key findings to the
worklog under a `## Exploration notes` heading before
continuing. This prevents discovery loss if the context
window compresses or the session is interrupted.

## Write the plan

Create `{SNIPPETS_DIR}/plan.md` with:

```
# issue-{ISSUE_NUMBER}: {Issue Title}

## Issue definition
{Acceptance criteria, scope, and any refinements agreed above}

## Implementation plan

- [ ] **Step 1: {Description}**
  - What to change and where
  - Typespecs: new or updated @spec for changed functions
  - Tests: what test cases to add or modify
  - Key decisions or trade-offs
  - Verification: what to run to confirm this step works

- [ ] **Step 2: {Description}**
  ...

## Decisions

| Decision | Rationale |
|----------|-----------|

## Open questions
{Anything that still needs clarification — empty if none}
```

Formatting rules:
- Max 98 characters per line in all generated code and
  documentation, break without splitting words
- Steps ordered by dependency (earlier steps unblock later ones)
- Each step is small enough to implement and verify independently
- Each step includes its own verification criteria
- Every step that changes function signatures or adds public
  functions must include typespecs in its scope
- Every step must include test cases that cover the change;
  if the step is purely structural (migration, config), the
  tests belong in the next step that exercises the new structure

Present the plan to the user for review before saving.

## Log decisions to Deciduous

If `deciduous` is on PATH and the project has a
`.deciduous/` directory, bridge the plan to the Deciduous
graph. Never run `deciduous init` without asking the user:
since 1.0.5 it requires choosing where the graph lives.

Log **before** coding, not after: the graph captures the
"why" at the moment of decision, which is lost if recorded
retroactively.

Before writing the plan, run `make deciduous-pulse` to
surface existing goals and decisions so the new plan does
not duplicate them.

1. Run `/work` with the issue title to create a Goal node
   **before implementation begins**. This is the "begin
   transaction" for decision tracking.
2. For each row in the `## Decisions` table, first run
   `/decision` to record the Options explored. Goals must
   never lead directly to Decisions — always explore Options
   first so the graph captures what you *didn't* pick and
   why. Then record the Decision made with its rationale.
3. Capture the user's original framing verbatim when
   creating Goal and Option descriptions. Summarizing loses
   the nuance that makes the graph valuable later.
4. Skip this section silently if `deciduous` is not available.

See [development-workflow.md](development-workflow.md) for the
canonical list of `make deciduous-*` targets and fallback CLI
invocations.

This keeps the plan as the readable artifact and the graph
as the queryable, cross-project knowledge base.

## Generate the Playbill notebook (solution verifier)

After the plan is saved, use the `using-playbill` skill to
build `{SNIPPETS_DIR}/plan.livemd`. This notebook is the
**solution verifier** for the issue: it starts with the plan,
grows ExUnit-driven verifier cells during implementation, and
ends as executable proof-of-work that `playbill verify` can
re-check on any checkout.

See [solution-verifier.md](solution-verifier.md) for the
mental model (inspired by
[simonw/showboat](https://github.com/simonw/showboat)),
cell conventions, and the two pass conditions that gate the
PR (zero diffs vs baseline + zero ExUnit failures).

Build the entire notebook autonomously — do not stop for
confirmation between playbill commands. Present the finished
notebook for review once at the end.

Set `NOTEBOOK="${SNIPPETS_DIR}/plan.livemd"` and build the
following structure:

1. **Init** with title `"issue-{ISSUE_NUMBER}: {Issue Title}"`.
   Include project deps so the notebook references the actual
   branch code — see "Loading project code into the notebook"
   below.
2. **Section** "Issue Definition" followed by a **note** with
   the acceptance criteria and scope.
3. **Section** "Dependency Tree" followed by a **mermaid**
   diagram showing how the plan steps relate to each other.
   Use `graph TD` with each step as a node, and edges
   showing which steps unblock which. This is always the
   first visual element after the issue definition so the
   reader understands the implementation order at a glance.
4. **Section** "Implementation Plan".
5. For each step in the plan:
   - A **note** with the step heading and description (what
     to change and where).
   - An **exec** or **code** cell showing the key change
     for this step — a module skeleton, a function signature
     with typespec, a migration snippet, or a test case.
     Prefer `exec` when the code can produce meaningful
     output (e.g. calling a function, running a query).
     Use `code` for definitions that must exist before
     later cells execute them.
   - A **mermaid** diagram when the step involves module
     interactions, data flow, or state transitions. Skip
     diagrams for trivial steps (config changes, renames).
6. **Solution Verifier (fully implemented)** — append the
   Problem Statement, per-criterion verifier cells, and
   Solution Critique placeholder exactly as specified in
   [solution-verifier.md](solution-verifier.md). **Cells are
   not skeletons.** Each AC cell is a fully implemented,
   executable assertion against compiled branch code that
   fails loudly with a message naming the missing module /
   function / value before any implementation lands. At
   plan-phase end:
   - All AC cells use `playbill exec` (not `playbill code`).
   - `playbill verify` reports zero diffs.
   - Every AC cell's recorded output is FAIL (Strategy B) or
     `N failures` with N ≥ 1 (Strategy A).
   - Every FAIL message includes the missing-artifact name:
     `FAIL AC1: ... MISSING create/3 in MyApp.NewModule`,
     not generic `assertion failed`.
   The recorded failures ARE the visible contract for Implement
   phase — a reviewer must be able to recover the to-do list
   from the notebook alone.

Every step must have at least one executable cell (`exec`
or `table`) — pure-note steps are not acceptable.

Use the `mermaid-master` skill for all diagrams. It selects
the best diagram type for each situation, validates syntax,
and ensures a preview is always generated. Max 8 nodes per
diagram. Only add diagrams that clarify beyond the text.

After building, run `playbill show` to inspect the structure.
`playbill verify` succeeds (cells re-execute and match
recorded output), but each AC cell's recorded output reports
ExUnit failures. Those failures are the to-do list for
Implement phase.

## ExUnit verifier cell pattern

Each AC verifier cell follows this four-block skeleton
verbatim. The Calculator example below is the canonical
shape; adapt the contents (modules, factories, asserts) to
the plan you are writing.

```elixir
# 1. INITIALIZE EXUNIT
ExUnit.start(autorun: false)

# 2. MODULE UNDER TEST
defmodule Calculator do
  @moduledoc """
      iex> Calculator.add(2, 3)
      5
  """
  def add(a, b), do: a + b
end

# 3. EXUNIT TEST CASE
defmodule CalculatorTest do
  use ExUnit.Case

  test "correctly adds two positive numbers" do
    assert Calculator.add(10, 5) == 15
  end
end

# 4. EXECUTE
ExUnit.run()
```

How to adapt the four blocks:

- **Block 1 (`ExUnit.start(autorun: false)`)** — verbatim, in
  every AC cell. `autorun: false` is mandatory; Livebook
  evaluates cells manually and the default autorun would fire
  before any test module is defined and run zero tests.
- **Block 2 (MODULE UNDER TEST)** — keep inline only when the
  plan introduces a brand-new module. Define it with
  `@moduledoc` containing `iex>` doctest blocks so the
  documented behavior runs as part of `ExUnit.run()`. For
  changes to existing modules, omit block 2 entirely — the
  branch code is already loaded via the `Mix.install` setup
  cell at the top of the notebook.
- **Block 3 (EXUNIT TEST CASE)** — one test module per AC.
  Follow the active XP skill's testing rules
  (`nvieirafelipe-elixir-xp` → `references/testing.md`):
  alias the module under test as `Subject`, build inputs and
  `expected` from factories that already exist in the repo,
  assert full-struct equality with the function call on the
  LEFT (`assert Subject.fun(args) == expected`).
- **Block 4 (`ExUnit.run()`)** — verbatim, in every AC cell.
  Runs both the ExUnit tests defined in block 3 and any
  doctests defined in block 2.

### Research repo assertion helpers BEFORE writing cells

Every repo invents its own assert helpers to handle the parts
bare `assert ==` cannot — autogen fields, Ecto `__meta__`
state, JSON shape, decimal precision, published events, HTTP
responses, etc. Find them before writing any cell:

```bash
grep -rnE 'def(p|macro)? assert_[a-z_]+' apps/*/test/support/ test/support/ 2>/dev/null
```

Open at least one call site for each helper that looks
relevant. Helpers vary in arity, argument order, and whether
they take keyword lists or maps — the call site teaches the
contract faster than the definition.

Decision rule for each cell:

1. If a helper matches the shape under test (persisted-row
   equality, published-event match, response equality,
   decimal equality, etc.) — **import it and use it**.
2. Otherwise, fall back to bare
   `assert Subject.fun(args) == expected` with `expected`
   built from a factory.

Both branches must respect the active XP skill's rules:
full-struct equality, function call LEFT, factories for
inputs and expected. Bare `%{...}` or `%Module{...}` literals
in a cell body are not acceptable — if a factory variant
doesn't exist for the shape, add one before writing the cell.

## Loading project code into the notebook

Use the **livebook-as-plan** pattern documented in
[`using-playbill/references/livebook-as-plan.md`](../../using-playbill/references/livebook-as-plan.md).
That reference is the single source of truth for:

- the `Mix.install` setup cell (umbrella + non-umbrella variants,
  `MIX_ENV=test`, `.env` injection, `config_path`, `lockfile`,
  `Code.append_path` for test-support factories)
- the six-section livemd skeleton (Setup → Issue Definition →
  Dependency Tree → Implementation Plan → Solution Verifier →
  Solution Critique)
- mermaid label-quoting rules (`graph TD` with `S1["..."]`)

This skill applies the pattern to **Codeberg/Gitea issues**: the
slug is `issue-{ISSUE_NUMBER}`, the file is
`{SNIPPETS_DIR}/plan.livemd`. The `Probe` helper documented in
`livebook-as-plan.md` is **not used** by this workflow — ExUnit
assertions handle the "not implemented yet" case directly (a
failing assertion IS the missing-implementation signal).

## Plan phase gate

The Plan phase is **not complete** until all three files exist
and have been presented to the user for review:

1. `{SNIPPETS_DIR}/plan.md` — implementation plan
2. `{SNIPPETS_DIR}/worklog.md` — initialized worklog
3. `{SNIPPETS_DIR}/plan.livemd` — Playbill notebook (ExUnit-driven
   solution verifier; each AC cell's recorded output reports
   `N failures` until Implement phase fills them)

Do NOT move to the Implement phase or end the conversation
until all three are created. If any file is missing, create it
before presenting the plan for review.
