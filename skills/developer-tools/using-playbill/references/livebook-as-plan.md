# LiveBook-as-Plan + Solution Verifier

The "livebook-as-plan" pattern uses a single `.livemd` file as both the
implementation plan AND the executable verifier for a story or issue.
Unlike a markdown plan, the livemd loads the actual branch code via
`Mix.install` and runs each acceptance criterion against it. When the
branch changes, the livemd's outputs change with it — drift is
immediately visible.

The eventual goal is for the livemd to **replace** `plan.md`. Today the
two coexist: plan.md is the human-curated narrative, the livemd is the
machine-verifiable proof. Once a project has run a few stories through
this pattern and the verifier shape stabilizes, drop plan.md.

## Cells are implemented during Plan phase, not afterwards

Verifier cells are **not** skeletons with `# TODO` placeholders. Every
AC cell MUST be a fully implemented assertion that runs end-to-end and
fails loudly before any implementation lands, with a message that
names the missing module / function / value. A reviewer reading the
recorded output should be able to recover the to-do list without
reading the plan.

Plan-phase gate:

- AC cells use `playbill exec` (not `playbill code`).
- `playbill verify` reports zero diffs.
- Every AC's recorded output is FAIL (Strategy B) or contains
  `N failures` with N ≥ 1 (Strategy A) before implementation.
- Every FAIL message includes the missing-artifact name verbatim:
  `FAIL AC1: ... MISSING create/5 in MyApp.NewModule`, not generic
  `FAIL AC1: assertion failed`.

When Implement phase lands a module, the corresponding `FAIL` line
flips to `PASS`. Recapture via `playbill verify` to lock the new
baseline.

## Section structure

Every livemd built from this pattern has the same six sections, in
order:

1. **Setup** — the `Mix.install` cell. No heading; this is the first
   cell of the file.
2. **Story Definition** — the acceptance criteria, copied verbatim
   from the source ticket. The contract.
3. **Dependency Tree** — a `Kino.Mermaid` `graph TD` showing how the
   plan steps unblock each other.
4. **Implementation Plan** — a markdown table (one row per step,
   columns: `#`, `Step`, `Touches`) plus an optional `sequenceDiagram`
   for the orchestrator step. This replaces the prose plan.
5. **Solution Verifier** — one narrative cell per acceptance criterion
   (see "Verifier cells" below). Driven by a `Probe` helper module.
6. **Solution Critique** — bullet list of deviations from plan,
   resolved-during-plan decisions, and out-of-scope items.

## Two setup strategies for umbrella projects

| Strategy | Best for | Trade-off |
|---|---|---|
| **A. `Mix.install` path deps** | Small/medium umbrella, no `Application.compile_env!/3` at module load, runtime.exs reads env vars Mix.install can fake | Pure notebook, portable, slow re-compile per session |
| **B. Shell into worktree via `System.cmd`** | Large umbrella, runtime.exs needs secrets, apps with compile-env injections, hundreds of files | Reuses worktree's compiled `_build`, real config, faster per-cell |

If `Mix.install` fails with `could not fetch application environment` or
`could not load module ... due to reason :nofile` for known-existing
modules, switch to Strategy B.

## Setup cell — Strategy A (Mix.install, umbrella project)

The setup cell loads the worktree's umbrella apps via path deps so
verifier cells exercise real branch code. It also wires `MIX_ENV=test`,
injects `.env` files into the OS env for `runtime.exs`, and appends
`_build/test/lib/*/ebin` to the load path so test-support factories
(which `Mix.install` skips) become available.

