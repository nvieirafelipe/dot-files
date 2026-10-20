---
name: using-playbill
description: Generates LiveBook notebooks (.livemd) incrementally using the playbill CLI. Use when creating Elixir demos, tutorials, or interactive notebooks, or when the user mentions playbill.
---

STARTER_CHARACTER = 🎭

# Using Playbill

Playbill builds LiveBook notebooks (`.livemd`) incrementally through CLI commands. Each command reads the file, appends an entry, and writes it back.

## Prerequisites

Install as an escript:
```bash
cd playbill && mix escript.install
```

Or add as a dependency:
```elixir
{:playbill, "~> 0.1.0"}
```

## Commands

### `init <file> <title> [flags]`

Creates a new notebook.

```bash
playbill init demo.livemd "GenServer Demo" --deps kino:~>0.18.0
```

Dependency flags:
- `--deps name:version,...` — Hex packages. Version defaults to `>= 0.0.0` if omitted.
- `--path-deps name:path,...` — Local path dependencies. Path required.
- `--git-deps name:url,...` — Git dependencies. URL required.

### `section <file> <name>`

Adds a section heading.

```bash
playbill section demo.livemd "Implementation"
```

### `note <file> [text]`

Appends markdown. Reads from stdin if text is omitted.

```bash
playbill note demo.livemd "A simple counter using GenServer."
```

### `code <file> [code]`

Inserts a code cell **without executing** it. Reads from stdin if code is omitted.

```bash
cat <<'EOF' | playbill code demo.livemd
defmodule Counter do
  use GenServer
  def start_link(n), do: GenServer.start_link(__MODULE__, n, name: __MODULE__)
  def increment, do: GenServer.call(__MODULE__, :inc)
  def init(n), do: {:ok, n}
  def handle_call(:inc, _from, n), do: {:reply, n + 1, n + 1}
end
EOF
```

### `exec <file> [code]`

Executes code and embeds the output. Reads from stdin if code is omitted.

```bash
playbill exec demo.livemd "Counter.start_link(0); Counter.increment()"
```

Execution accumulates bindings — variables defined in earlier cells are available in later ones.

### `table <file> [code]`

Wraps output in a `Kino.DataTable` widget. Reads from stdin if code is omitted.

### `mermaid <file> [diagram]`

Wraps diagram in a `Kino.Mermaid` widget. Reads from stdin if diagram is omitted.

```bash
echo "graph LR; Client-->Counter-->State" | playbill mermaid demo.livemd
```

### `pop <file>`

Removes the last entry.

### `verify <file>`

Re-executes all code cells and validates outputs match what was previously recorded. Use after building a notebook to ensure correctness.

### `show <file>`

Prints the notebook to stdout.

### `extract <file>`

Outputs the CLI commands that would recreate the notebook. Useful for version control of the construction process.

## Workflow

1. `init` the notebook with title and dependencies
2. Build content with `section`, `note`, `code`, `exec`, `table`, `mermaid`
3. `verify` to confirm all code outputs are correct
4. If verify fails, use `pop` to remove the broken entry and re-add it

Structure notebooks with clear sections. Alternate between
explanatory notes and code cells to create a narrative flow.

### Autonomous operation

Build the entire notebook without stopping to ask the user
for confirmation between commands. Run all playbill commands
in sequence, then `verify` at the end. Only stop if `verify`
fails and you cannot fix it, or if a command returns a
non-zero exit code you cannot recover from.

When updating an existing notebook (adding sections,
verification cells, etc.), read the current state with
`playbill show`, decide what to append, and append it. Do
not ask the user to review intermediate steps — present the
finished notebook for review once at the end.

## Stdin pattern

Five commands accept content via stdin when the positional argument is omitted: `note`, `code`, `exec`, `table`, `mermaid`. Use heredocs or pipes for multi-line content:

```bash
cat <<'EOF' | playbill code demo.livemd
# multi-line code here
EOF
```

Use positional arguments for short, single-line content:
```bash
playbill note demo.livemd "Brief explanation."
```

## Exit codes

- `0` — success
- `1` — error (message on stderr, prefixed with `"error: "`)

## References

- [livebook-as-plan.md](references/livebook-as-plan.md) — the
  livebook-as-plan + solution-verifier pattern: setup-cell templates
  for umbrella and non-umbrella projects, the `Probe` helper,
  narrative verifier cells, mermaid gotchas, and the migration path
  from plan.md to a single livemd artifact. Read this when building a
  notebook for a story, issue, or any unit of work that has explicit
  acceptance criteria.

## Anti-patterns

- Do NOT create `.livemd` files by writing them directly. Always use playbill commands.
- Do NOT skip `verify` after building a notebook with `exec` cells.
- Do NOT pass multi-line code as positional arguments. Use stdin via heredoc or pipe instead.
- Do NOT omit `--deps` when the notebook uses external packages like Kino. The notebook will fail in LiveBook without them.
