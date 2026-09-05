# Documentation — Personal Elixir

Code documentation on all modules and public functions. If skipped, justify in a comment or commit message.

## Contents
- `@moduledoc` — describe what, not how
- `@doc` + `## Examples` on every public function
- `@spec` for every public function
- Module references: `#{inspect(module)}` and `#{inspect(__MODULE__)}`
- Empty line after each example, including the last
- Realistic UUIDs in examples
- Line length 98 (matches formatter default)

## `@moduledoc`

Describe what the module is and when callers reach for it. Skip implementation detail.

```elixir
defmodule MyModule do
  @moduledoc """
  Builds and validates outbound payloads for the booking pipeline.

  Use when serialising booking events for downstream consumers.
  """
end
```

## `@doc` + `## Examples`

Every public `def` gets a `@doc` with at least:
- One-sentence description focused on what (not how).
- `## Examples` block showing **both a success path and an error path** for any function whose return type is `{:ok, _} | {:error, _}` / `:ok | {:error, _}` / `Entity.result(_)`. Both branches MUST be documented. For functions with a single return shape, one example is enough.

**Pre-PR gate**: this rule is enforced on every public function the
PR touches — new or modified. Missing `## Examples` fails the pre-PR
self-review checklist.

**Executable doctests whenever possible**: when the function is pure
and deterministic (no DB, no process state, no wall-clock / random /
PID dependencies), write the example with `iex>` prompts so `mix
test` runs it as a doctest. A passing doctest is free regression
protection and keeps the example honest:

```elixir
@doc """
Shifts `anchor` by `delta` months, clamping to day 1.

## Examples

    iex> #{inspect(__MODULE__)}.shift_month(~D[2026-04-15], 1)
    ~D[2026-05-01]

"""
```

For DB-backed / LiveView / side-effectful functions, keep the
`## Examples` block for intent. Use `iex>` prompt with the expected
return on the next line (matches upstream VEG and peer codebase
style); the doctest is not registered (no `doctest` directive in the
test file) so it renders as documentation only:

```elixir
@doc """
Returns the scope's expenses with associations preloaded.

## Examples

    iex> #{inspect(__MODULE__)}.list_expenses(scope)
    [%Expense{}, ...]

"""
```

**Never** use `#=> result` after a bare call line. That syntax is not
part of upstream VEG and does not render specially in ExDoc — it's
just a code comment. Always use the `iex>` prompt + result line form.

Reference example with executable + error paths:

```elixir
@doc """
Returns the persisted booking for the given ID.

## Examples

    iex> #{inspect(__MODULE__)}.fetch("a56dcb6a-110b-4efc-a563-178838f4143c")
    {:ok, %#{inspect(__MODULE__)}{id: "a56dcb6a-110b-4efc-a563-178838f4143c"}}

    iex> #{inspect(__MODULE__)}.fetch("00000000-0000-0000-0000-000000000000")
    {:error, :not_found}

"""
@spec fetch(binary()) :: {:ok, t()} | {:error, :not_found}
def fetch(id), do: ...
```

## `@spec` per public function

Every public function gets a `@spec`. Use custom types (`@type`) for domain concepts instead of raw primitives:

```elixir
@type booking_id :: String.t()
@type result :: {:ok, t()} | {:error, :not_found}

@spec fetch(booking_id()) :: result()
def fetch(id), do: ...
```

Specs are documentation and Dialyzer fuel.

## Module references

Use `#{inspect(module)}` when referencing an aliased module — keeps docs accurate when alias changes.

```elixir
# Avoid
@doc """
Process a `MyModule.SubModule` message.
"""

# Prefer
@doc """
Processes a `#{inspect(SubModule)}` message.
"""
```

Use `#{inspect(__MODULE__)}` when referencing current module.

```elixir
@doc """
Creates a new `#{inspect(__MODULE__)}` struct.

## Examples

    iex> #{inspect(__MODULE__)}.new()
    %#{inspect(__MODULE__)}{}

"""
```

## Empty line after each example

Blank line after each `iex>` block, including the last. Required for `mix docs` rendering and doctest detection.

## Realistic UUIDs

When function arguments are UUID-shaped strings, use realistic UUIDs — never `"abc123"` or `"some-id"`.

```elixir
# Avoid
iex> #{inspect(__MODULE__)}.fetch("abc123")

# Prefer
iex> #{inspect(__MODULE__)}.fetch("a56dcb6a-110b-4efc-a563-178838f4143c")
```

Pick a stable UUID per module (or per function) and reuse in subsequent examples.

## Line length

98 chars in `@moduledoc`/`@doc` (matches `mix format` default). Wrap long sentences manually; formatter does not reflow doc strings.