```elixir
worktree = "/absolute/path/to/.claude/worktrees/{branch-name}"

# Use the test profile so runtime.exs picks dev/test defaults instead
# of requiring production env vars.
System.put_env("MIX_ENV", "test")

# Inject .env values into the OS env so runtime.exs reads them.
for env_file <- ["#{worktree}/.env", "#{worktree}/.env.integration"],
    File.exists?(env_file) do
  env_file
  |> File.read!()
  |> String.split("\n", trim: true)
  |> Enum.reject(&(String.starts_with?(&1, "#") or &1 == ""))
  |> Enum.each(fn line ->
    case String.split(line, "=", parts: 2) do
      [key, value] ->
        unquoted = value |> String.trim() |> String.trim("\"") |> String.trim("'")
        System.put_env(String.trim(key), unquoted)

      _ ->
        :ok
    end
  end)
end

Mix.install(
  [
    {:kino, "~> 0.14"},
    {:core, path: "#{worktree}/apps/core"},
    {:data, path: "#{worktree}/apps/data"},
    {:entity, path: "#{worktree}/apps/entity"},
    {:common, path: "#{worktree}/apps/common"}
  ],
  config_path: "#{worktree}/config/config.exs",
  lockfile: "#{worktree}/mix.lock"
)

# `Mix.install` skips test/support paths. Append the worktree's
# compiled test-env ebins so factories are available to verifier cells.
# Run `MIX_ENV=test mix compile` in the worktree first.
for ebin <- Path.wildcard("#{worktree}/_build/test/lib/*/ebin"),
    do: Code.append_path(ebin)
```

List **only the apps the verifier cells touch.** A four-app subset is
typical even in a ten-app umbrella.

## Setup cell — Strategy B (shell into worktree)

When the worktree already has a compiled umbrella (or any Mix project
with non-trivial config/runtime.exs), skip `Mix.install` entirely.
Define a per-story helper module that shells `mix run --no-start` into
the worktree with `.env` sourced.

**Worktree prep (once per story):**

```bash
cd <worktree-root>
ln -s <main-repo>/deps deps      # share deps + _build with main repo
ln -s <main-repo>/_build _build
mix deps.get                     # sync if base lockfile differs
mix compile                      # warm umbrella cache
```

**Notebook setup cell:**

```elixir
defmodule {Slug}.Check do
  @moduledoc "Shells assertion scripts into the worktree against compiled code."

  @worktree "/absolute/path/to/.claude/worktrees/<branch>"

  def run(ac, expectation, code) do
    script = Path.join(System.tmp_dir!(), "{slug}_check.exs")
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

**Each AC cell:**

```elixir
{Slug}.Check.run("AC1", "<expectation in one sentence>", ~S'''
Code.ensure_loaded!(MyApp.NewModule)
unless function_exported?(MyApp.NewModule, :new_fn, 3) do
  raise "MISSING new_fn/3 on MyApp.NewModule"
end
''')
```

**Why this works:**
- Real umbrella code, real config, real factories all available.
- Compile cost paid once at worktree prep. Each cell = subprocess + warm BEAM.
- No `Mix.install` duplication, no compile-env workarounds.
- One helper module, every AC cell is one line of Elixir + one heredoc.

### Strategy B gotchas

- **`runtime.exs` env vars.** `mix run` triggers `config/runtime.exs`
  which often needs `PORT`, secrets, etc. Source `.env` via
  `set -a; source .env; set +a` before `mix run`.
- **Triple-single-quote sigil `~S''' ... '''`** prevents Elixir from
  interpolating `#{}` in the outer cell. Use `<>` concatenation for
  runtime interpolation inside the assertion body. `~S` skips
  interpolation; `~s` (lowercase) would still interpolate.
- **Embedding `#{}` in a heredoc that's *also* inside a `playbill exec`
  shell-quoted arg** requires double-escaping — use `<> inspect(var) <>`
  in the assertion body and skip `#{}` entirely.
- **Output trimming.** Stack traces are noisy. The helper above drops
  lines starting with `    (` or `    /` (BEAM frame markers) and
  keeps the last 4 meaningful lines. Tune per project.
- **`MIX_ENV=test` triggers recompile of unbuilt deps.** Stay on `dev`
  unless the worktree was previously compiled with `MIX_ENV=test`.

## Setup cell — non-umbrella project

