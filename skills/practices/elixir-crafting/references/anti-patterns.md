# Elixir Anti-Patterns

These are common mistakes documented in the official Elixir
guide. When reviewing or writing code, check for these
patterns and apply the recommended fixes.

## Code anti-patterns

### Comments overuse

Commenting self-explanatory code reduces readability. Use
self-documenting names and module attributes instead.

Anti-pattern:
```elixir
# Returns the Unix timestamp of 5 minutes from now
defp unix_five_min_from_now do
  # Get the current time
  now = DateTime.utc_now()
  # Convert to Unix timestamp
  unix_now = DateTime.to_unix(now, :second)
  # Add five minutes in seconds
  unix_now + (60 * 5)
end
```

Fix — module attributes and clear naming:
```elixir
@five_min_in_seconds 60 * 5

defp unix_five_min_from_now do
  now = DateTime.utc_now()
  unix_now = DateTime.to_unix(now, :second)
  unix_now + @five_min_in_seconds
end
```

### Complex else clauses in with

Flattening all errors into a single `else` block obscures
which clause caused which error.

Fix — normalise errors in private functions, let `with`
focus on the happy path:
```elixir
def open_decoded_file(path) do
  with {:ok, encoded} <- file_read(path),
       {:ok, decoded} <- base_decode64(encoded) do
    {:ok, String.trim(decoded)}
  end
end

defp file_read(path) do
  case File.read(path) do
    {:ok, contents} -> {:ok, contents}
    {:error, _} -> {:error, :badfile}
  end
end
```

### Complex extractions in clauses

Extracting many values in function heads makes it unclear
which variables serve pattern matching vs body usage.

Fix — extract only what is needed for guards in the head,
destructure in the body:
```elixir
def drive(%User{age: age} = user) when age >= 18 do
  %User{name: name} = user
  "#{name} can drive"
end
```

### Dynamic atom creation

Atoms are not garbage collected. `String.to_atom/1` on
external input risks exhausting the atom table.

Fix — use explicit mapping or `String.to_existing_atom/1`:
```elixir
defp convert_status("ok"), do: :ok
defp convert_status("error"), do: :error
defp convert_status("redirect"), do: :redirect
```

### Long parameter lists

Functions with many parameters are hard to call correctly.

Fix — group related parameters into maps or structs:
```elixir
def loan(%User{} = user, %Book{} = book) do
  # ...
end
```

### Namespace trespassing

Libraries defining modules outside their namespace risk
conflicts. Use the package name as the namespace prefix.

Anti-pattern: `defmodule Plug.Auth` in package `:plug_auth`
Fix: `defmodule PlugAuth`

### Non-assertive map access

Using `map[:key]` for required keys lets `nil` propagate
silently. Use `map.key` or pattern matching.

### Non-assertive pattern matching

Defensive code that returns wrong values instead of crashing
hides bugs. Use pattern matching to fail fast on unexpected
input.

Anti-pattern — `Enum.at` avoids the crash but returns wrong
results:
```elixir
key_value = String.split(pair, "=")
Enum.at(key_value, 0) == desired_key && Enum.at(key_value, 1)
```

Fix — pattern match to surface malformed data:
```elixir
[key, value] = String.split(pair, "=")
key == desired_key && value
```

### Non-assertive truthiness

Using `&&`/`||`/`!` with boolean operands is unnecessarily
generic and unsafe with Erlang interop.

Fix — use `and`/`or`/`not` for booleans.

### Structs with 32+ fields

The BEAM switches struct representation from flat to hash
map at 32 fields, increasing memory and losing
optimisation.

Fix — nest optional fields in a map or group related
fields into separate structs.

## Design anti-patterns

### Alternative return types

Functions that change return type based on options create
unpredictable APIs.

Fix — create separate functions for each return type:
`parse/1` and `parse_discard_rest/1`.

### Boolean obsession

Multiple overlapping boolean options encode states poorly.

Fix — use atoms for distinct states:
```elixir
# Instead of admin: true, editor: false
role: :admin
```

### Exceptions for control flow

Using `try/rescue` for expected errors obscures intent.

Fix — use functions returning `{:ok, _}`/`{:error, _}`
tuples and handle via pattern matching.

### Primitive obsession

Using strings for complex domain concepts forces repeated
parsing throughout the codebase.

Fix — create structs with a `parse/1` function:
```elixir
defmodule Address do
  defstruct [:street, :city, :postal_code, :country]

  def parse(raw_string) do
    # ...
  end
end
```

### Unrelated multi-clause functions

Clauses handling completely different types (e.g. Product
and Animal) belong in separate functions with specific
names.

### App config for libraries

Libraries using `Application.get_env` prevent consumers
from configuring them differently.

Fix — accept configuration via function parameters or
keyword options.

## Process anti-patterns

### Code organisation by process

Using GenServer/Agent for pure computation creates
bottlenecks. Processes model runtime properties (state,
concurrency, fault isolation) — not code structure.

Fix — use plain modules and functions for logic. Let
callers decide parallelisation.

### Scattered process interfaces

Multiple modules directly calling `Agent.update/2` or
`GenServer.call/3` creates inconsistent data handling.

Fix — centralise all process interaction in one module
that enforces data format consistency.

### Sending unnecessary data

Copying large structures (like `conn`) across process
boundaries wastes CPU and memory.

Fix — extract only the data the process needs before
sending:
```elixir
ip = conn.remote_ip
spawn(fn -> log_request_ip(ip) end)
```

### Unsupervised processes

Long-running processes outside supervision trees lack
visibility, monitoring, and deterministic lifecycle.

Fix — place all processes in a supervision tree.

## Meta-programming anti-patterns

### Compile-time dependencies

Macros create compile-time dependencies, causing
unnecessary recompilation cascades.

Fix — use `Macro.expand_literals/2` to convert module
references to runtime dependencies.

### Large code generation

Macros generating excessive code bloat compilation.

Fix — delegate bulk work to regular functions, keep
`quote` blocks minimal.

### Unnecessary macros

Using macros when functions would work adds complexity
without benefit.

Fix — prefer regular functions. Macros are for syntax
transformation, not logic.

### use instead of import

`use` injects code broadly and hides dependencies.

Fix — prefer explicit `import` or `alias`. If `use` is
necessary, document its effects clearly.

### Untracked compile-time dependencies

Dynamically generated module names bypass the compiler's
dependency tracker.

Fix — use explicit module names. If dynamic generation is
necessary, do it at compile-time within macros.
