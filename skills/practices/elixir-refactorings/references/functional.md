# Functional refactorings

Functional refactorings use programming features characteristic of functional languages,
such as pattern matching and higher-order functions. This group has 32 entries.
Condensed from the [Catalog of Elixir
Refactorings](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md)
by Lucas Vegi and Marco Tulio Valente (MIT). Each entry links to its full text there.
The examples are upstream's code, trimmed but not corrected: read them as shapes, and
see "Caution" notes and [sources.md](sources.md#upstream-slips) for known slips.

## Contents

- [Generalise a function definition](#generalise-a-function-definition)
- [Introduce pattern matching over a
  parameter](#introduce-pattern-matching-over-a-parameter)
- [Turning anonymous into local functions](#turning-anonymous-into-local-functions)
- [Merging multiple definitions](#merging-multiple-definitions)
- [Splitting a definition](#splitting-a-definition)
- [Inline macro](#inline-macro)
- [Transforming list appends and subtracts](#transforming-list-appends-and-subtracts)
- [From tuple to struct](#from-tuple-to-struct)
- [Struct guard to matching](#struct-guard-to-matching)
- [Struct field access elimination](#struct-field-access-elimination)
- [Equality guard to pattern matching](#equality-guard-to-pattern-matching)
- [Static structure reuse](#static-structure-reuse)
- [Simplifying guard sequences](#simplifying-guard-sequences)
- [Converts guards to conditionals](#converts-guards-to-conditionals)
- [Widen or narrow definition scope](#widen-or-narrow-definition-scope)
- [Introduce Enum.map/2](#introduce-enummap2)
- [Merging match expressions into a list
  pattern](#merging-match-expressions-into-a-list-pattern)
- [Function clauses to/from case clauses](#function-clauses-tofrom-case-clauses)
- [Transform a body-recursive function to a
  tail-recursive](#transform-a-body-recursive-function-to-a-tail-recursive)
- [Eliminate single branch](#eliminate-single-branch)
- [Transform to list comprehension](#transform-to-list-comprehension)
- [Nested list functions to comprehension](#nested-list-functions-to-comprehension)
- [List comprehension simplifications](#list-comprehension-simplifications)
- [Closure conversion](#closure-conversion)
- [Replace pipeline with a function](#replace-pipeline-with-a-function)
- [Remove single pipe](#remove-single-pipe)
- [Simplifying pattern matching with nested
  structs](#simplifying-pattern-matching-with-nested-structs)
- [Improving list appending performance](#improving-list-appending-performance)
- [Convert nested conditionals to pipeline](#convert-nested-conditionals-to-pipeline)
- [Replacing recursion with a higher-level
  construct](#replacing-recursion-with-a-higher-level-construct)
- [Replace a nested conditional in a "case" statement with
  guards](#replace-a-nested-conditional-in-a-case-statement-with-guards)
- [Replace function call with raw value in a pipeline
  start](#replace-function-call-with-raw-value-in-a-pipeline-start)

## Generalise a function definition

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L2516)

**When:** Functions in one module have equivalent expression structures, the Duplicated
Code smell. Generalize the shared structure into a new function, higher-order where the
varying parts are functions, and call it from the original bodies, so the expressions
are maintained in one place.

**Before:**
```elixir
defmodule Gen do
  def foo(list) do
    list_comprehension = for x <- list, do: x * x

    list_comprehension
    |> Enum.map(&(&1 * 3))
  end

  def bar(list) do
    list_comprehension = for x <- list, do: x + x

    list_comprehension
    |> Enum.filter(&(rem(&1, 4) == 0))
  end
end
# ...
```

**After:**
```elixir
defmodule Gen do
  def generic(list, generator_op, trans_op, trans_args) do
    list_comprehension = for x <- list, do: generator_op.(x,x)

    list_comprehension
    |> trans_op.(trans_args)
  end

  def foo(list) do
    # Body replaced
    generic(list, &Kernel.*/2, &Enum.map/2, &(&1 * 3))
  end

  def bar(list) do
    # Body replaced
    generic(list, &Kernel.+/2, &Enum.filter/2, &(rem(&1, 4) == 0))
  end
end
# ...
```

**Side-conditions:**
- The name and arity of the new function (e.g. `generic/4`) must not conflict with any
  function already defined or imported by the module.
- The generalized functions must originally be defined in the same module.
- The arity of the new function must equal the number of groups of generalizable code
  elements in the equivalent expressions.
- The expressions to generalize are not patterns and do not call the function that
  contains them (recursive calls).
- The extracted expressions must not be part of a macro definition.

## Introduce pattern matching over a parameter

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L2601)

**When:** A function picks a branch from its parameter values with a classic conditional
(`if`, `unless`, `cond`, `case`), and its body grows into a Long Function. Replace the
conditional with a multi-clause function that pattern matches on the parameters, one
clause per branch. Callers do not change.

**Before:**
```elixir
def fibonacci(n) when is_integer(n) do
  case n do
    0 -> 0
    1 -> 1
    _ -> fibonacci(n-1) + fibonacci(n-2)
  end
end
# ...
```

**After:**
```elixir
def fibonacci(0), do: 0
def fibonacci(1), do: 1
def fibonacci(n) when is_integer(n) do
  fibonacci(n-1) + fibonacci(n-2)
end
# ...
```

**Side-conditions:**
- The function must have parameters whose values decide which internal branch runs;
  after the refactoring, the clauses pattern match on them.
- The multi-clause function must have as many clauses as the original function had
  branches.
- The patterns must use the same expressions the conditionals originally evaluated.

## Turning anonymous into local functions

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L2653)

**When:** The same anonymous function is defined at several points (Duplicated Code).
Anonymous functions are less reusable than local functions and cannot be exported, so
lift the anonymous function into a local function and update the original sites to use
it. Upstream also calls this lambda lifting, a specific instance of Extract Function.

**Before:**
```elixir
defmodule Lambda do
  def foo(list) do
    Enum.map(list, fn x -> x * 2 end)
  end

  def bar(list) do
    Enum.map_every(list, 3, fn x -> x * 2 end)
  end
end
# ...
```

**After:**
```elixir
defmodule Lambda do
  def double(x) do  #<- lambda lifted to a local function!
    x * 2
  end

  def foo(list) do
    Enum.map(list, &double/1)
  end

  def bar(list) do
    Enum.map_every(list, 3, &double/1)
  end
end
# ...
```

**Side-conditions:**
- The duplicated anonymous functions must be defined in the same module.
- The duplicated anonymous functions may use the `fn` and `end` syntax (e.g. `fn x -> x
  * 2 end`) or the equivalent `&` syntax (e.g. `&(&1 * 2)`).
- The name and arity of the new local function (e.g. `double/1`) must not conflict with
  any function already defined or imported by the module.

## Merging multiple definitions

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L2721)

**When:** Complementary functions, such as `take/2` and `drop/2`, contain near-identical
code (Duplicated Code). Merge them into one function that returns a tuple holding each
original result in its own element; the code is shared and the same data structure is
not traversed several times. Upstream also calls this tupling.

**Before:**
```elixir
defmodule MyList do
  def take(0, _), do: []
  def take(_, []), do: []
  def take(n, [h | t]) when n > 0 do
    [h | take(n-1, t)]
  end
  def take(_, _), do: :error_take_negative

  def drop(0, list), do: list
  def drop(_, []), do: []
  def drop(n, [h | t]) when n > 0 do
    drop(n-1, t)
  end
  def drop(_, _), do: :error_drop_negative
end
# ...
```

**After:**
```elixir
defmodule MyList do
  # ...

  # Merging take and drop!
  def split_at(0, list), do: {[], list}
  def split_at(_, []), do: {[], []}
  def split_at(n, [h | t]) when n > 0 do
    {ts, zs} = split_at(n-1, t)
    {[h | ts], zs}
  end
  def split_at(_, _), do: {:error_take_negative, :error_drop_negative}
end

# ...
iex(1)> {take, drop} = MyList.split_at(2, [1,2,3,4,5,6])
# ...
```

**Side-conditions:**
- The merged functions should preferably be defined in the same module, which keeps the
  behavior and the cohesion of the codebase.
- If calls to the original functions are replaced with calls to the new function,
  pattern matching must extract the wanted value from the returned tuple to keep the
  original behavior.

Example credit: Haskell code in two papers
([1](https://dl.acm.org/doi/10.1145/1706356.1706378),
[2](https://www.cs.kent.ac.uk/pubs/2010/3009/index.html)).

## Splitting a definition

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L2823)

**When:** A recursive function returns a tuple. Split it into new recursive functions,
each generating one element of the original tuple.

No code example upstream; it points to the [Merging multiple
definitions](#merging-multiple-definitions) example read from After to Before.

**Side-conditions:**
- The function must return a tuple with as many elements as the number of new functions
  to create.
- The new recursive functions must not conflict with functions of the same name and
  arity already defined or imported by the module.

**Reverse:** Upstream calls this the inverse of [Merging multiple
definitions](#merging-multiple-definitions).

## Inline macro

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L2841)

**When:** A macro solves a problem that a function or an existing language construct
could solve, which makes the code more complex and less readable (the Unnecessary Macros
smell). Replace every call with the macro's body, adjusted to work outside the macro,
then delete the macro. Upstream calls this a specialization of Inline function.

**Before:**
```elixir
defmodule MyMacro do
  defmacro sum_macro(v1, v2) do
    quote do
      unquote(v1) + unquote(v2)
    end
  end
end

defmodule Foo do
  def bar(v1, v2) do
    require MyMacro
    MyMacro.sum_macro(v1, v2)
  end
end
# ...
```

**After:**
```elixir
defmodule Foo do
  def bar(v1, v2) do
    v1 + v2   #<- inlined macro!
  end
end
# ...
```

**Side-conditions:**
- The macro body must not contain variables whose names conflict with variables already
  in scope where the macro is called.
- The macro must not call another macro in its definition.
- When the body replaces the calls, remove constructs such as `quote/2` and `unquote/1`,
  which a conventional function does not need.

## Transforming list appends and subtracts

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L2906)

**When:** Code calls `Enum.concat/2` to append to a list or `Enum.reject/2` to subtract
elements from one. Replace the calls with the `Kernel.++/2` and `Kernel.--/2` operators,
which can make the code shorter and more readable.

**Before:**
```elixir
iex(1)> Enum.concat([1, 2, 3, 4], [5, 6, 7])
[1, 2, 3, 4, 5, 6, 7]

iex(2)> Enum.reject([1, 2, 3, 4, 5], &(Enum.member?([1, 3], &1)))
[2, 4, 5]
```

**After:**
```elixir
iex(1)> [1, 2, 3, 4] ++ [5, 6, 7]
[1, 2, 3, 4, 5, 6, 7]

iex(2)> [1, 2, 3, 4, 5] -- [1, 3]
[2, 4, 5]
```

**Side-conditions:**
- The left operand of `++` must be the list originally passed first to `Enum.concat/2`,
  and the right operand the list passed second.
- The left operand of `--` must be the list originally passed first to `Enum.reject/2`,
  and the right operand the list inside the anonymous function passed second.

**Caution (this skill, not upstream):** `--` removes one occurrence per element on its
right, while the `Enum.reject/2` form removes every occurrence: `[1, 2, 1] -- [1]` is
`[2, 1]`, and the reject form gives `[2]`. Subtract with `--` only when the left list
has no duplicates of what is removed.

## From tuple to struct

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L2944)

**When:** Code passes a tuple whose elements cannot be named, which exposes details of
the data representation and makes the code less readable. Replace the tuple with a
struct, whose named fields give the data a more abstract interface.

**Before:**
```elixir
defmodule Order do
  def discount(tuple, value) do
    put_elem(tuple, 2, elem(tuple, 2) * value)
  end
end
# ...
```

**After:**
```elixir
defmodule Order do
  defstruct [id: nil, customer: nil, date: nil, total: nil]

  def discount(order, value) do
    %Order{order | total: order.total * value}
  end
end
# ...
```

**Side-conditions:**
- The module that holds the tuple must not already define a struct.
- The struct field names must be atoms, and therefore all unique.

## Struct guard to matching

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L2994)

**When:** A guard calls `is_struct/1` or `is_struct/2` for a check that pattern matching
alone can do, which makes the code verbose and less readable. Replace the guard with a
struct pattern on the parameter.

**Before:**
```elixir
defmodule Order do
  def discount(struct, value) when is_struct(struct, Order) do
    %Order{struct | total: struct.total * value}
  end
end
# ...
```

**After:**
```elixir
defmodule Order do
  def discount(%Order{} = struct, value) do
    %Order{struct | total: struct.total * value}
  end
end
# ...
```

**Side-conditions:**
- To keep the behavior, an instance of the struct that `is_struct` checked (e.g.
  `%Order{}`) goes on the left of the match operator on the parameter the guard
  validated (e.g. `struct`).

## Struct field access elimination

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L3044)

**When:** A function accesses struct fields directly, in its guard or its body. Extract
the field into a variable by pattern matching and use the variable instead, which
reduces code size; the more direct accesses, the larger the reduction. When the fields
are accessed exclusively in the signature or the body, take care not to introduce the
Complex extractions in clauses smell.

**Before:**
```elixir
defmodule Order do
  def discount(%Order{} = struct, value) when struct.total >= 100.0 do
    %Order{struct | total: struct.total * value}
  end
end
# ...
```

**After:**
```elixir
defmodule Order do
  def discount(%Order{total: t} = struct, value) when t >= 100.0 do
    %Order{struct | total: t * value}
  end
end
# ...
```

**Side-conditions:**
- The new variable's name must not conflict with parameters or local variables the
  function already defines.

## Equality guard to pattern matching

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L3092)

**When:** A variable extracted from a struct field is used only in an equality
comparison in a guard. Remove the variable and match the compared value directly in the
pattern. This further reduces code produced by [Struct field access
elimination](#struct-field-access-elimination).

**Before:**
```elixir
defmodule Order do
  def discount(%Order{total: t, customer: c} = s, value) when t >= 100.0 and c == "Jose" do
    %Order{s | total: t * value}
  end
end
# ...
```

**After:**
```elixir
defmodule Order do
  def discount(%Order{total: t, customer: "Jose"} = s, value) when t >= 100.0 do
    %Order{s | total: t * value}
  end
end
# ...
```

**Side-conditions:**
- The variable must have been extracted from a composite data type (e.g. list, tuple,
  map or struct) in a function clause.
- Before the refactoring, the variable is used only in an equality comparison in a
  guard.
- After the refactoring, the value it was compared with replaces the variable where it
  was extracted.

**Caution (this skill, not upstream):** a pattern compares strictly, while `==` treats
`1.0` and `1` as equal. When the constant is a number, replace `x == 1` with the pattern
`1` only if the field cannot hold `1.0`.

## Static structure reuse

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L3146)

**When:** A function rebuilds identical tuples or lists at several points. Upstream says
the recreation makes the code more verbose, takes more memory and can lead to less
efficient runtime. Bind each structure to a variable, for example by pattern matching in
the function clause, and reuse the variable.

**Before:**
```elixir
defmodule Order do
  def check({paid, [:car, :house, i]}) do
    case paid do
      true -> [:car, :house, i]
      false -> {paid, [:car, :house, i]}
    end
  end
end
# ...
```

**After:**
```elixir
defmodule Order do
  def check({paid, [:car, :house, _i] = list} = tuple) do
    case paid do
      true -> list    # <= reuse!
      false -> tuple  # <= reuse!
    end
  end
end
# ...
```

**Side-conditions:**
- The new variables' names must not conflict with existing variables.
- The structures replaced by variables must originally be lexically identical.

## Simplifying guard sequences

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L3206)

**When:** A guard holds redundant propositions, such as a type check beside a comparison
that already implies the type. Upstream says this does not change behavior but can make
the code more verbose and inefficient. Remove the redundant propositions.

**Before:**
```elixir
defmodule Foo do
  def bar(f) when is_float(f) and f == 81.0 do
    {:float, f}
  end

  def bar(l) when is_list(l) and length(l) > 2 do
    {:list, l}
  end
end
# ...
```

**After:**
```elixir
defmodule Foo do
  def bar(f) when f === 81.0 do
    {:float, f}
  end

  def bar(l) when length(l) > 2 do
    {:list, l}
  end
end
# ...
```

**Side-conditions:**
- The expressions to simplify must be in guards, of `case` statements or of function
  clauses.
- To count as redundant, the expressions must do one of the following:
  - Check the type of a simple value (e.g. integer, float or atom) and also compare it
    for equality with a constant.
  - Check the type of a composite value (e.g. list, tuple, bitstring or map) and also
    compare it with a constant in a way that checks the type too. For example,
    `byte_size/1`, `tuple_size/1` and `map_size/1` return sizes and also check for a
    bitstring, tuple or map.

**Caution (this skill, not upstream):** the example also swaps `==` for `===`, which
the type check made safe for `81.0`. Since Erlang/OTP 27, `===` tells `-0.0` from `0.0`
and `==` does not, so `is_float(f) and f == 0.0` does not reduce to `f === 0.0`: only
the first accepts `-0.0`.

## Converts guards to conditionals

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L3281)

**When:** A multi-clause function tells its clauses apart with guards. Replace all the
guards with a traditional conditional in a single clause. Upstream warns that the error
handling needed to keep the behavior, together with merging the clauses, may turn the
result into a Long Function.

**Before:**
```elixir
defmodule Foo do
  def bar(f) when f === 81.0 do
    {:float, f}
  end

  def bar(l) when length(l) > 2 do
    {:list, l}
  end
end
# ...
```

**After:**
```elixir
defmodule Foo do

  def bar(v) do
    try do
      cond do
        v === 81.0 -> {:float, v}
        length(v) > 2 -> {:list, v}
        true -> raise FunctionClauseError
      end
    rescue
      _e in ArgumentError -> raise FunctionClauseError
    end
  end

end
# ...
```

**Side-conditions:**
- The guards turned into `cond` clauses must originally tell apart the clauses of a
  multi-clause function.
- Error handling may be needed to keep the original behavior. An error raised inside a
  guard only makes the guard false, but the same expression in a conditional propagates
  it, as with `Kernel.length/1` on a non-list, which raises `ArgumentError`.

**Caution (this skill, not upstream):** a bare `raise FunctionClauseError` carries no
module, function or arity, so its message reads only "no function clause matches".
Raise `FunctionClauseError, module: __MODULE__, function: :bar, arity: 1` to keep the
original error.

## Widen or narrow definition scope

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L3363)

**When:** Elixir has no nested named functions, but a named function can define a nested
anonymous function whose scope is narrowed to its body. Widen the scope by turning the
anonymous function into a named function outside it and replacing its calls, or narrow a
named function's scope the other way.

**Before:**
```elixir
defmodule Foo do
  def bar(v1, v2, v3) do
    my_div = fn
      (_, 0) -> {:error, "invalid!"}
      (x, y) -> {:ok, x/y}
    end

    case my_div.(v1, v2) do
      {:error, msg} -> msg
      {:ok, value} -> value * v3
    end
  end
end

# ...
iex(3)> my_div.(10, 2)
warning: variable "my_div" does not exist...
** (CompileError) undefined function my_div/0...
```

**After:**
```elixir
defmodule Foo do
  def bar(v1, v2, v3) do
    case my_div(v1, v2) do
      {:error, msg} -> msg
      {:ok, value} -> value * v3
    end
  end

  # new multi-clause named function with widened scope!
  def my_div(_, 0), do: {:error, "invalid!"}
  def my_div(x, y), do: {:ok, x/y}
end

# ...
iex(3)> Foo.my_div(10, 2)
{:ok, 5.0}
# ...
```

**Side-conditions:**
- When widening, the name and arity of the new named function (e.g. `my_div/2`) must not
  conflict with any function already defined or imported by the module.
- When widening, the anonymous function must not be a closure: it must not access
  variables outside its scope.

**Reverse:** Narrowing the scope is the reverse refactoring: upstream's example read
from After to Before.

## Introduce Enum.map/2

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L3442)

**When:** A list expression generates each element by calling the same function. Replace
it with a call to `Enum.map/2`; upstream's aim is to restructure divide-and-conquer
functions so they are easier to parallelize. The result enables [Transform to list
comprehension](#transform-to-list-comprehension).

**Before:**
```elixir
defmodule Foo do
  def bar(list, list_2) do
    [merge_sort(list), merge_sort(list_2)]
  end
end
# ...
```

**After:**
```elixir
defmodule Foo do
  def bar(list, list_2) do
    Enum.map([list, list_2], &merge_sort/1)
  end
end
# ...
```

**Side-conditions:**
- The function that generates each element (e.g. `merge_sort/1`) must be pure, without
  side effects.

## Merging match expressions into a list pattern

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L3490)

**When:** A function has a series of match expressions. Merge them into a single match
expression with a list pattern; upstream's aim is to restructure divide-and-conquer
functions so they are easier to parallelize. The result enables [Introduce
Enum.map/2](#introduce-enummap2).

**Before:**
```elixir
defmodule Foo do
  def bar(list, list_2) do
    e_1 = merge_sort(list)
    e_2 = merge_sort(list_2)

    # do something with e_1 and e_2 ...
  end
end
```

**After:**
```elixir
defmodule Foo do
  def bar(list, list_2) do
    [e_1, e_2] = [merge_sort(list), merge_sort(list_2)]

    # do something with e_1 and e_2 ...
  end
end
```

**Side-conditions:**
- The functions in the match expressions must be pure, without side effects. The series
  may call several different functions, not only one as in the example.

## Function clauses to/from case clauses

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L3537)

**When:** A multi-clause function can become a single-clause function by mapping its
function clauses into the clauses of a `case` statement. Upstream's aim is to
restructure divide-and-conquer functions so they are easier to parallelize.

**Before:**
```elixir
defmodule Foo do
  def merge_sort([]), do: []    #<= base case
  def merge_sort([h]), do: [h]  #<= base case

  def merge_sort(list) do       #<= recursive case
    half = length(list) |> div(2)
    right = merge_sort(Enum.take(list, half))
    left = merge_sort(Enum.drop(list, half))
    merge(right, left)
  end
end
# ...
```

**After:**
```elixir
defmodule Foo do
  def merge_sort(list) do
    case list do
      []  -> []
      [h] -> [h]
      _   ->  half = length(list) |> div(2)
              right = merge_sort(Enum.take(list, half))
              left = merge_sort(Enum.drop(list, half))
              merge(right, left)
    end
  end
end
# ...
```

**Side-conditions:**
- When the clauses are unified into one `case` statement, it is ideal that the original
  clauses define no identically named variables, which would conflict after unification.

**Reverse:** Upstream says the refactoring also runs the other way: `case` clauses map
into function clauses, turning a single-clause function into a multi-clause one (see
[Introduce pattern matching over a
parameter](#introduce-pattern-matching-over-a-parameter)). The example then reads from
After to Before.

## Transform a body-recursive function to a tail-recursive

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L3598)

**When:** A recursive function makes its recursive call somewhere other than as the last
operation before returning (body recursion). Convert it to tail recursion, usually with
an accumulating parameter, so the Erlang VM can apply tail-call optimization, which
upstream says can enhance parallelization and lead to more efficient code. In upstream's
Benchee run on a one-million-element list, the tail-recursive version can be about three
times faster.

**Before:**
```elixir
defmodule Foo do
  def sum_list_elements([]), do: 0

  def sum_list_elements([head | tail]) do
    sum_list_elements(tail) + head
  end
end
# ...
```

**After:**
```elixir
defmodule Foo do
  def sum_list_elements(list) do
    do_sum_list_elements(list, 0)
  end

  defp do_sum_list_elements([], sum), do: sum

  defp do_sum_list_elements([head | tail], sum) do
    do_sum_list_elements(tail, sum + head)
  end
end
# ...
```

**Side-conditions:**
- The new supporting function (e.g. `do_sum_list_elements/2`) must have a name different
  from every function already defined or imported by the module.
- The function must not rely on post-recursive processing: logical restructuring alone
  must transform it, without design changes such as types or the number of parameters.

**Caution (this skill, not upstream):** the accumulator adds the elements from the left
and the body recursion from the right. Integer sums agree, but float sums can differ:
for `[0.1, 0.2, 0.3]` the old version returns `0.6` and the new one
`0.6000000000000001`. Convert only when the order of the operation cannot change the
result for the values the function receives.

## Eliminate single branch

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L3694)

**When:** A control statement has only one possible flow, such as a `case` statement
with a single branch. Replace the statement with the code its single branch runs.

**Before:**
```elixir
defmodule Foo do
  def qux(value) do
    case value do
      {:ok, v1, v2} -> (v1 + v1) * v2
    end
  end
end

# ...
iex(2)> Foo.qux({:error, 2, 4})
** (CaseClauseError) no case clause matching: {:error, 2, 4}
```

**After:**
```elixir
defmodule Foo do
  def qux(value) do
    {:ok, v1, v2} = value
    (v1 + v1) * v2
  end
end

# ...
iex(2)> Foo.qux({:error, 2, 4})
** (MatchError) no match of right hand side value: {:error, 2, 4}
```

**Side-conditions:**
- Upstream states no preconditions for this refactoring.
- The two versions raise different errors (`CaseClauseError` and `MatchError`), so fully
  preserving the original behavior may need an error handler such as `try..rescue`.

## Transform to list comprehension

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L3753)

**When:** Code calls `Enum.map/2` or `Enum.filter/2` to build a new list from an
existing one. Replace the call with a semantically equivalent list comprehension, which
can be more declarative and easier to read.

**Before:**
```elixir
iex(1)> Enum.map([2, 3, 4], &(&1 * &1))
[4, 9, 16]

iex(2)> Enum.filter([1, 2, 3, 4, 5], &(rem(&1, 2) == 0))
[2, 4]
```

**After:**
```elixir
iex(1)> for x <- [2, 3, 4], do: x * x
[4, 9, 16]

iex(2)> for x <- [1, 2, 3, 4, 5], rem(x, 2) == 0, do: x
[2, 4]
```

**Side-conditions:**
- The only precondition is that calls to `Enum.map/2` or `Enum.filter/2` are selected
  for conversion into equivalent list comprehensions.

## Nested list functions to comprehension

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L3791)

**When:** `Enum.map/2` and `Enum.filter/2` are nested to build a new list, which hurts
readability and is inefficient: the original list can be visited more than once and an
intermediate list must be built. Replace the nested calls with one semantically
equivalent list comprehension, which can be more readable and more efficient. Upstream
also calls this deforestation, a specific instance of [Transform to list
comprehension](#transform-to-list-comprehension).

**Before:**
```elixir
iex(1)> Enum.filter([1, 2, 3, 4, 5], &(rem(&1, 2) == 0)) |> Enum.map(&(&1 * &1))
[4, 16]
```

**After:**
```elixir
iex(1)> for x <- [1, 2, 3, 4, 5], rem(x, 2) == 0, do: x * x
[4, 16]
```

**Side-conditions:**
- The only precondition is that nested calls to `Enum.map/2` or `Enum.filter/2` are
  selected for conversion. Upstream does not recommend selecting many levels of nesting
  (e.g. more than three nested calls), because the comprehension may become less
  readable than the original code.

## List comprehension simplifications

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L3821)

**When:** The codebase has a list comprehension. Transform it into semantically
equivalent calls to `Enum.map/2` or `Enum.filter/2`.

No code example upstream; it points to the [Transform to list
comprehension](#transform-to-list-comprehension) and [Nested list functions to
comprehension](#nested-list-functions-to-comprehension) examples read from After to
Before.

**Side-conditions:**
- The list comprehension may have only one generator. Comprehensions with two or more
  generators can be transformed, but the result would likely be harder to understand and
  not worth it.

**Caution (this skill, not upstream):** a generator with a pattern, such as
`{:ok, v} <- list`, skips the elements that do not match, while the function given to
`Enum.map/2` raises `FunctionClauseError` on them. Convert only generators whose left
side is a plain variable, or filter on the pattern first.

**Reverse:** Upstream calls this the inverse of [Transform to list
comprehension](#transform-to-list-comprehension) and [Nested list functions to
comprehension](#nested-list-functions-to-comprehension).

## Closure conversion

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L3837)
· Source: SLR

**When:** An anonymous function is a closure: it accesses variables outside its scope.
Make the referenced variables parameters of the function and update its calls for the
new arity, a specific case of Add or remove a parameter. Upstream says this helps code
optimization and memory management and makes the code easier to understand and read.

**Before:**
```elixir
defmodule Foo do
  def generate_sum(x) do
    fn y -> x + y end   # closure example!
  end
end

# ...
iex(1)> add_8 = Foo.generate_sum(8)
#Function<0.104673823/1 in Foo.generate_sum/1>

iex(2)> result = add_8.(2)
10
# ...
```

**After:**
```elixir
defmodule Foo do
  def generate_sum(_x) do
    fn x, y -> x + y end   # closure conversion!
  end
end

# ...
iex(1)> add_8 = Foo.generate_sum(8)  # unnecessary parameter in generate_sum/1
#Function<0.7062781/2 in Foo.generate_sum/1>

iex(2)> result = add_8.(8,2)
10
# ...
```

**Side-conditions:**
- The new parameter must have the same name as the variable that came from outside the
  anonymous function's scope (e.g. `x`). The function then stops being a closure, and
  the parameter does not conflict with any existing parameter or local variable in it.

**Caution (this skill, not upstream):** `generate_sum/1` now returns a two-argument
function, so every caller of that function must pass `x` as well. Code that hands it to
`Enum.map/2`, or anything else that calls it with one argument, raises `BadArityError`.

## Replace pipeline with a function

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L3897)
· Source: GLR

**When:** A pipeline of built-in higher-order functions, such as `Enum.filter/2 |>
Enum.count/1`, does what one function call can do. Replace it with a function that
composes it or with an equivalent built-in function, which reduces the iterations over
the data. Upstream says this improves performance and readability; in its Benchee run,
the original was 1.46x slower.

**Before:**
```elixir
list = Enum.to_list(1..1_000_000)

list
|> Enum.filter(&(rem(&1, 3) == 0))
|> Enum.count()
```

**After:**
```elixir
list = Enum.to_list(1..1_000_000)

Enum.count(list, &(rem(&1, 3) == 0))
```

**Side-conditions:**
- The pipeline must consist of chained calls to Elixir's built-in functions.
- Built-in functions must exist whose behavior equals the chained calls being replaced.
  Upstream lists these compatible substitutions for Elixir 1.17.2 and notes that
  compatibility may change as the language evolves:
  - `Enum.map/2 |> Enum.into/2` to `Enum.into/3`
  - `Enum.map/2 |> Enum.join/2` to `Enum.map_join/3`
  - `DateTime.utc_now/0 |> DateTime.truncate/1` to `DateTime.utc_now/1`
  - `NaiveDateTime.utc_now/0 |> NaiveDateTime.truncate/1` to `NaiveDateTime.utc_now/1`
  - `Enum.map/2 |> Enum.map/2` to one `Enum.map/2`
  - `Enum.filter/2 |> Enum.filter/2` to one `Enum.filter/2`
  - `Enum.reject/2 |> Enum.reject/2` to one `Enum.reject/2`
  - `Enum.filter/2 |> Enum.reject/2` to one `Enum.filter/2`

Example credit: Credo's documentation
([source](https://hexdocs.pm/credo/Credo.Check.Refactor.FilterCount.html)).

## Remove single pipe

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L3981)
· Source: GLR

**When:** A pipe has only two members: a variable or zero-arity function call, then a
call to a function of arity one or more. Replace this single pipe with a direct call to
that function, which gives cleaner, more readable code.

**Before:**
```elixir
list = [1,2,3,4]

list |> Enum.reverse()  # <-- single pipe!
```

**After:**
```elixir
list = [1,2,3,4]

Enum.reverse(list)
```

**Side-conditions:**
- The pipe must have only two members: first a variable or a zero-arity function call,
  then a call to a function of arity one or more.

Example credit: Recode's documentation
([source](https://hexdocs.pm/recode/Recode.Task.SinglePipe.html)).

## Simplifying pattern matching with nested structs

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L4017)
· Source: GLR

**When:** A function clause pattern matches deep into nested structs to extract a value,
which makes the code messy and hard to understand. Match only the outermost struct and
reach the value through chained strict field access, which improves readability and
reduces code size.

**Before:**
```elixir
def find_favorite_pet(%Post{comment: %Comment{author: %Author{favorite_pet: pet}}}) do
  pet
end
```

**After:**
```elixir
def find_favorite_pet(%Post{} = post) do
  post.comment.author.favorite_pet
end
```

**Side-conditions:**
- The deep extraction must originally happen in the definition of a function clause.
- All nested structs must have atom keys.
- The variable bound to the outermost struct must not conflict with existing parameters
  or local variables in the function.

**Caution (this skill, not upstream):** the new clause no longer checks for `%Comment{}`
and `%Author{}`. Another struct or a plain map with the same keys now returns a value,
and a `nil` comment raises `BadMapError` instead of `FunctionClauseError`. Keep the
nested patterns where the clause must reject other input.

Example credit: David Lucia ([source](https://www.youtube.com/watch?v=wvfhrvAFOoQ)).

## Improving list appending performance

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L4057)
· Source: GLR

**When:** Code appends elements to the end of a list. To keep data immutable, Elixir
duplicates the whole list on each tail concatenation, so frequent ones can lead to
significant memory use and hinder performance. Concatenate at the head instead, so the
lists share more memory; in upstream's Benchee run, tail concatenation was 215.31x
slower.

**Before:**
```elixir
list = Enum.to_list(1..5_000)

new_list = list ++ [new_element]  # <-- tail concatenation
```

**After:**
```elixir
list = Enum.to_list(1..5_000)

new_list = [new_element] ++ list # <-- head concatenation
```

**Side-conditions:**
- The order of the list's elements must not matter to other parts of the system.

Example credit: Credo's documentation
([source](https://hexdocs.pm/credo/Credo.Check.Refactor.AppendSingleItem.html)).

## Convert nested conditionals to pipeline

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L4123)
· Source: GLR

**When:** Nested conditionals such as `if..else` and `case` sequence calls to functions
that return `{:ok, _}` or `{:error, _}`, which makes the code confusing. Adapt the
functions with Add or remove a parameter and [Introduce pattern matching over a
parameter](#introduce-pattern-matching-over-a-parameter), then chain the calls with
`|>`. This composite refactoring can improve readability and is an alternative to
Pipeline using "with".

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
  state
  |> valid_move(index)
  |> players_turn(state, user_id)
  |> play_turn(state, index, marker)
end
```

**Side-conditions:**
- To keep the behavior, some functions in the pipeline change signature:
  `players_turn/2` and `play_turn/3` become `players_turn/3` and `play_turn/4`. The
  added parameter receives the previous function's `{:ok, _}` or `{:error, _}` return
  and directs the function's internal flow.

Example credit: Gary Rennie ([source](https://www.youtube.com/watch?v=V21DAKtY31Q)).

## Replacing recursion with a higher-level construct

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L4170)
· Source: GLR

**When:** A function iterates through recursion, which puts the reader's focus on its
mechanics and adds cognitive load, especially in code someone else wrote. Replace the
recursion with a call to a built-in higher-order function such as `Enum.reduce/3`, which
makes the code less verbose and more maintainable.

**Before:**
```elixir
defmodule Foo do
  def factorial(0), do: 1
  def factorial(n), do: n * factorial(n - 1)

  def sum_list([]), do: 0
  def sum_list([head | tail]) do
    head + sum_list(tail)
  end
end
```

**After:**
```elixir
defmodule Foo do
  def factorial(n) do
    Enum.reduce(1..n, 1, &(&1 * &2))
  end

  def sum_list(list) do
    Enum.reduce(list, 0, &(&1 + &2))
  end
end
```

**Side-conditions:**
- The recursive functions must behave identically to the `Enum` calls that replace them:
  no caller of the original functions changes, and all existing tests behave the same
  way.

**Caution (this skill, not upstream):** the example breaks that side-condition. `1..0`
is a descending range, so the new `factorial(0)` returns `0` where the old one returned
`1`; `1..n//1` keeps `factorial(0) == 1`. Three more differences:

- For a negative `n`, the old `factorial/1` recurses until memory runs out, and the new
  one returns a number. A guard such as `when n >= 0` makes negatives fail fast.
- `Enum.reduce/3` adds from the left and `head + sum_list(tail)` from the right, so
  float sums can differ in the last digits.
- `sum_list/1` now accepts any enumerable, such as a range, where the old one raised
  `FunctionClauseError`.

Check the empty, base and invalid inputs before replacing recursion.

## Replace a nested conditional in a "case" statement with guards

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L4218)
· Source: MSR

**When:** A `case` clause nests an `if..else` to perform a more complex check. Replace
the nested conditional with a guard on the clause, which keeps the check and improves
readability. Upstream's example first applies Extract expressions to bind the condition
to a local variable.

**Before:**
```elixir
defmodule File.Stream do
  def reduce(%{path: path, modes: modes}, acc, fun) do
    start_fun =
      fn ->
        case :file.open(path, read_modes(modes)) do
          {:ok, device} -> if :strip_bom in modes, do: strip_bom(device), else: device
          {:error, reason} -> raise(File.Error, reason)
        end
      end
    ...
  end

  ...

end
```

**After:**
```elixir
defmodule File.Stream do
  def reduce(%{path: path, modes: modes}, acc, fun) do
    strip_bom? = :strip_bom in modes  #<- "Extract Expressions" refactoring!

    start_fun =
      fn ->
        case :file.open(path, read_modes(modes)) do
          {:ok, device} when strip_bom? -> strip_bom(device) #<- Guard replacing nested conditional!
          {:ok, device} -> device
          {:error, reason} -> raise(File.Error, reason)
        end
      end
    ...
  end

  ...

end
```

**Side-conditions:**
- Put a `when` guard on the `case` clause that held the nested `if..else`, replacing the
  branch equivalent to the `if`.
- Immediately after it, add a clause with the same pattern as the original clause,
  replacing the branch defined by the `else`.

**Caution (this skill, not upstream):** a guard passes only when its expression is
`true`, while `if` takes any truthy value. If `strip_bom?` held `"yes"`, the `if` would
strip the BOM and the guard would not. Move a condition into a guard only when it
returns a boolean, as `:strip_bom in modes` does.

Example credit: Andrea Leopardi
([source](https://github.com/elixir-lang/elixir/pull/5702)).

## Replace function call with raw value in a pipeline start

[Catalog
entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L4285)
· Source: MSR

**When:** A pipeline starts with a function call instead of a raw value. Extract the
call's first argument and put it at the start of the pipeline; upstream says pipelines
are often more readable this way because they show which value the operations transform.

**Before:**
```elixir
defmodule Foo do
  def bar(list) do
    Enum.map(list, &(&1 * 2))
    |> Enum.sort
    |> Enum.at(0)
  end
end
# ...
```

**After:**
```elixir
defmodule Foo do
  def bar(list) do
    list           #<- Raw value!
    |> Enum.map(&(&1 * 2))
    |> Enum.sort
    |> Enum.at(0)
  end
end
# ...
```

**Side-conditions:**
- The pipeline must start with a call to a function of arity one or more, and the first
  argument of that call must be a variable.
