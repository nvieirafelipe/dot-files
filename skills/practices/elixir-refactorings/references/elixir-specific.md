# Elixir-specific refactorings

Elixir-specific refactorings use programming features unique to Elixir. This group has
14 entries. Condensed from the
[Catalog of Elixir Refactorings](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md)
by Lucas Vegi and Marco Tulio Valente (MIT). Each entry links to its full text there.
The examples are upstream's code, trimmed but not corrected: read them as shapes, and
see "Caution" notes and [sources.md](sources.md#upstream-slips) for known slips.

## Contents

- [Alias expansion](#alias-expansion)
- [Default value for an absent key in a Map](#default-value-for-an-absent-key-in-a-map)
- [Defining a subset of a Map](#defining-a-subset-of-a-map)
- [Modifying keys in a Map](#modifying-keys-in-a-map)
- [Simplifying Ecto schema fields validation](#simplifying-ecto-schema-fields-validation)
- [Pipeline using "with"](#pipeline-using-with)
- [Pipeline for database transactions](#pipeline-for-database-transactions)
- [Transform nested "if" statements into a "cond"](#transform-nested-if-statements-into-a-cond)
- [Explicit a double boolean negation](#explicit-a-double-boolean-negation)
- [Transform "if" statements using pattern matching into a "case"](#transform-if-statements-using-pattern-matching-into-a-case)
- [Moving "with" clauses without pattern matching](#moving-with-clauses-without-pattern-matching)
- [Remove redundant last clause in "with"](#remove-redundant-last-clause-in-with)
- [Replace "Enum" collections with "Stream"](#replace-enum-collections-with-stream)
- [Generalise a process abstraction](#generalise-a-process-abstraction)

## Alias expansion

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L129) · Source: GLR

**When:** A multi-alias such as `alias Foo.Bar.{Baz, Boom}` saves lines, but in a large
code base it can make a dependency harder to search for. Expanding it into one `alias`
per module improves readability and traceability.

**Before:**
```elixir
alias Foo.Bar.{Baz, Boom}
```

**After:**
```elixir
alias Foo.Bar.Baz
alias Foo.Bar.Boom
```

**Side-conditions:**
- The refactoring inserts one `alias` for each module that was merged inside the `{}`,
  no more and no fewer.
- Each inserted `alias` starts with the path the merged modules shared (for example
  `Foo.Bar`), followed by a `.` and the name of one of those modules.

Example credit: the official documentation of
[Recode](https://hexdocs.pm/recode/0.6.5/Recode.Task.AliasExpansion.html) and
[ExactoKnife](https://hexdocs.pm/exacto_knife/readme.html#refactorings).

## Default value for an absent key in a Map

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L164) · Source: GLR

**When:** Code calls `Map.has_key?/2` in an `if...else` to return either the key's value
or a default. A single `Map.get/3` call does the same with less code and the same
behavior.

**Before:**
```elixir
currency =
  if(Map.has_key?(price, "currency")) do
    price["currency"]
  else
    "USD"
```

**After:**
```elixir
currency = Map.get(price, "currency", "USD")
```

**Side-conditions:**
- The code is an `if..else` statement whose condition is a call to `Map.has_key?/2`.
- The `if` branch only returns the value of the checked key, and the `else` branch only
  returns a default value for the absent key.

Example credit: Malreddy Ankanna
([source](https://medium.com/blackode/elixir-code-refactoring-techniques-33589ac56231)).

## Defining a subset of a Map

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L200) · Source: GLR

**When:** Code builds a new map from some key/value pairs of a large map by reading each
key by hand. `Map.take/2` removes the duplicated reads, cuts lines, and reads better.

**Before:**
```elixir
longitude = pickup["longitude"]
latitude = pickup["latitude"]

location = %{     # <-- Defining a subset manually
  "longitude" => longitude,
  "latitude" => latitude
}
```

**After:**
```elixir
location = Map.take(pickup, ["latitude", "longitude"])
```

**Side-conditions:**
- The original code builds a subset of a map by hand: a new map that holds only some of
  the key/value pairs of the full map.
- The list passed as the second argument to `Map.take/2` holds exactly the keys of that
  subset, as many elements as the subset had pairs.

**Caution (this skill, not upstream):** `Map.take/2` leaves out a key the map does not
have, while `pickup["latitude"]` stores `nil` for it. Without a `"latitude"` key, the
old map is `%{"latitude" => nil, "longitude" => ...}` and the new one has only
`"longitude"`. Use it when every key is present, or when readers treat a missing key and
`nil` alike.

Example credit: Malreddy Ankanna
([source](https://medium.com/blackode/elixir-code-refactoring-techniques-33589ac56231)).

## Modifying keys in a Map

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L255) · Source: GLR

**When:** Code renames a map key by chaining `Map.get`, `Map.put`, and `Map.delete`,
which takes many lines and gets worse with each key. `Map.new/2` with a multi-clause
anonymous function renames any number of keys in one pass, removes the duplicated code,
and makes the code more resilient to typing-related errors.

**Before:**
```elixir
latitude = Map.get(pickup, "latitude")    # --> step 1
pickup = Map.put(pickup, "lat", latitude) # --> step 2
pickup = Map.delete(pickup, "latitude")   # --> step 3
```

**After:**
```elixir
pickup =
  Map.new(pickup, fn
    {"latitude", lat} -> {"lat", lat}
    {key, value} -> {key, value}  # <-- Clause for unchanged keys
  end)
```

**Side-conditions:**
- The original code is a call to `Map.get`, followed by `Map.put` and `Map.delete`.
- The variables bound in the clauses of the anonymous function (for example `lat`,
  `key`, and `value`) must not share a name with a variable already defined.
- The anonymous function passed to `Map.new/2` has at least two clauses: one for each
  renamed key, and one that keeps every other key unchanged
  (`{key, value} -> {key, value}`).

**Caution (this skill, not upstream):** without a `"latitude"` key, the old code still
adds `"lat" => nil`, and the `Map.new/2` form adds nothing. If the map already holds
`"lat"`, the old code always overwrites it, while `Map.new/2` keeps whichever pair comes
last in the map's iteration order. Apply it when the old key is always present and the
new one never is.

Example credit: Malreddy Ankanna
([source](https://medium.com/blackode/elixir-code-refactoring-techniques-33589ac56231)).

## Simplifying Ecto schema fields validation

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L308) · Source: GLR

**When:** A changeset lists the schema's fields by hand for `cast` and
`validate_required/3`. The list is verbose, prone to typos, duplicates the schema, and
needs rework when the schema changes. `__schema__(:fields)` returns the non-virtual
field names, so the code keeps working when the schema changes.

**Before:**
```elixir
def changeset(attrs) do
  # Manual listing of schema fields
  schema_fields = [:carrier_time, :carrier_date, :carrier_name, :carrier_number, :carrier_terminal, :carrier_type]

  %__MODULE__{}
  |> cast(attrs, schema_fields)
  |> validate_required(schema_fields, message: "Missing Field")
end
```

**After:**
```elixir
def changeset(attrs) do

  schema_fields = __schema__(:fields)  #<-- returns dynamically the list of schema fields!

  %__MODULE__{}
  |> cast(attrs, schema_fields)
  |> validate_required(schema_fields, message: "Missing Field")
end
```

**Side-conditions:**
- The original code passes a hand-written list to `validate_required/3`.
- If that list leaves out some schema fields, the refactored code subtracts them from
  the result with `Kernel.--/2`, for example
  `__schema__(:fields) -- [:carrier_terminal, :carrier_type]`.

**Caution (this skill, not upstream):** the example breaks the second side-condition.
`__schema__(:fields)` also returns the primary key (`:id` unless the schema changes it),
which the hand-written list left out. As written, the after code casts `:id` from the
attributes and fails every changeset that has none. Subtract it:
`__schema__(:fields) -- [:id]`.

Example credit: Malreddy Ankanna
([source](https://medium.com/blackode/elixir-code-refactoring-techniques-33589ac56231)).

## Pipeline using "with"

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L371) · Source: GLR

**When:** Nested `if..else` or `case` statements sequence function calls, and the code
can become confusing. A `with` pipeline pattern-matches each call and stops at the first
mismatch; it reads better without changing any function heads, so it is less prone to
breaking changes than "Convert nested conditionals to pipeline". The resulting `with` is
itself a candidate for
[Remove redundant last clause in "with"](#remove-redundant-last-clause-in-with).

**Before:**
```elixir
defp update_game_state(%{status: :started} = state, index, user_id) do
  {move, _} = valid_move(state, index)
  if move == :ok do
    players_turn(state, user_id)
    |> case do
      {:ok, marker} -> play_turn(state, index, marker)
      other         -> other
    end
  else
    {:error, :invalid_move}
  end
end
```

**After:**
```elixir
defp update_game_state(%{status: :started} = state, index, user_id) do
  with {:ok, _}         <- valid_move(state, index),
       {:ok, marker}    <- players_turn(state, user_id),
       {:ok, new_state} <- play_turn(state, index, marker) do
    {:ok, new_state}
  else
    (other -> other)
  end
end
```

**Side-conditions:**
- Each function called in sequence inside the nested conditional must have its flow
  controlled by pattern matching, for example functions that return `{:ok, _}` or
  `{:error, _}`.

**Caution (this skill, not upstream):** the example changes one result. When
`valid_move/2` fails, the before code returns `{:error, :invalid_move}`, and the after
code returns whatever `valid_move/2` returned. Keep the original value with an `else`
clause that maps that failure back to it.

Example credit: Gary Rennie ([source](https://www.youtube.com/watch?v=V21DAKtY31Q)).

## Pipeline for database transactions

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L428) · Source: GLR

**When:** `Ecto.Repo.transaction/2` receives an anonymous function that runs a sequence
of database operations, which can make the code confusing. Building an `Ecto.Multi`
instead groups the Repo operations into a cleaner pipeline, and the transaction does not
run if the `Ecto.Multi` is invalid (any changeset has errors).

**Before:**
```elixir
def update_refused_challenges(user, count) do
  params = %{refused_challenges: user.refused_challenges + count}

  user
  |> User.update_changeset(params)
  |> Repo.update()
end

defp delete_challenges(challenges) do
  ids = Enum.map(challenges, &(&1.id))
  query = where(Challenge, [c], c.id in ^ids)
  Repo.delete_all(query)
end

defp stop_games(challenges) do
  Enum.map(challenges, &GameRegistry.delete_game(&1.id))
end

def clear_challenges(user, age \\ 300) do
  challenges = get_old_open_challenges(user, age)
  count = length(challenges)

  Repo.transaction(fn ->
    with {:ok, user} <- update_refused_challenges(user, count),
           delete_challenges(challenges),
           stop_games(challenges),
      do: user,
      else: ({:error, reason} -> Repo.rollback(reason))
  end)
end
```

**After:**
```elixir
def update_refused_challenges(user, count) do
  params = %{refused_challenges: user.refused_challenges + count}

  user
  |> User.update_changeset(params)
  #|> Repo.update()   <-- removed during refactoring!
end

defp delete_challenges(challenges) do
  ids = Enum.map(challenges, &(&1.id))
  query = where(Challenge, [c], c.id in ^ids)
  # Repo.delete_all(query) <-- removed during refactoring!
end

defp stop_games(challenges) do
  Enum.map(challenges, &GameRegistry.delete_game(&1.id))
  {:ok, :stopped_games} # <--- added during refactoring!
end

def clear_challenges(user, age \\ 300) do
  challenges = get_old_open_challenges(user, age)
  count = length(challenges)

  Ecto.Multi.new()
  |> Ecto.Multi.update(:user, update_refused_challenges(user, count))
  |> Ecto.Multi.delete_all(:challenges, delete_challenges(challenges))
  |> Ecto.Multi.run(:games, fn _ -> stop_games(challenges) end)
  |> Repo.transaction()
end
```

**Side-conditions:** None stated.

**Caution (this skill, not upstream):** besides the `Ecto.Multi.run/3` slip listed in
[sources.md](sources.md#upstream-slips), the results change. With a Multi,
`Repo.transaction/1` returns `{:ok, changes}`, a map keyed by operation name, or
`{:error, name, value, changes_so_far}`, where the old code returned `{:ok, user}` or
`{:error, reason}`. And `update_refused_challenges/2` is public: it now returns a
changeset and no longer writes. Update the callers of `clear_challenges/2` or map the
result back, and give the changeset builder its own private name.

Example credit: Gary Rennie ([source](https://www.youtube.com/watch?v=V21DAKtY31Q)).

## Transform nested "if" statements into a "cond"

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L517) · Source: GLR

**When:** Nested `if` statements test several conditions in turn, which in some
situations is verbose, deeply indented, and hard to maintain. Elixir has no `else if`,
but `cond` is logically equivalent; one `cond` removes the nesting and reads cleaner.

**Before:**
```elixir
def classify_bmi(weight, height) do
  {status, bmi} = calculate_bmi(weight, height)

  if status == :ok do
    if bmi < 18.5 do
      "Underweight"
    else
      if bmi < 25.0 do
        "Normal weight"
      else
        if bmi < 30.0 do
          "Overweight"
        else
          if bmi < 35.0 do
            "Obesity grade 1"
          else
            if bmi < 40.0 do
              "Obesity grade 2"
            else
              "Obesity grade 3"
            end
          end
        end
      end
    end
  else
    "Error in BMI calculation: #{bmi}"
  end
end
```

**After:**
```elixir
def classify_bmi(weight, height) do
  {status, bmi} = calculate_bmi(weight, height)

  if status == :ok do
    cond do
      bmi < 18.5 -> "Underweight"
      bmi < 25.0 -> "Normal weight"
      bmi < 30.0 -> "Overweight"
      bmi < 35.0 -> "Obesity grade 1"
      bmi < 40.0 -> "Obesity grade 2"
      true       -> "Obesity grade 3"
    end
  else
    "Error in BMI calculation: #{bmi}"
  end
end
```

**Side-conditions:** None stated.

## Explicit a double boolean negation

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L592) · Source: GLR

**When:** A double negation (`!!value`) casts `false` and `nil` to `false` and anything
else to `true`, but can hide the intent of the operation. A multi-clause helper function
that pattern-matches those cases states the intent; `helper/1` is an illustrative name,
so name it after its purpose in context.

**Before:**
```elixir
var_1 = true
var_2 = false
var_3 = nil
var_4 = 100

#...Use examples...
iex(1)> !!var_1
true
iex(2)> !!var_2
false
iex(3)> !!var_3
false
iex(4)> !!var_4
true
```

**After:**
```elixir
defmodule Foo do
  def helper(nil), do: false
  def helper(false), do: false
  def helper(_), do: true
end

 #...Use examples...
iex(1)> Foo.helper(var_1)
true
iex(2)> Foo.helper(var_2)
false
iex(3)> Foo.helper(var_3)
false
iex(4)> Foo.helper(var_4)
true
```

**Side-conditions:**
- The name and arity of the new function (for example `helper/1`) must not conflict with
  any function already defined in or imported by the refactored module.

Example credit: Credo's official documentation
([source](https://hexdocs.pm/credo/Credo.Check.Refactor.DoubleBooleanNegation.html)).

## Transform "if" statements using pattern matching into a "case"

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L651) · Source: GLR

**When:** An `if` condition pattern-matches (`if {:ok, contents} = ...`) to control
flow, which may compromise readability. A `case` suits pattern matching better and
leaves room to run a different block when the pattern does not match.

**Before:**
```elixir
if {:ok, contents} = File.read("foo.txt") do
  do_something(contents)
end
```

**After:**
```elixir
case File.read("foo.txt") do
  {:ok, contents} -> do_something(contents)
  _               -> do_something_else()
end
```

**Side-conditions:**
- None. Upstream calls this refactoring free of side-conditions: it applies to any `if`
  statement that pattern-matches in its condition.

**Caution (this skill, not upstream):** the two versions differ when the match fails.
The `if` raises `MatchError`, and the `case` calls `do_something_else()`. A
single-branch `case` still crashes, with `CaseClauseError`; otherwise treat the new
branch as a behavior change and test it.

Example credit: Credo's official documentation
([source](https://hexdocs.pm/credo/Credo.Check.Refactor.MatchInCondition.html)).

## Moving "with" clauses without pattern matching

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L688) · Source: GLR

**When:** A `with` starts or ends with a clause that has no `<-`, so it matches nothing
and gains nothing from the `with`, which can confuse readers. Move a leading clause to
before the `with` and a trailing clause into its body, so the clauses only chain pattern
matches; behavior stays the same.

**Before:**
```elixir
with ref = make_ref(),
     {:ok, user} <- User.create(ref),
     :ok <- send_email(user),
     Logger.debug("Created user: #{inspect(user)}") do
  user
end
```

**After:**
```elixir
ref = make_ref()  # moved outside of the 'with'

with {:ok, user} <- User.create(ref),
     :ok <- send_email(user) do
  Logger.debug("Created user: #{inspect(user)}")  # moved inside the body of the 'with'
  user
end
```

**Side-conditions:**
- The first clause, the last clause, or both do not use the `<-` operator (they match
  nothing).

Example credit: Credo's official documentation
([source](https://hexdocs.pm/credo/Credo.Check.Refactor.WithClauses.html)).

## Remove redundant last clause in "with"

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L731) · Source: MSR

**When:** The last clause of a `with` matches a pattern identical to the value the
`with` returns when every pattern matches, so the clause is redundant. Remove it and
return the expression it checked from the body instead. In a `with` without `else`,
behavior stays the same and the code is shorter and easier to read.

**Before:**
```elixir
# ...
@impl true
def handle_call({@prefix, :fetch_upload_config, name, cid}, _from, state) do
  read_socket(state, cid, fn socket, _ ->
    result =
      with {:ok, uploads} <- Map.fetch(socket.assigns, :uploads),
           {:ok, conf} <- Map.fetch(uploads, name) do  #<- redundant last clause!
        {:ok, conf}  #<- predefined value to be returned by the ``with``!
      end

    {:reply, result, state}
  end)
end
# ...
```

**After:**
```elixir
# ...
@impl true
def handle_call({@prefix, :fetch_upload_config, name, cid}, _from, state) do
  read_socket(state, cid, fn socket, _ ->
    result =
      with {:ok, uploads} <- Map.fetch(socket.assigns, :uploads) do
        Map.fetch(uploads, name) #<- predefined value to be returned by the ``with``!
      end

    {:reply, result, state}
  end)
end
# ...
```

**Side-conditions:**
- The pattern in the last clause of the `with` is lexically identical to the value its
  body returns, and the body contains only that value.

**Caution (this skill, not upstream):** apply it only to a `with` without an `else`.
With an `else`, a failed last match goes through the `else`; after the refactoring, the
body returns that value unchanged.

Example credit: an original refactoring by ByeongUk Choi
([source](https://github.com/phoenixframework/phoenix_live_view/pull/1958)).

## Replace "Enum" collections with "Stream"

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L796) · Source: MSR

**When:** A pipeline runs several eager `Enum` operations over a large collection, and
each one builds an intermediate collection. Lazy `Stream` functions build the
computations and run them only when the stream reaches an `Enum` function, which can cut
traversal time with the same result. Upstream also shows a Benchee run on a
50-million-element list in which the `Stream` version was about 12 times faster but used
more memory.

**Before:**
```elixir
defmodule Foo do
  def sum_odd_numbers(list, odd?) do
    list
    |> Enum.map(&(&1 * 3))
    |> Enum.filter(odd?)
    |> Enum.sum()
  end
end

#...Use examples...
iex(1)> Foo.sum_odd_numbers([1,2,3,4,5,6,7,8], &(rem(&1,2) != 0))
48
```

**After:**
```elixir
defmodule Foo do
  def sum_odd_numbers(list, odd?) do
    list
    |> Stream.map(&(&1 * 3))  #<- Replace "Enum" with "Stream"!
    |> Stream.filter(odd?)    #<- Replace "Enum" with "Stream"!
    |> Enum.sum()
  end
end

#...Use examples...
iex(1)> Foo.sum_odd_numbers([1,2,3,4,5,6,7,8], &(rem(&1,2) != 0))
48
```

**Side-conditions:**
- An `Enum` call in a pipeline can only be replaced by a `Stream` function that performs
  an equivalent operation.
- To keep the original behavior, the pipeline must call at least one `Enum` function
  after the inserted `Stream` calls.

**Caution (this skill, not upstream):** `Stream` takes each element through the whole
pipeline before the next, while `Enum` runs each step over all elements first. When the
functions have side effects, such as logging, or raise on a bad element, the effects run
in a different order, and some run that did not run before.

Example credit: Elixir's official documentation
([source](https://hexdocs.pm/elixir/enumerable-and-streams.html)).

## Generalise a process abstraction

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L901) · Source: MSR

**When:** A `Task` or `Agent` is used beyond its purpose, for example a `Task` that runs
as a long-lived server and keeps exchanging messages with clients. Converting it to a
`GenServer`, the generic abstraction that can do everything `Task` and `Agent` do,
removes the code smell
[GenServer Envy](https://github.com/lucasvegi/Elixir-Code-Smells?#genserver-envy) and
improves readability, since the code no longer needs explicit message passing or a
recursive loop to keep the process alive.

**Before:**
```elixir
defmodule DatabaseServer do
  use Task

  def start_link() do
    Task.start_link(&loop/0)
  end

  defp loop() do
    receive do
      {:run_query, caller, query_def} ->
        send(caller, {:query_result, run_query(query_def)})
    end
    loop()
  end

  def get(server_pid, query_def) do
    send(server_pid, {:run_query, self(), query_def})
    receive do
      {:query_result, result} -> result
    end
  end

  defp run_query(query_def) do
    Process.sleep(1000)
    "#{query_def} result"
  end
end
# ...
```

**After:**
```elixir
defmodule DatabaseServer do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, nil)
  end

  def get(server_pid, query_def) do
    GenServer.call(server_pid,{:run_query, query_def})
  end

  defp run_query(query_def) do
    Process.sleep(1000)
    "#{query_def} result"
  end

  @impl
  def handle_call({:run_query, query_def}, _, state) do
    {:reply, run_query(query_def), state}
  end
end
# ...
```

**Side-conditions:** None stated.

**Caution (this skill, not upstream):** `GenServer.call/2` waits 5 seconds by default
and then exits the caller, where the old `receive` waited forever. Each query takes a
second, so with six or more concurrent callers the later ones time out. Pass `:infinity`
or a chosen timeout as the third argument to keep the old behavior. The after code also
needs `@impl true` and an `init/1` (see [sources.md](sources.md#upstream-slips)).

Example credit: Saša Jurić, from the book "Elixir in Action, 2. ed.".
