# Coding — Personal Elixir

Style enforced by `mix format` and (where configured) `mix credo --strict`. Run on save in the editor.

## Contents
- Module attribute and directive ordering
- Alphabetical key ordering (ALL maps, structs, schemas, migrations, TypedStruct)
- Single-line functions
- Pipe operator
- Pattern matching: lookup tables, conditional logic, struct params
- Type specs and custom types
- Structs and data validation
- `with` statements
- No boolean args
- No nested `if` in `case`
- Factory aggregate naming

## Module attribute and directive ordering

Inside a module:

1. `@moduledoc`
2. `@behaviour`
3. `use` directives
4. `import` directives (alphabetical)
5. `require` directives
6. `alias` directives (alphabetical)
7. `@module_attribute`s
8. `@type` / `@typep`
9. Public functions, then private functions
10. `defguard` / callbacks (`@impl`) follow the same alphabetical-within-group rule

Public ordering applies to private equivalents (`@typep`, `defp`) — keep groups separate, public above private.

## Alphabetical key ordering — ALL maps and structs

Every map, struct, schema field declaration, migration, TypedStruct field, pattern match, and literal sorted alphabetically by key.

Reviewer eyes scan faster. Merge conflicts on field additions become trivial. Consistent across every file.

```elixir
# Avoid
%{name: "John", age: 10, email: "x@y.com"} = user
user = %User{name: "John", age: 10}

# Prefer
%{age: 10, email: "x@y.com", name: "John"} = user
user = %User{age: 10, name: "John"}
```

Same for Ecto schemas, migrations, TypedStruct, `Keyword` lists when keys are static:

```elixir
schema "users" do
  field :age, :integer
  field :email, :string
  field :first_name, :string
  field :last_name, :string
end
```

Exceptions: when order has semantic meaning (e.g. pipeline step keyword lists, explicit ordering by domain convention). Call out the exception with a comment.

## Single-line functions

Short functions stay on one line with `do:`.

```elixir
def add(a, b), do: a + b
```

When all clauses are single-line, group without blank lines. Mixed (some single, some multi-line) — separate with blank lines.

## Pipe operator

Use pipe when chain has two or more steps. Single function call: no pipe.

```elixir
# Avoid — single step
result = data |> process()

# Prefer
result = process(data)

# Prefer — two or more steps
data
|> process()
|> validate()
|> persist()
```

First item in a pipeline is a value, never a function call. If a function call is the input, assign it first.

## Pattern matching

### Lookup tables

Replace conditional dispatch with function-head pattern matching when input is one of a finite set.

```elixir
# Avoid
def role_label(role) do
  case role do
    :admin -> "Administrator"
    :editor -> "Editor"
    :viewer -> "Viewer"
  end
end

# Prefer
def role_label(:admin), do: "Administrator"
def role_label(:editor), do: "Editor"
def role_label(:viewer), do: "Viewer"
```

### Conditional logic

Push branching into function heads where possible. Reserve `case` for runtime values without a fixed shape.

### Receiving structs as parameters

Pattern-match the struct in the function head — extracts fields, asserts type at boundary.

```elixir
# Avoid
def full_name(user), do: "#{user.first_name} #{user.last_name}"

# Prefer
def full_name(%User{first_name: first, last_name: last}),
  do: "#{first} #{last}"
```

Do not mix variable assignment and conditions in pattern-matched function heads.

## Type specs and custom types

- `@spec` for every public function. Internal contracts catch drift via Dialyzer (if configured).
- `@type` for domain concepts: `@type postal_code :: String.t()` over bare `String.t()`. Names carry intent.
- `@typep` for module-internal types.

## Structs and data

- Keep structs under 32 fields. Beyond that BEAM switches from flat to hash-map representation. Group optional fields into a nested map or separate struct.
- Use structs for domain concepts. Use plain maps for transient or unstructured data.
- Validate at construction. `Foo.build(params) -> {:ok, %Foo{}} | {:error, error}`.

## `with` statements

`with` is for chaining functions that return tagged tuples. Happy path = linear sequence of `<-` arms. `else` handles joint failure space.

Flatten chained `case` into `with` + `else` when the happy path is linear.

```elixir
# Avoid
case fetch(id) do
  {:ok, x} ->
    case validate(x) do
      {:ok, v} -> persist(v)
      err -> err
    end

  err -> err
end

# Prefer
with {:ok, x} <- fetch(id),
     {:ok, v} <- validate(x) do
  persist(v)
end
```

Avoid `with` blocks with a complex `else` containing many distinct error shapes. If `else` becomes a mini case statement on different tagged errors, split into smaller functions.

## No boolean arguments

A boolean parameter to a helper is opaque at call site (`build_error(true, ...)` says nothing). Replace with:

1. **Tagged atom classifier** → function-head dispatch.
2. **Recursive single function** traversing input until match, with function heads for match / skip / exhausted.

```elixir
# Avoid
defp build_error(true, _error, key), do: already_exists(key)
defp build_error(false, error, _key), do: log_and_build(error)

# Prefer — tagged atom
defp build_error(:already_exists, _error, key), do: already_exists(key)
defp build_error(:unexpected, error, _key), do: log_and_build(error)

# Or — recursive traversal
defp build_error([:unique | _], _error, key), do: already_exists(key)
defp build_error([_ | rest], error, key), do: build_error(rest, error, key)
defp build_error([], error, _key), do: log_and_build(error)
```

## Factory aggregate naming

Module path carries context. Don't repeat domain name in inner factory key.

```elixir
# Avoid — name repeats
Factory.Entity.Booking.build(:booking_record, ...)

# Prefer — aggregate + role
Factory.Entity.Booking.build(:confirmed, ...)
Factory.Entity.Booking.build(:cancelled, ...)
```

Subfactories for the same aggregate live together under one module.