```elixir
worktree = "/absolute/path/to/.claude/worktrees/{branch-name}"

System.put_env("MIX_ENV", "test")

Mix.install(
  [
    {:kino, "~> 0.14"},
    {:my_app, path: worktree}
  ],
  config_path: "#{worktree}/config/config.exs",
  lockfile: "#{worktree}/mix.lock"
)

for ebin <- Path.wildcard("#{worktree}/_build/test/lib/*/ebin"),
    do: Code.append_path(ebin)
```

`config_path` and `lockfile` are required when the project has a
`config/runtime.exs` or non-default lockfile location. Omit them only
if the project has no config.

### Picking which umbrella apps to load

Load **only** the apps whose modules the cells touch. Each extra
app costs compile time and risks compile-env failures. In
particular, apps that call `Application.compile_env!/3` at module
load (a common pattern for runtime-injected service modules) will
fail to compile outside a full `mix` project context — adding them
to `Mix.install` will halt the setup cell with messages like:

```
** (ArgumentError) could not fetch application environment
[:injections, ...] for application :core because the application
was not loaded nor configured
```

Workaround: skip that app in `Mix.install`. If a cell needs to
assert something about an unloaded app's source (e.g. "a module
attribute is unchanged"), read the source file from disk and parse
it with a regex instead of loading the module.

## Compile-time struct expansion vs `Mix.install`

`%Module.Name{}` literals expand at compile time. `Mix.install` runs
only after the surrounding script compiles, so the struct is not yet
defined and the cell fails with `__struct__/1 is undefined, cannot
expand struct Module.Name`. This bites any cell that constructs a
struct from a freshly-installed dependency.

Use `struct/2` (or the keyword-list form `struct(Module, [])`) inside
cells. It defers struct resolution to runtime, after `Mix.install`
has loaded the module.

```elixir
# Avoid in cells:
empty = %MyApp.Entity.Order{}

# Prefer:
empty = struct(MyApp.Entity.Order, [])
```

The same trick applies to `is_struct/2` guards and `case` patterns
on struct literals — rewrite them to compare on `:__struct__` if
the pattern matters at compile time.

## `playbill exec` drops the cell on raise

If a cell raises during `playbill exec`, playbill does **not**
append the cell to the livemd. Any prior `playbill note` or
`playbill section` commands that were intended to precede that cell
are also lost because they were only flushed alongside a successful
append. This destroys pre-implementation verifier cells, which are
*meant* to raise.

Use `playbill code` for any cell that will raise pre-implementation.
`code` appends the cell text without executing it, so the body
survives in the livemd and is visible to LiveBook readers.

Confirm each `code` cell fails for the right reason out-of-band by
piping the body through a standalone `elixir` script with the same
`Mix.install` header:

```bash
HEADER='Mix.install([
  {:entity, path: "/path/to/worktree/apps/entity"},
  {:data,   path: "/path/to/worktree/apps/data"}
])'
TMP=$(mktemp -d)
printf '%s\n%s\n' "$HEADER" "$CELL_BODY" > "$TMP/cell.exs"
elixir "$TMP/cell.exs"  # observe the raise message
```

Record the captured failure messages in the story worklog under a
`## Verifier baseline (pre-implement, <date>)` table — that is the
proof the verifier raises for the right reason, not for a typo.

During Implement phase, once a criterion is met, swap the cell to
`playbill exec` so the success output is recorded as the
post-implement baseline. The cell **body** must stay byte-identical
across the switch; only the playbill subcommand changes. That keeps
`playbill verify` honest as the regression gate.

## The `Probe` helper

Verifier cells must degrade gracefully before the implementation
exists. The `Probe` helper centralizes the "does this thing exist
yet?" check so cells stay readable.

```elixir
defmodule {Slug}.Probe do
  @moduledoc "Existence checks so notebook cells degrade gracefully pre-implementation."

  def field?(module, field) do
    Code.ensure_loaded?(module) and
      function_exported?(module, :__schema__, 1) and
      field in module.__schema__(:fields)
  end

  def module?(module), do: Code.ensure_loaded?(module)

  def function?(module, fun, arity) do
    Code.ensure_loaded?(module) and function_exported?(module, fun, arity)
  end
end
```

