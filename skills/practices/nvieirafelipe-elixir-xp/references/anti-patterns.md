# Anti-patterns — Personal Elixir

Recurring patterns that surface in review. Each entry: the smell, why it hurts, the fix.

## Contents
- Pattern matching in assertions
- Per-field assertions on tuples or lists
- Production code in test setup
- Generic `:ok` mock returns
- Boolean arguments switching behaviour
- Inline struct/map construction in tests
- Unsorted struct/map/schema keys
- `with` blocks with sprawling `else`
- Pipe operator on a single function call
- `String.to_atom/1` on external input

## Pattern matching in assertions

```elixir
# Avoid — only matched fields are checked; new fields silently ignored
assert {:ok, %Entity.Foo{} = inserted} = Subject.insert(params)
assert inserted.field == expected
```

Why: pattern matching ignores fields not in the pattern. If `Foo` adds `field_b`, the test still passes when the function fails to set it. Failure messages from pattern-match mismatches are also harder to read than equality diffs.

Fix: build expected via factory, assert full equality.

```elixir
expected = Factory.Entity.build(:foo, field: expected)
assert Subject.insert(params) == {:ok, expected}
```

## Per-field assertions on tuples or lists

```elixir
# Avoid
assert length(items) == 2
assert Enum.at(items, 0).name == "a"
assert Enum.at(items, 1).name == "b"
```

Why: same problem as pattern-matched fields. Also: noisy.

Fix:

```elixir
assert items == [
  Factory.Item.build(:item, name: "a"),
  Factory.Item.build(:item, name: "b")
]
```

## Production code in test setup

```elixir
# Avoid
expected = Entity.Booking.build(%{id: id, status: :confirmed})
```

Why: production builders evolve for runtime concerns. Tests coupled to them break for unrelated reasons. Spreads struct knowledge across test files.

Fix: factory.

```elixir
expected = Factory.Entity.Booking.build(:booking, id: id, status: :confirmed)
```

Exception: the function under test itself.

## Generic `:ok` mock returns

```elixir
# Avoid — spec returns {:ok, entity}; mock shortcircuits
expect(Subject.Foo, :insert, fn _params -> :ok end)
```

Why: contract drift between caller and callee passes the test. When the real implementation returns `{:ok, entity}` and a caller depends on it, the test silently lies.

Fix: return per-spec values.

```elixir
expected = Factory.Entity.build(:foo)
expect(Subject.Foo, :insert, fn _params -> {:ok, expected} end)
```

## Boolean arguments switching behaviour

```elixir
# Avoid
defp build_error(true, _error, key), do: already_exists(key)
defp build_error(false, error, _key), do: log_and_build(error)
```

Why: `build_error(true, ...)` at call site says nothing about what `true` means. Reader has to jump to definition.

Fix: tagged atoms or recursive function heads.

```elixir
defp build_error(:already_exists, _error, key), do: already_exists(key)
defp build_error(:unexpected, error, _key), do: log_and_build(error)
```

## Inline struct or map construction in tests

```elixir
# Avoid — bare struct literal
expected = %Entity.Booking{
  id: id,
  status: :confirmed,
  customer: %Entity.Customer{id: cid, email: "x@y.com"}
}

# Avoid — bare map literal
detail = %{
  data: %{offer: %{token: "t"}},
  metadata: %{correlation_id: "c", idempotency_key: "i"}
}
```

Why: same problem as production builders — spreads shape knowledge. Inline literals drift from production shapes.

Fix: factory. Add one if missing.

```elixir
expected = Factory.Entity.Booking.build(:confirmed, id: id, customer_id: cid)
detail = EventsFactory.Consumer.build(:create_booking_detail)
```

Applies to ALL maps and structs in tests — inputs and expected values.

## Unsorted struct/map/schema keys

```elixir
# Avoid
%{name: "John", age: 10, email: "x@y.com"} = user

schema "users" do
  field :first_name
  field :last_name
  field :age, :integer
end
```

Why: slower to scan; merge conflicts on field additions become non-trivial.

Fix: alphabetical order, across ALL maps and structs (not only schemas).

```elixir
%{age: 10, email: "x@y.com", name: "John"} = user

schema "users" do
  field :age, :integer
  field :first_name
  field :last_name
end
```

## `with` blocks with sprawling `else`

```elixir
# Avoid
with {:ok, x} <- step_a(),
     {:ok, y} <- step_b(x),
     {:ok, z} <- step_c(y) do
  z
else
  {:error, :a_problem} -> handle_a()
  {:error, :b_problem} -> handle_b()
  {:error, %Ecto.Changeset{} = cs} -> handle_changeset(cs)
  {:error, %{type: :timeout}} -> handle_timeout()
  err -> handle_anything()
end
```

Why: `with` becomes a hidden case statement on disjoint error shapes. Reader must trace which step produced which error.

Fix: split into smaller functions, each with a tighter `with` and focused `else`. Or explicit pattern matching on each step.

## Pipe operator on a single function call

```elixir
# Avoid
result = data |> process()
```

Why: pipe earns its keep across multiple steps; one-step pipes are visual noise.

Fix:

```elixir
result = process(data)
```

## `String.to_atom/1` on external input

```elixir
# Avoid
status = String.to_atom(params["status"])
```

Why: atoms are not garbage collected. External input under attacker control can exhaust the atom table and crash the BEAM.

Fix: `String.to_existing_atom/1`, or map known strings explicitly.

```elixir
status =
  case params["status"] do
    "in_progress" -> :in_progress
    "completed" -> :completed
    _ -> nil
  end
```
