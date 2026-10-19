# Solution Verifier (Playbill notebook)

The Playbill notebook is not just a plan mirror. It is the
**solution verifier**: executable proof that the issue is solved
correctly, and that the chosen implementation is the best available
answer.

Inspired by [simonw/showboat](https://github.com/simonw/showboat):
markdown + executed code blocks + captured output == reproducible
proof of work. `playbill verify` re-executes every cell and diffs
actual output against captured output. Drift == regression.

The notebook file is `{SNIPPETS_DIR}/plan.livemd`. Each acceptance
criterion gets one ExUnit-driven verifier cell.

## Pattern reference

The notebook structure and setup-cell template are documented
once in
[`using-playbill/references/livebook-as-plan.md`](../../using-playbill/references/livebook-as-plan.md).
Read that first. This file documents the verifier-cell shape and
the workflow-specific gates that wrap the pattern.

This workflow does **not** use the `Probe` helper from
`livebook-as-plan.md`. ExUnit handles the "not implemented yet"
case directly — a failing assertion IS the missing-implementation
signal.

## Mental model

| Layer              | Question answered                              | Where                       |
|--------------------|------------------------------------------------|-----------------------------|
| Issue Definition   | What did the issue ask for?                    | verbatim from issue         |
| Verifier cells     | Does the code meet each criterion?             | one ExUnit cell per AC      |
| Solution Critique  | Is this the best solution? What was rejected?  | note cell                   |

Each verifier cell is a self-contained ExUnit run:
`ExUnit.start(autorun: false)` → optional inline module(s) under
test → `defmodule ACNTest do use ExUnit.Case ... end` →
`ExUnit.run()`. Inputs and expected values come from factories
that already exist in the repo, never from inline literals. The
module under test is loaded via the notebook's `Mix.install`
setup cell (or defined inline when the plan introduces it
brand-new).

## The two pass conditions

The PR gate requires both. They are orthogonal: one proves the
output is stable, the other proves the output is correct.

### Pass condition 1 — Zero diffs vs baseline

Playbill records each executed cell's output directly into the
`.livemd` file (a fenced block immediately following the cell).
That recorded output IS the baseline. The baseline lives in git
alongside the notebook — the committed `.livemd` carries both
the executable cells AND their expected outputs.

`playbill verify` re-executes every cell against the current
branch code and diffs the fresh output against the recorded
output. Any cell whose fresh output differs from its recorded
output is a diff. Three things can cause a diff:

- **Regression** — implementation changed behavior the verifier
  captured earlier (fix the code).
- **Intentional refinement** — the verifier's recording was
  wrong and the new output is actually correct (re-capture via
  `playbill exec`, justify in the Solution Critique).
- **Stale recording** — the cell was last captured against an
  older branch state (re-run `playbill verify` to recapture,
  commit).

### Pass condition 2 — Zero ExUnit failures in the baseline

Every AC cell ends with `ExUnit.run()`. ExUnit prints a summary
line like `1 test, 0 failures, ...`. The gate fails if any
cell's recorded output reports `N failures` with N ≥ 1. Even
when `playbill verify` produces zero diffs, a baseline of "1
failure" is itself failing — diff-stability does not imply
correctness.

The pre-push hook scans the committed `.livemd` for the regex
`[1-9][0-9]* failure` and blocks on any hit.

## Plan phase: implement cells, capture failing baseline

**Cells are not skeletons.** Every AC cell MUST be a fully implemented
assertion that runs end-to-end and fails loudly with a message naming
the missing module / function / value before any implementation lands.
A reviewer reading the recorded output must learn exactly what is left
to build, without consulting the plan.

Workflow:

1. **Compile worktree** (Strategy B requires `mix deps.get && mix compile`
   in the worktree). For Strategy A, generate the setup cell with
   `playbill init --path-deps "..."`.
2. **Setup cell** — define the helper (`Issue{N}.Check` for Strategy B;
   `Mix.install` for Strategy A).
3. For **each** acceptance criterion:
   - A **section** with `AC{N}: <short title>`.
   - An **exec** cell with a real assertion against compiled umbrella
     code. The assertion must raise (or report a non-zero ExUnit
     summary) before implementation, and pass after.
   - The recorded output line(s) must name the artifact:
     `FAIL AC1: ... MISSING create/5 in MyApp.Core.Orders.OrderCreation`
     not generic `FAIL AC1: assertion failed`.
4. **Section** `"Solution Critique"` + placeholder note:
   ```
   * TODO: list deviations from plan after implementation.
   ```
5. **Run `playbill verify`** to lock the baseline. Confirm zero
   diffs — recorded FAIL output now matches re-run FAIL output.

**Plan-phase gate (must hold before user approves plan):**

- All AC cells exist as `playbill exec` cells (not `playbill code`).
- `playbill verify` reports zero diffs.
- The recorded output for every AC line starts with `FAIL ` (Strategy
  B) or contains `N failures` with N ≥ 1 (Strategy A).
- Every FAIL message includes the missing-artifact name verbatim
  (module path, function arity, expected value, file path).

When Implement phase lands a module, the corresponding `FAIL` line
flips to `PASS` (or `0 failures`). Recapture via `playbill verify`
to update the baseline.

## Implement phase: turn failures green

After each implementation step that makes a criterion verifiable:

1. Re-run the AC cell in Livebook (or via `playbill exec`). The
   ExUnit assertion now passes; the cell's recorded output
   reports `0 failures`.
2. Cells must use existing factories (e.g.
   `Factory.Entity.Order`, `Factory.Response`) — never
   inline `%{...}` literals or prod builders. See the active
   XP skill (`nvieirafelipe-elixir-xp`) for the testing-pre-write
   gate.
3. Cover happy path AND at least one negative path per criterion
   when the criterion involves error handling or validation.
4. Use repo-specific assertion helpers (e.g. `assert_persisted_schema`
   for DB-backed shapes) when they apply. Research before
   writing — see plan-phase.md.
5. Run `playbill verify` to capture output. The captured `0
   failures` line is the proof-of-work signature for that
   criterion.

When the final criterion turns green, replace the Solution
Critique placeholder with a real critique. If `deciduous` is on
PATH, pull the options from the graph and read the rows whose
STATUS column says `rejected`:

```bash
deciduous nodes -t option
```

Run `playbill verify` once more. Zero diffs == baseline
established. Commit the notebook so the baseline lives in git.

## PR phase: verifier is the regression gate

Both pass conditions MUST hold before a PR is opened or pushed:

1. `playbill verify "{SNIPPETS_DIR}/plan.livemd"` produces zero
   diffs.
2. `grep -nE '[1-9][0-9]* failure' "{SNIPPETS_DIR}/plan.livemd"`
   returns nothing.

The pre-push hook chain in SKILL.md enforces both.

The PR description must include a link to the verifier notebook
and one line:

> Solution verifier: `{N}` acceptance criteria, `playbill verify`
> passing at `{commit-sha}`, zero ExUnit failures in baseline.

## Playbill + umbrella project gotchas

### Two strategies for umbrella projects

| Strategy | When to use | Trade-off |
|---|---|---|
| **A. `Mix.install` path deps** | Small umbrella, no `Application.compile_env!/3` at module load, no runtime.exs requiring secrets | Pure notebook, no worktree dep |
| **B. Shell into worktree via `System.cmd`** | Large umbrella (hundreds of files, runtime.exs needs PORT/secrets, compile-env apps) | Recommended for large umbrellas — fast (compiled umbrella reused), real config, no Mix.install duplication |

### Strategy B (recommended for large umbrellas) — shell into worktree

Notebook lives in `.snippets/issue-N/` (main repo). The persistent
worktree, at `.claude/worktrees/<branch>/` under the main checkout,
has the compiled umbrella. Cells shell
into the worktree, source `.env`, run `mix run --no-start` with a
script body.

**Worktree prep (once per issue):**

```bash
cd <worktree-root>
ln -s <main-repo>/deps deps   # share deps + _build with main repo
ln -s <main-repo>/_build _build
mix deps.get                  # sync if base branch lockfile differs
mix compile                   # warm umbrella cache
```

**Notebook setup cell** (one helper module, reused by every AC cell):

```elixir
defmodule Issue{N}.Check do
  @worktree "/absolute/path/to/.claude/worktrees/<branch>"

  def run(ac, expectation, code) do
    script = Path.join(System.tmp_dir!(), "issue{N}_check.exs")
    File.write!(script, code)
    cmd = "set -a; source .env; set +a; mix run --no-start " <> script
    {out, exit_code} = System.cmd("bash", ["-c", cmd], cd: @worktree, stderr_to_stdout: true)
    File.rm(script)
    msg =
      out
      |> String.split("\n")
      |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "    (") or String.starts_with?(&1, "    /")))
      |> Enum.take(-4)
      |> Enum.join(" | ")

    case exit_code do
      0 -> IO.puts("PASS " <> ac <> ": " <> expectation)
      _ ->
        IO.puts("FAIL " <> ac <> ": " <> expectation)
        IO.puts("  > " <> msg)
    end
  end
end
:ok
```

**Each AC cell** uses `Issue{N}.Check.run/3` + sigil `~S'''` heredoc to
avoid interpolation collisions:

```elixir
Issue{N}.Check.run("AC3a", "Entity.Order.cancellation_sources/0 must return [:customer, :admin]", ~S'''
actual = MyApp.Entity.Order.cancellation_sources()
expected = [:customer, :admin]
unless actual == expected do
  raise "WRONG @cancellation_sources — expected " <> inspect(expected) <> ", got " <> inspect(actual)
end
''')
```

Recorded output is one line: `FAIL AC3a: ...` + `  > ** (RuntimeError) WRONG ...`.
Implementation lands → output flips to `PASS AC3a: ...`. `playbill verify`
diffs the line.

**Why this works:**
- Real umbrella code, real config, real factories all available.
- Compile cost paid once (umbrella cache). Each cell = subprocess + warm BEAM.
- No `Mix.install` duplication, no compile-env-failure workarounds.
- Single helper module, every AC cell is one line of Elixir + one heredoc.

### Strategy B gotchas

- **`runtime.exs` env vars.** `mix run` triggers `config/runtime.exs`
  which often needs `PORT`, `SECRET_KEY_BASE` etc. Source `.env` before
  `mix run` (the bash `set -a; source .env; set +a` pattern above).
- **`~S''' ... '''` triple-single-quote heredoc** prevents
  Elixir from interpolating `#{}` in the outer cell. Use `<>`
  concatenation for runtime interpolation inside the assertion body.
- **String escaping.** Embedding `#{}` in a heredoc that's *also*
  inside a `playbill exec "..."` shell-quoted arg requires double-
  escaping — easier to use `<> inspect(var) <>` in the assertion
  body and skip `#{}` entirely.

### Strategy A — `Mix.install` path deps (legacy)

For simpler umbrellas. Use `playbill init --path-deps "..."`:

```bash
playbill init <livemd> "<title>" \
  --path-deps "entity:$REPO/apps/entity,data:$REPO/apps/data"
```

**Rules for picking which umbrella apps to load:**

- Load **only** the apps whose modules are referenced by the cells.
  Each extra app adds compile time and risks compile-env failures.
- Skip apps that fail to compile outside the umbrella root.
  An app that calls `Application.compile_env!/3` at module load
  raises outside a `mix` project.

**Compile-time struct expansion vs `Mix.install`:** `%MyApp.Module.Name{}`
literal expands at compile time. The script compiles before
`Mix.install` runs → `__struct__/1 is undefined`. Use `struct/2`:

```elixir
# Avoid in cells:
empty = %MyApp.Entity.Order{}

# Prefer:
empty = struct(MyApp.Entity.Order, [])
```

### `playbill exec` drops the cell on raise

If the code cell raises, `playbill exec` **does not append
the cell** to the livemd. Both the code block and any
intervening section/note state since the last successful
append are lost. This bites when wiring a pre-implement
verifier whose cells are *meant* to fail their assertions
without raising.

Strategy for pre-implement verifier cells:

1. Each AC cell's ExUnit run should produce a normal
   `N failures` summary, not a raise. ExUnit assertion
   failures do NOT raise out of `ExUnit.run/0`; they are
   captured and reported in the summary line. So
   `playbill exec` records the cell cleanly with `1 test,
   1 failure` in the recorded output.
2. A raise inside a cell (e.g. `UndefinedFunctionError`
   when the module under test does not exist yet) WILL
   cause `playbill exec` to drop the cell. Guard against
   this by stubbing the function inline at plan time —
   either define the module with a function clause that
   returns a placeholder (e.g. `:not_implemented`) so the
   ExUnit assertion fails cleanly, or use `Code.ensure_loaded?/1`
   in the test setup and skip the assertion path if the
   module is missing.
3. During Implement, once a criterion is met, re-run
   `playbill exec` so the recorded `1 failure` flips to
   `0 failures`. The cell text itself stays the same — only
   the recorded output changes.

## Anti-patterns

- **Pattern-match assertions.** `assert {:ok, %Foo{x: ^x}} =
  Subject.fun(args)` ignores added fields. Use full-struct
  equality: build `expected` from a factory, assert
  `Subject.fun(args) == {:ok, expected}`.
- **Inline literals.** `%{...}` or `%Module{...}` in a cell body
  couples the notebook to the struct shape. Use a factory; add
  a variant if none exists.
- **Bare `assert ==` when a repo helper applies.** Reach for
  `assert_persisted_schema`-style helpers when the shape under
  test has autogen fields, `__meta__` state, decimal precision,
  or JSON shape concerns.
- **Faking the verifier.** If a criterion cannot be exercised by
  code (e.g. documentation-only), say so in the AC narrative and
  skip the cell — do not write a trivially-true assertion.
- **Verifier drift.** Do not edit the Issue Definition after
  Plan phase unless the issue itself changed.
- **Skipping the critique.** A passing verifier proves the code
  works. The critique proves it is the *right* solution.