`{Slug}` is a per-story module prefix (e.g. `Issue42`).
Define `Probe` once at the top of the Solution Verifier section.

## Verifier cells (narrative pattern)

Each acceptance criterion gets a heading, a short narrative paragraph
explaining the requirement, then a code cell that runs real branch
code. There is **no test framework** and **no DSL**. The cell either:

- prints observable evidence (a struct, a computed value, a list) so
  the developer or AI agent can read it and learn the design; or
- returns `{:not_implemented, "exact missing path"}` so the gap is
  obvious without crashing the notebook.

### Cell anatomy

```markdown
### AC1 — `expires_at` + `:merchant` on schema and entity

The order expiration date lives on the order row so any consumer
(sweeper, API, reporting) can read it without a join. `:merchant`
joins `:customer` and `:admin` to mark "this order was cancelled by
the merchant."

Inspect the schema field list and the cancellation source enum directly —
these are the source of truth.
```

```elixir
schema = MyApp.Data.Schema.Order
entity = MyApp.Entity.Order

%{
  schema_has_expires_at: Issue42.Probe.field?(schema, :expires_at),
  entity_has_expires_at: Issue42.Probe.field?(entity, :expires_at),
  schema_cancellation_sources: schema.cancellation_sources(),
  entity_cancellation_sources: entity.cancellation_sources()
}
```

The narrative paragraph teaches the design. The code cell proves it.

### Graceful-degradation pattern

For criteria that depend on a function not yet implemented:

```elixir
parser = MyApp.Core.Checkout.Parser.OrderParams

if Issue42.Probe.function?(parser, :parse, 3) do
  parser.parse(cart, customer_info, "demo_order")
else
  %{
    not_implemented: "#{inspect(parser)}.parse/3 missing",
    customer_info_shape: customer_info
  }
end
```

When the implementation lands, the `else` branch falls away and the
cell starts returning the real struct. The PR-gate hook detects any
remaining `{:not_implemented, ...}` tuple and blocks the push.

### Naming and fixture conventions

- AC cell module names MUST match the modules listed in the
  Implementation Plan table. Drift between plan and verifier is the
  most common source of confusion.
- Fixtures come from existing factories — never re-declare a struct
  inline in a verifier cell. The principle is project-agnostic:
  reusing the project's fixture surface keeps the verifier honest, e.g.
  `Factory.Entity.Order.build/2` or `Factory.Response.build/2`.
- Wrap fixture-building or parser calls in `try/rescue` only when the
  factory itself may not yet exist; otherwise let the exception
  surface so the gap is loud.

## Mermaid gotchas

LiveBook renders mermaid via `Kino.Mermaid.new/1`. Two recurring
parser pitfalls:

- **Quote node labels** with spaces, colons, or punctuation:
  `S1["1. Schema: expires_at + merchant"]`. Bare labels like
  `S1[Schema: expires_at]` break the parser at the colon.
- **`graph` defaults to `LR`** in Kino. Use `graph TD` (top-down) for
  dependency trees and `sequenceDiagram` for orchestrator interaction.

## Evolving toward plan-replacement

The migration path:

1. **Today:** plan.md and the livemd coexist. plan.md is the
   human-curated source. The livemd mirrors the plan + adds verifier
   cells.
2. **After 3-5 stories on the same project:** the verifier cell
   shape stabilizes. The livemd's "Implementation Plan" table starts
   carrying the prose that used to live in plan.md.
3. **Drop plan.md:** the livemd becomes the single artifact. Update
   the workflow's plan-phase docs to skip the markdown step.
4. **Verifier-driven planning:** new stories start by writing the
   Story Definition + per-AC narrative cells with `{:not_implemented,
   "..."}` placeholders. The unimplemented tuples ARE the to-do list.

The PR-gate stays the same throughout: `playbill verify` passes AND
no cell output contains `{:not_implemented, ...}` AND the Solution
Critique has no remaining `TODO` items.
