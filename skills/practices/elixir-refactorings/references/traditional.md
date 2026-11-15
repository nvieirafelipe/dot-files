# Traditional refactorings

Traditional refactorings come mainly from Fowler's catalog or use programming features
that do not depend on a language or paradigm. This group has 25 entries. Condensed from
the [Catalog of Elixir Refactorings](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md)
by Lucas Francisco da Matta Vegi and Marco Tulio Valente (UFMG; MIT license), from
their study [Understanding refactorings in Elixir functional
language](https://doi.org/10.1007/s10664-025-10652-y) (Empirical Software Engineering,
2025). Each entry links to its full text there.
The examples are upstream's code, trimmed but not corrected: read them as shapes, and
see "Caution" notes and [sources.md](sources.md#upstream-slips) for known slips.

## Contents

- [Rename an identifier](#rename-an-identifier)
- [Moving a definition](#moving-a-definition)
- [Add or remove a parameter](#add-or-remove-a-parameter)
- [Grouping parameters in tuple](#grouping-parameters-in-tuple)
- [Reorder parameter](#reorder-parameter)
- [Extract function](#extract-function)
- [Inline function](#inline-function)
- [Folding against a function definition](#folding-against-a-function-definition)
- [Extract constant](#extract-constant)
- [Temporary variable elimination](#temporary-variable-elimination)
- [Extract expressions](#extract-expressions)
- [Splitting a large module](#splitting-a-large-module)
- [Remove nested conditional statements in function calls](#remove-nested-conditional-statements-in-function-calls)
- [Move file](#move-file)
- [Remove dead code](#remove-dead-code)
- [Introduce a temporary duplicate definition](#introduce-a-temporary-duplicate-definition)
- [Introduce overloading](#introduce-overloading)
- [Remove import attributes](#remove-import-attributes)
- [Introduce import](#introduce-import)
- [Group Case Branches](#group-case-branches)
- [Move expression out of case](#move-expression-out-of-case)
- [Simplifying checks by using truthness condition](#simplifying-checks-by-using-truthness-condition)
- [Reducing a boolean equality expression](#reducing-a-boolean-equality-expression)
- [Transform "unless" with negated conditions into "if"](#transform-unless-with-negated-conditions-into-if)
- [Replace conditional with polymorphism via Protocols](#replace-conditional-with-polymorphism-via-protocols)

## Rename an identifier

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L999)

**When:** An identifier's name does not convey its purpose. A clear name improves
readability, so developers spend less time working out what the code does. In Elixir,
identifiers include functions, modules, macros, variables, map and struct fields,
registered processes, protocols, behaviour callbacks, module aliases, module attributes,
and function parameters.

**Before:**
```elixir
def foo(value_1, value_2) do
  value_1 + value_2
end
```

**After:**
```elixir
def sum(value_1, value_2) do
  value_1 + value_2
end

def foo(value_1, value_2) do  #<-- must be deleted in the future!
  sum(value_1, value_2)
end
```

**Side-conditions:**
- The new name must not conflict with other existing names.
- When renaming a function, the new name must not conflict with other functions of the
  same module or with functions imported from another module.

**Mechanics:** The steps vary by identifier type. For renaming a function:
1. Check whether a behaviour or protocol implemented by the module defines the function.
   If so, make the change at that behaviour or protocol and in every module of the
   codebase that implements it.
2. Create a function with the new name and copy the original body into it.
3. Replace the original body with a call to the new function.
4. Test for breaking changes.
5. Replace each call to the original function with a call to the new one, testing again
   each time.
6. When no calls to the original remain and tests pass, delete it, along with its
   behaviour or protocol definition if there is one.

## Moving a definition

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L1054)

**When:** A definition (function, macro, or struct) uses more data or functions from
another module than from its own, or another module uses it more. Moving it there groups
related definitions, which raises cohesion and removes avoidable coupling. This helps
remove the Feature Envy code smell.

**Before:**
```elixir
defmodule ModuleA do
  alias ModuleB, as: B

  def foo(v1, v2) do
    B.baz(v1, v2)
    |> B.qux()
  end

  def bar(v1) do
    ...
  end
end

#...Use example...
iex(1)> ModuleA.foo(1, 2)

defmodule ModuleB do
  def baz(value_1, value_2) do
    ...
  end

  def qux(value_1) do
    ...
  end
end
```

**After:**
```elixir
defmodule ModuleA do
  def bar(v1) do
    ...
  end
end

defmodule ModuleB do
  # ...

  def foo(v1, v2) do #<-- moved function!
    baz(v1, v2)
    |> qux()
  end
end

#...Use example...
iex(1)> ModuleB.foo(1, 2)
```

**Side-conditions:**
- When moving a function or macro, its name must not conflict with any definition of the
  same type already defined in or imported by the target module.
- A moved function that calls other functions or macros must still refer to the same
  definitions after the move.
- A struct can move only to a target module that does not already define a struct.

## Add or remove a parameter

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L1144)

**When:** A function needs more information from its callers, or no longer needs some of
what they pass. Elixir default values (`\\`) simplify the change:
`foo(value, new_arg \\ 1)` defines both `foo/1` and `foo/2`, so existing callers keep
working unchanged.

**Before:**
```elixir
def foo(value) do
  value + 1
end
```

**After:**
```elixir
def foo(value, new_arg \\ 1) do
  value + new_arg
end
```

**Side-conditions:**
- When adding a parameter, its name must not conflict with any other parameter or local
  variable in the function.
- When adding a parameter raises the arity, the function must not conflict with a
  function of the same name and arity already defined in or imported into the module.
- When removing a parameter, the function body must not use it.
- When removing a parameter lowers the arity, the function must not conflict with a
  function of the same name and arity already defined in or imported into the module.

**Reverse:** The same entry covers removal. Once the body no longer uses the parameter,
give it a default value: callers of the higher arity keep working, and new callers of
the lower arity can coexist with them. When no caller of the higher arity remains,
delete the parameter.

## Grouping parameters in tuple

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L1186)

**When:** A long parameter list makes a function's interface confusing and bug-prone.
Group sequential, related parameters into a tuple and update the callers; this can
remove the Long Parameter List code smell. When the same group recurs across functions
(Data Clumps), upstream prefers a struct reused across all of them.

**Before:**
```elixir
defmodule Foo do
  def rand(first, last) do
    Enum.random(first..last)
  end
end

#...Use examples...
iex(1)> Foo.rand(1, 9)
4
# ...
```

**After:**
```elixir
defmodule Foo do
  def rand({first, last} = group) do
    Enum.random(first..last)
  end
end

#...Use examples...
iex(1)> g = {1, 9}  #<= tuple definition
iex(2)> Foo.rand(g)
5
# ...
iex(5)> g = {2, 8, 3} #<= wrong tuple definition!
iex(6)> Foo.rand(g)
** (FunctionClauseError) no function clause matching in Foo.rand/1
```

**Side-conditions:**
- The grouped parameters must be sequential in the original parameter list.
- The new, lower-arity function must not conflict with functions defined in or imported
  by the module.
- The function must not be an OTP callback (for example, `GenServer.handle_call/3`).

## Reorder parameter

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L1251)

**When:** A function's parameter order does not keep related concepts together, which
confuses callers and invites errors that go unnoticed. Reorder the parameters so they
read in a meaningful order.

**Before:**
```elixir
def area(major_base, height, minor_base) do
  ((major_base + minor_base) * height) / 2
end

#...Use examples...
iex(1)> Trapezoid.area(24, 9, 15) #<- misuse
175.5
# ...
```

**After:**
```elixir
def new_area(major_base, minor_base, height) do  #<-- can be renamed in the future!
  ((major_base + minor_base) * height) / 2
end

def area(major_base, height, minor_base) do      #<-- must be deleted in the future!
  new_area(major_base, minor_base, height)
end

#...Use examples...
iex(1)> Trapezoid.new_area(24, 9, 15)
247.5
# ...
```

**Side-conditions:**
- The new function must have the same arity as the original and a name that differs
  from every function defined or imported by the module.
- Right after the refactoring, the new function (e.g. `new_area/3`) must be called only
  from the body of the original function (e.g. `area/3`).

## Extract function

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L1307)

**When:** A function serves several purposes and grows long, often with comments that
explain a run of lines. Move that run into a new function whose name states its purpose,
and call it from the original. This targets the Long Function code smell; the smaller
function reads better and the extracted one can be reused.

**Before:**
```elixir
def ticket_booking(passenger, air_line, date, credit_card, seat) do
  {company, contact_info, cancel_policy} = check_availability(air_line, date)
                                            |> documents_validation(passenger)
                                            |> select_seat(seat)
                                            |> payment(credit_card)
  #print booking report
  IO.puts("Booking made at the company: #{company}")
  IO.puts("Any doubt, contact: #{contact_info}")
  IO.puts("For cancellations, see company policies: #{cancel_policy}")
end
```

**After:**
```elixir
def report({company, contact_info, cancel_policy} = confirmation) do
  IO.puts("Booking made at the company: #{company}")
  IO.puts("Any doubt, contact: #{contact_info}")
  IO.puts("For cancellations, see company policies: #{cancel_policy}")
end

def ticket_booking(passenger, air_line, date, credit_card, seat) do
  check_availability(air_line, date)
  |> documents_validation(passenger)
  |> select_seat(seat)
  |> payment(credit_card)
  |> report()  #<- extracted function call!
end
```

**Side-conditions:**
- The name and arity of the extracted function must not conflict with any function
  defined or imported by the module.
- The extracted expressions must not call the original function recursively.
- The extracted expressions must not come from a guard sequence.
- The extracted expressions must not be part of a pattern.
- The extracted expressions must not be inside a macro definition.

## Inline function

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L1368)

**When:** A function body only delegates to another call, so its purpose is as clear as
its name and keeping it adds nothing. Excessive delegation can make the execution flow
indirect and hard to debug. Replace every call with the body, then delete the function.

**Before:**
```elixir
defmodule Order do
  defp sum_list(list) do
    Enum.sum(list)
  end

  def get_amount(order_itens) do
    sum_list(order_itens)
  end
end
```

**After:**
```elixir
defmodule Order do
  def get_amount(order_itens) do
    Enum.sum(order_itens)  #<- inlined function!
  end
end
```

**Side-conditions:**
- The inlined body must not contain variables whose names conflict with variables
  already in scope where the calls occurred.
- If the function is defined in a different module from the calls, its body must not
  call functions that are not imported in the scope of those calls.

**Reverse:** Upstream calls this the inverse of Extract function.

## Folding against a function definition

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L1414)

**When:** Some code duplicates what an existing function computes. Replace the duplicate
with a call to that function, adapting the call site where needed to keep behavior; this
can remove Duplicated Code. The chance may appear after Extract function followed by
Generalise a function definition.

**Before:**
```elixir
defmodule Class do
  defstruct [:id, :grades, :avg, :worst, :best]

  def report(list) do  #<- Generated after extraction and generalisation!
    avg = Enum.sum(list) / length(list)
    {min, max} = Enum.min_max(list)
    {avg, min, max}
  end

  def improve_grades(class_id, grades, students_amount) do
    high_grade = Enum.max(grades)
    adjustment_factor = 100 / high_grade
    new_grades = Enum.map(grades, &(&1 * adjustment_factor) |> Float.round(2))

    grades_avg = Enum.sum(new_grades) / students_amount   #<- duplicated code
    {w, b} = Enum.min_max(new_grades)                     #<- duplicated code

    %Class{id: class_id, grades: new_grades, avg: grades_avg, worst: w, best: b}
  end
end
```

**After:**
```elixir
defmodule Class do
  # ...

  def improve_grades(class_id, grades, students_amount) do
    high_grade = Enum.max(grades)
    adjustment_factor = 100 / high_grade
    new_grades = Enum.map(grades, &(&1 * adjustment_factor) |> Float.round(2))

    {grades_avg, w, b} = report(new_grades) #<- Folding against a function definition!

    %Class{id: class_id, grades: new_grades, avg: grades_avg, worst: w, best: b}
  end
end
```

**Side-conditions:**
- The duplicated code and the function that replaces it must be defined in the same
  module.
- After the replacement, compensations (for example, pattern matching on the returned
  value) may be needed to keep the original behavior.

**Caution (this skill, not upstream):** `report/1` divides by `length(list)`, so the
after code ignores `students_amount`, and the two versions agree only when it equals
`length(grades)`. For grades `[50, 100]` and 3 students, the average goes from `50.0` to
`75.0`. Fold only when the existing function computes the same value, or compensate as
the second side-condition says.

## Extract constant

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L1505)

**When:** Magic numbers appear directly in expressions, which makes the code harder to
understand, and a number scattered across the codebase is costly and bug-prone to
change. Create a constant (a module attribute) with a meaningful name and replace the
occurrences with it.

**Before:**
```elixir
defmodule Circle do
  def area(r) do
    3.14 * r ** 2
  end

  def circumference(r) do
    2 * 3.14 * r
  end
end
```

**After:**
```elixir
defmodule Circle do
  @pi 3.14    #<- extracted constant!

  def area(r) do
    @pi * r ** 2
  end

  def circumference(r) do
    2 * @pi * r
  end
end
```

**Side-conditions:** None stated.

## Temporary variable elimination

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L1564)

**When:** Temporary variables only hold a result to return or an intermediate value.
Replace their uses with the bound value and delete them, as the compiler technique copy
propagation does (for `a = b`, replace uses of `a` with `b`). This can simplify the code
and avoid redundant computation.

**Before:**
```elixir
defmodule Foo do
  def bar(b, list) when is_integer(b) do
    a = b * 2
    c = a
    result_1 = Enum.at(list, c)
    r = a
    result_2 = Enum.map(list, &(&1 + r))
              |> Enum.sum()

    {result_1, result_2}
  end
end
```

**After:**
```elixir
defmodule Foo do
  def bar(b, list) when is_integer(b) do
    { Enum.at(list, b * 2),
      Enum.map(list, &(&1 + b * 2)) |> Enum.sum() }
  end
end
```

**Side-conditions:**
- The variable has only one binding occurrence, on the left-hand side of a match, and is
  not part of a compound pattern.
- The expression bound to the variable is pure (has no side effects).

## Extract expressions

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L1622)

**When:** An expression is large and hard to understand, or repeats. Break it into parts
bound to local variables with meaningful names. This can also help remove Duplicated
Code, since the variables can be reused instead of repeating long expressions.

**Before:**
```elixir
defmodule Bhaskara do

  def solve(a, b, c) do
    if b*b - 4*a*c < 0 do
      {:error, "No real roots"}
    else
      x1 = (-b + (b*b - 4*a*c) ** 0.5) / (2*a)
      x2 = (-b - (b*b - 4*a*c) ** 0.5) / (2*a)
      {:ok, {x1, x2}}
    end
  end

end
```

**After:**
```elixir
defmodule Bhaskara do

  def solve(a, b, c) do
    delta = (b*b - 4*a*c) #<- extracted variable!

    if delta < 0 do
      {:error, "No real roots"}
    else
      x1 = (-b + delta ** 0.5) / (2*a)
      x2 = (-b - delta ** 0.5) / (2*a)
      {:ok, {x1, x2}}
    end
  end

end
```

Upstream also shows a further version, reached by applying Extract function, Generalise
a function definition, Folding against a function definition, and Temporary variable
elimination to this result.

**Side-conditions:**
- The new variable's name must not conflict with any variable already defined in the
  same scope.
- The expression must be inside a function body and not part of a guard expression.
- The expression cannot be replaced by a variable if any of its sub-expressions is
  impure (has side effects).

**Reverse:** Upstream says this behaves, in a way, as the inverse of Temporary variable
elimination.

## Splitting a large module

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L1738)

**When:** A module does the work of two or more and becomes large, poorly cohesive, and
hard to maintain. Split it into new modules, moving to each only the attributes and
functions related to its purpose. This can remove the Large Module code smell (Large
Class in object-oriented languages).

**Before:**
```elixir
defmodule ShoppingCart do
  # Rule 1
  def calculate_total(items, subscription) do
    # ...
  end

  # Rule 1
  def calculate_shipping(zip_code, %{id: 3}), do: 0.0
  def calculate_shipping(zip_code, %{id: 4}), do: 0.0
  def calculate_shipping(zip_code, _), do
    10.0 * Location.calculate(zip_code)
  end

  # Rule 2
  def apply_discount(total, %{id: 3}), do: total * 0.9
  def apply_discount(total, %{id: 4}), do: total * 0.9
  def apply_discount(total, _), do: total

  # Rule 3
  def send_message_subscription(%{id: 3}, _), do: nil
  def send_message_subscription(%{id: 4}, _), do: nil
  def send_message_subscription(subscription, user), do: # something

  # Rule 4
  def report(user, order) do
    # ...
  end
end
```

**After:**
```elixir
defmodule ShoppingCart do
  # Rule 1
  # ...
end

defmodule Item do
  # Rule 2
  def apply_discount(total, %{id: 3}), do: total * 0.9
  def apply_discount(total, %{id: 4}), do: total * 0.9
  def apply_discount(total, _), do: total
end
```

Upstream applies the refactoring three times, also moving Rule 3 to `Subscription` and
Rule 4 to `Util`.

**Side-conditions:** None stated.

## Remove nested conditional statements in function calls

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L1837)

**When:** Nested conditional statements, such as a `case` passed as a function argument,
can hurt readability without need. Remove the unneeded nesting; in the upstream example,
a strict equality comparison (`===`) replaces the inner `case`.

**Before:**
```elixir
defmodule Foo do
  defp convert(list, switch) do
    case switch do
      true -> {:tuple, List.to_tuple(list)}
      _    -> {:list, list}
    end
  end

  def qux(list, value, index) do
    case convert(list, case Enum.at(list, index) do
                          ^value -> true
                          _      -> false
                        end) do
      {:tuple, _} -> "Something..."
      {:list, _}  -> "Something else..."
    end
  end
end
```

**After:**
```elixir
defmodule Foo do
  ...

  def qux(list, value, index) do
    case convert(list, Enum.at(list, index) === value) do
      {:tuple, _} -> "Something..."
      {:list, _}  -> "Something else..."
    end
  end

end
```

**Side-conditions:** None stated.

## Move file

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L1905)

**When:** A project file containing code (modules, macros, structs) belongs in another
directory. Moving it groups related files, for example those of the same architectural
layer. Code that depends on the moved file may need its references updated.

No code example upstream.

**Side-conditions:** None stated.

## Remove dead code

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L1914)

**When:** Unused code makes a codebase longer and harder to maintain. Delete the
definitions that nothing uses. The compiler's unused-variable warning can point to them.

**Before:**
```elixir
defmodule Foo do
  def bar(v1, v2) do
    v1 = v1 ** 2
    v2 = v2 + 5
    dead_code = v2 / 2  #<= can be removed!
    {:ok, v1 ** v2}
  end
end

#...Use examples...
iex(1)> c("sample.ex")
warning: variable "dead_code" is unused... sample.ex:5: Foo.bar/2
# ...
```

**After:**
```elixir
defmodule Foo do
  def bar(v1, v2) do
    v1 = v1 ** 2
    v2 = v2 + 5
    {:ok, v1 ** v2}
  end
end
```

**Side-conditions:**
- No further conditions apply, given that the removed code is either commented out or
  not referenced by any other part of the codebase.

## Introduce a temporary duplicate definition

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L1966)

**When:** A change to some code needs trying out without losing the original definition.
Duplicate the definition temporarily under a new identifier; once the new version is
approved, it replaces the original and the duplicate goes.

**Before:**
```elixir
defmodule Foo do
  def bar(v1, v2) do
    v3 = v1 ** v2
    {:ok, v3}
  end
end
```

**After:**
```elixir
defmodule Foo do
  def bar(v1, v2) do
    v3 = v1 ** v2               #<= definition to be changed!
    v3_duplication = v1 ** v2   #<= original version!
    {:ok, v3}
  end
end
```

**Side-conditions:**
- The identifier of the duplicate (`v3_duplication`) must not conflict with any other
  identifier in the code.
- Once the new version is approved, this refactoring removes the duplicate. If the new
  version is rejected, Rename an identifier restores the original version.

## Introduce overloading

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L2019)

**When:** A function needs a variation for use in another context. Add a clause with the
same arity (a multi-clause function), or a function with the same name and a different
arity.

**Before:**
```elixir
defmodule Order do
  defstruct [date: nil, total: nil]

  def discount(%Order{total: t} = s) when t >= 100.0 do
    %Order{s | total: t * 0.7}
  end

end
```

**After:**
```elixir
defmodule Order do
  defstruct [date: nil, total: nil]

  # new
  def discount(%Order{date: d, total: t} = s) when d.day == 25 and d.month == 12 do
    %Order{s | total: t * 0.1}
  end

  # original
  def discount(%Order{total: t} = s) when t >= 100.0 do
    %Order{s | total: t * 0.7}
  end

  # new
  def discount(%Order{total: t} = s, value) do
    %Order{s| total: t * value}
  end

end

#...Use examples...
iex(1)> Order.discount(%Order{total: 150.0, date: ~D[2022-12-25]})
%Order{date: ~D[2022-12-25], total: 15.0}
# ...
iex(3)> Order.discount(%Order{total: 90.0, date: ~D[2022-10-18]}, 0.8)
%Order{date: ~D[2022-10-18], total: 72.0}
```

**Side-conditions:** None stated.

**Caution (this skill, not upstream):** the new 25 December clause sits above the
original, so it takes orders the original clause used to price: the `150.0` order above
cost `105.0` before and `15.0` after. A clause added to an existing function keeps
behavior only when it matches inputs that no existing clause handles; otherwise the
change is a feature, not a refactoring.

## Remove import attributes

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L2086)

**When:** `import` shortens calls but hides where a called function comes from, which
hurts readability. Remove the `import` directives and call each formerly imported
function as `Module.function(args)`.

**Before:**
```elixir
defmodule Bar do
  def sum(v1, v2) do
    v1 + v2
  end
end

defmodule Foo do
  import Bar  #<= to be removed!

  def qux(value_1, value_2) do
    sum(value_1, value_2)   #<= imported function!
  end
end
```

**After:**
```elixir
# ...

defmodule Foo do
  def qux(value_1, value_2) do
    Bar.sum(value_1, value_2)   #<= calling with a fully-qualified name
  end
end
```

**Side-conditions:**
- Upstream calls this free of preconditions and postconditions. Fully qualified calls
  cannot conflict, even when the importing module defines a function with the same name
  and arity as one it used to import.

## Introduce import

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L2142)

**When:** Calls use fully qualified names (`Module.function(args)`) for another module's
functions. Import that module and call its functions by name alone.

No code example upstream. Upstream points to the Remove import attributes example, read
from After to Before.

**Side-conditions:**
- When a module `Foo` imports functions from a module `Bar`, `Foo` must not already
  define functions with the same name and arity as those imported from `Bar`.
- `Foo` must not already import, from other modules, functions with the same name and
  arity as those imported from `Bar`.

**Reverse:** Upstream calls this the inverse of Remove import attributes.

## Group Case Branches

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L2160)

**When:** A divide-and-conquer function handles its base cases and recursive cases in a
single `case`. Separating the two kinds makes the function easier to parallelize. The
original `case` becomes four: two decide base versus recursive, and two pick the
specific base or recursive case.

**Before:**
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
```

**After:**
```elixir
defmodule Foo do
  def merge_sort(list) do
    is_base = case list do        #<= role 1
                []    -> true
                [_h]  -> true
                _     -> false
              end

    case is_base do               #<= role 2
      true  ->  case list do      #<= role 3
                  []  -> []
                  [h] -> [h]
                end
      false ->  case list do      #<= role 4
                  _   ->  half = length(list) |> div(2)
                          right = merge_sort(Enum.take(list, half))
                          left = merge_sort(Enum.drop(list, half))
                          merge(right, left)
                end
    end
  end
end
```

**Side-conditions:**
- The head expression of the original `case` (e.g. `case list do`) must be pure: no
  side effects such as I/O, database writes, GUI state updates, or sending or receiving
  messages.

## Move expression out of case

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L2234)

**When:** The same expression ends every branch of a `case`. Move it out, after the
`case`. Upstream frames this as restructuring divide-and-conquer functions to make them
easier to parallelize.

**Before:**
```elixir
defmodule Foo do
  def bar(confirm, list) do
    case confirm do
      true  ->  value = Enum.at(list, 0)
                Integer.is_odd(value)
      false ->  value = Enum.at(list, length(list)-1)
                Integer.is_odd(value)
    end
  end
end
```

**After:**
```elixir
defmodule Foo do
  def bar(confirm, list) do
    value = case confirm do
              true  ->  Enum.at(list, 0)
              false ->  Enum.at(list, length(list)-1)
            end
    Integer.is_odd(value) #<= out of case!
  end
end
```

**Side-conditions:**
- The expressions at the end of the original branches must be lexically identical.

## Simplifying checks by using truthness condition

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L2295) · Source: GLR

**When:** Code uses `is_nil/1` and an `if`/`else` block to return a default when a value
is `nil`. Use the short-circuit operator `||` instead, which returns its first operand
that is not falsy (`nil` and `false` are falsy). This takes fewer lines and reads
clearly.

**Before:**
```elixir
def default(price) do
  if is_nil(price) do
    "$100"
  else
    price
  end
end
```

**After:**
```elixir
def default(price) do
  price || "$100"
end
```

**Side-conditions:** None stated.

**Caution (this skill, not upstream):** the two versions differ when the value is
`false`: `false || "$100"` returns `"$100"`, while the `is_nil/1` version returns
`false`. Apply it only where the value cannot be `false`.

Example credit: based on code by Malreddy Ankanna
([source](https://medium.com/blackode/elixir-code-refactoring-techniques-33589ac56231)).

## Reducing a boolean equality expression

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L2334) · Source: GLR

**When:** A boolean expression chains several equality comparisons of the same variable
with `or`. Use the `in` operator with a list of the valid values; this removes partly
duplicated code and reads better.

**Before:**
```elixir
if user == "admin" or user == "super_admin" or user == "agent" or user == "super_agent" do
  do_something()
else
  do_something_else()
end
```

**After:**
```elixir
if user in ["admin", "super_admin", "agent", "super_agent"] do
  do_something()
else
  do_something_else()
end
```

**Side-conditions:** None stated.

**Caution (this skill, not upstream):** `in` compares with `===`, while `==` treats
`1.0` and `1` as equal: `1.0 == 1` is `true`, but `1.0 in [1, 2]` is `false`. The
example compares strings, so it is safe; with numbers, rewrite only when the variable
and the listed values have the same type.

Example credit: based on code by Malreddy Ankanna
([source](https://medium.com/blackode/elixir-code-refactoring-techniques-33589ac56231)).

## Transform "unless" with negated conditions into "if"

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L2371) · Source: GLR

**When:** An `unless` tests a negated condition, so the block runs only when a negated
condition is not met, which is confusing. Drop the negation and use `if`; the behavior
stays the same. The reason is readability, not anything technical.

**Before:**
```elixir
unless !allowed? do
  proceed_as_planned()
end
```

**After:**
```elixir
if allowed? do
  proceed_as_planned()
end
```

**Side-conditions:** None stated.

Example credit: based on Credo's official documentation
([source](https://hexdocs.pm/credo/Credo.Check.Refactor.NegatedConditionsInUnless.html)).

## Replace conditional with polymorphism via Protocols

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L2404) · Source: GLR

**When:** A conditional picks its action by data type or data properties and grows
harder to follow with each new case, or the same conditional sequence (`if..else`,
`case`, `cond`) repeats so a new check means editing many places: the Switch Statements
code smell. Translate Fowler's refactoring to Elixir with a protocol implemented once
per data type, so adding a type means adding a module.

**Before:**
```elixir
defmodule Bird do
  defstruct type: nil, number_of_coconuts: 0, voltage: 0

  def plumage(bird) do
    case bird.type do
      "EuropeanSwallow" -> "average"
      "AfricanSwallow" ->
        if bird.number_of_coconuts > 2 do
          "tired"
        else
          "average"
        end
      "NorwegianParrot" ->
        if bird.voltage > 100 do
          "scorched"
        else
          "beautiful"
        end
    end
  end
end

#...Use examples...
iex(1)> Bird.plumage(%Bird{type: "AfricanSwallow", number_of_coconuts: 7})
"tired"
# ...
```

**After:**
```elixir
defprotocol Bird do
  def plumage(bird)
end

# ...

defmodule AfricanSwallow do
  defstruct number_of_coconuts: 0

  defimpl Bird, for: AfricanSwallow do
    def plumage(%AfricanSwallow{number_of_coconuts: num}) when num > 2, do: "tired"
    def plumage(_), do: "average"
  end
end

# ...
iex(1)> Bird.plumage(%AfricanSwallow{number_of_coconuts: 7})
"tired"
# ...
```

Upstream also shows the `EuropeanSwallow` and `NorwegianParrot` implementations.

**Side-conditions:** None stated.

Example credit: based on code by Zack Kayser
([source](https://launchscout.com/blog/refactoring-patterns-in-elixir-replace-conditional-with-polymorphism-via-protocols-part-2)).
