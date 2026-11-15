---
name: elixir-refactorings
description:
  Names and applies the 82 behavior-preserving refactorings of the Catalog of Elixir
  Refactorings (Vegi and Valente), each with the code shape that calls for it, a
  before-and-after example, and the side-conditions that keep it safe. Use when
  refactoring Elixir code, choosing the fix for a code smell or anti-pattern in .ex or
  .exs files, proposing a structural remedy in an Elixir code review, or when someone
  names a refactoring in an Elixir context, such as extract function, pipeline using
  with, Enum to Stream, tail recursion, tuple to struct, or removing a GenServer.
---

STARTER_CHARACTER = ♻️💧

# Elixir refactorings

Turn "this code smells" into a named move that keeps behavior the same: which
refactoring, when it applies, and what must hold before it is safe. The moves come from
the [Catalog of Elixir Refactorings][catalog] by Lucas Vegi and Marco Tulio Valente: 82
refactorings in four groups. The reference files condense each one, and each entry links
to its full text upstream.

## Rules for every refactoring

- **Behavior stays the same.** Run the tests before starting. If no test covers the
  code, write one that pins its current behavior first; a refactoring without a safety
  net is a rewrite.
- **One named refactoring per step.** Run the tests after each step. Commit refactorings
  apart from behavior changes, and name the refactoring in the commit message so a
  reviewer knows what to check.
- **Check the side-conditions and the Caution first.** Side-conditions are listed per
  entry. When one fails, fix that first or pick another move. Many concern callers:
  before changing a signature, find them with `git grep` on the function name, and
  `mix xref graph --sink <file>` lists the files that depend on the module's file. A
  "Caution (this skill, not upstream)" note marks a difference the side-conditions miss,
  such as `nil` against `false`, `==` against `===`, an empty range, or a changed error;
  check the code for it too.
- **Public functions change their callers.** Rename an identifier, Add or remove a
  parameter, Reorder parameter, Grouping parameters in tuple and Moving a definition all
  change a public interface when applied to one. Outside one application, that is a
  breaking change: keep the old function as a delegate until callers move. Introduce a
  temporary duplicate definition keeps both versions side by side until the new one
  replaces the old.
- **Some entries change runtime behavior on purpose.** Replace "Enum" collections with
  "Stream" changes when work happens, Transform a body-recursive function to a
  tail-recursive changes stack use and speed, Improving list appending performance
  changes cost, and the process and supervision entries change failure and concurrency.
  Tests rarely notice these. Say what changes at runtime, and measure when the reason is
  speed.

## Find the refactoring from the smell

Start from what is wrong with the code, then open the entry. Names in the first column
are the ones guided-pr-review's smell baseline, elixir-crafting's anti-patterns and
nvieirafelipe-elixir-xp's anti-patterns use. "Catalog" means upstream ties the smell to
the entry; "judgment" is this skill's reading and needs a look at the code.

| Smell or anti-pattern | Refactorings | Basis |
|---|---|---|
| Duplicated Code | Extract expressions, Folding against a function definition, Generalise a function definition, Merging multiple definitions, Turning anonymous into local functions | catalog |
| Long Function | Extract function, Introduce pattern matching over a parameter | catalog |
| Long Parameter List | Grouping parameters in tuple, then From tuple to struct | catalog, then judgment |
| Large Module | Splitting a large module | catalog |
| Feature Envy | Moving a definition | catalog |
| Repeated Switches (Switch Statements) | Replace conditional with polymorphism via Protocols | catalog |
| GenServer Envy | Generalise a process abstraction | catalog |
| Unnecessary macros | Inline macro | catalog |
| Code organisation by process | Remove processes | catalog |
| Unsupervised processes | Moving error-handling mechanisms to supervision trees | judgment: the entry links the smell's corrected code |
| Mysterious Name | Rename an identifier | judgment |
| Comments overuse | Rename an identifier, Extract constant | judgment |
| Data Clumps | Grouping parameters in tuple, then From tuple to struct | judgment |
| Primitive Obsession | From tuple to struct, Typing parameters and return values | judgment |
| Shotgun Surgery, Scattered process interfaces | Moving a definition, gathering what changes together | judgment |
| Divergent Change | Splitting a large module | judgment |
| Speculative Generality | Remove dead code, Inline function, Add or remove a parameter, Behaviour inlining | judgment |
| Middle Man | Inline function | judgment |
| Message Chains through nested structs | Extract function, to hide the walk behind one name; Simplifying pattern matching with nested structs runs the other way and creates the chain | judgment |
| Non-assertive pattern matching | Introduce pattern matching over a parameter, Struct guard to matching, Equality guard to pattern matching | judgment |
| Boolean arguments switching behaviour | Introduce pattern matching over a parameter, Function clauses to/from case clauses (towards clauses) | judgment |
| Nested `if` inside `case` | Replace a nested conditional in a "case" statement with guards | judgment |
| Complex else clauses in with, `with` blocks with sprawling `else` | Moving "with" clauses without pattern matching; Remove redundant last clause in "with" only once the `else` is gone | judgment, partial: they tidy the head; an `else` that normalises many errors still wants private functions that return one error shape |
| Pipe operator on a single function call | Remove single pipe | judgment |
| Exceptions for control flow | Moving error-handling mechanisms to supervision trees, when the rescue only resets state | judgment |

Two catalog entries can introduce a smell; the catalog warns about both. Struct field
access elimination can produce Complex extractions in clauses, and Converts guards to
conditionals can produce a Long Function. A third, Simplifying pattern matching with
nested structs, replaces a nested pattern with a chain of field accesses and drops the
struct checks the pattern made.

No close entry: dynamic atom creation, namespace trespassing, non-assertive map access
and truthiness, structs with 32+ fields, alternative return types, boolean obsession,
unrelated multi-clause functions, app config for libraries, sending unnecessary data,
the compile-time and code-generation anti-patterns, and Refused Bequest. Fix those from
elixir-crafting's anti-pattern catalog instead.

## Pick the direction

Several entries run both ways, and a few point against rules in elixir-crafting and
nvieirafelipe-elixir-xp. The repository's documented standards decide first, then those
skills. The catalog lists safe moves; it does not say which end state is better.

| Entry | Prefer | Why |
|---|---|---|
| Converts guards to conditionals | The opposite moves: Replace a nested conditional in a "case" statement with guards, or Introduce pattern matching over a parameter | Assertive style: pattern matching in function heads over branching |
| Function clauses to/from case clauses | Towards function clauses | Same rule |
| Transform nested "if" statements into a "cond" | Function clauses when the conditions test arguments; `cond` otherwise | Same rule; `cond` is the fallback, not the goal |
| Grouping parameters in tuple | Straight to a struct or map (From tuple to struct) | elixir-crafting groups related data in maps or structs |
| Default value for an absent key in a Map | Only for keys that may be absent | For a required key, `map.key` or a pattern fails fast; `Map.get/3` hides the bug |
| Simplifying checks by using truthness condition | Only when the value cannot be `false` | `x \|\| default` also replaces `false`, which the `is_nil/1` version kept |
| Simplifying pattern matching with nested structs | Keep the nested pattern when the clause must reject other shapes | Assertive style: the pattern checks each struct; the chain of field accesses does not |
| Introduce processes / Remove processes | Processes only for runtime needs: concurrency, state, fault isolation | elixir-crafting: processes are not code organisation |
| Behaviour extraction / Behaviour inlining | Extract once a second implementation exists | YAGNI |
| Extract function / Inline function, Extract expressions / Temporary variable elimination, Introduce import / Remove import attributes, Merging multiple definitions / Splitting a definition, Transform to list comprehension and Nested list functions to comprehension / List comprehension simplifications, Widen or narrow definition scope, Add or remove a parameter | Whichever reads better at the call site in this codebase | Pure inverses; the project's existing style decides |

## Use it in a review

Name the refactoring, link the entry, and say why its side-conditions hold here and why
its Caution, if it has one, does not apply:
"possible Long Function: *Introduce pattern matching over a parameter* would split
`price/2` into one clause per `:currency`; every caller passes an atom, so the clauses
cover the same inputs." A refactoring opportunity is Consider, unless a documented
standard requires the change. Entries that change runtime behavior (see the rules above)
also get a Behavior check: what changes at runtime, and would a test notice.
guided-pr-review loads this skill for Elixir diffs and sets the rest of the format.

## Index

Open the group file for the entry: its example, side-conditions and upstream link.

The examples are upstream's code, trimmed but not corrected. Read them as shapes, not
code to paste: a few do not compile, and 21 change behavior while the catalog presents
them as behavior-preserving. Those 21 carry a "Caution (this skill, not upstream)" note,
as do 8 entries whose move is unsafe on code their side-conditions do not rule out.
[references/sources.md](references/sources.md#upstream-slips) lists every slip.

### Elixir-specific (14): features unique to Elixir

| Refactoring | When |
|---|---|
| [Alias expansion](references/elixir-specific.md#alias-expansion) | A multi-alias such as `alias Foo.Bar.{Baz, Boom}` makes a dependency hard to search for in a large code base. |
| [Default value for an absent key in a Map](references/elixir-specific.md#default-value-for-an-absent-key-in-a-map) | Code calls `Map.has_key?/2` in an `if...else` to return either the key's value or a default. |
| [Defining a subset of a Map](references/elixir-specific.md#defining-a-subset-of-a-map) | Code builds a new map from some key/value pairs of a large map by reading each key by hand. |
| [Modifying keys in a Map](references/elixir-specific.md#modifying-keys-in-a-map) | Code renames a map key by chaining `Map.get`, `Map.put`, and `Map.delete`, which takes many lines and gets worse with each key. |
| [Simplifying Ecto schema fields validation](references/elixir-specific.md#simplifying-ecto-schema-fields-validation) | A changeset lists the schema's fields by hand for `cast` and `validate_required/3`. |
| [Pipeline using "with"](references/elixir-specific.md#pipeline-using-with) | Nested `if..else` or `case` statements sequence function calls, and the code can become confusing. |
| [Pipeline for database transactions](references/elixir-specific.md#pipeline-for-database-transactions) | A function passed to `Ecto.Repo.transaction/2` runs a sequence of database operations. |
| [Transform nested "if" statements into a "cond"](references/elixir-specific.md#transform-nested-if-statements-into-a-cond) | Nested `if` statements test several conditions in turn, which in some situations is verbose, deeply indented, and hard to maintain. |
| [Explicit a double boolean negation](references/elixir-specific.md#explicit-a-double-boolean-negation) | A double negation (`!!value`) casts `false` and `nil` to `false` and anything else to `true`, but can hide the intent of the operation. |
| [Transform "if" statements using pattern matching into a "case"](references/elixir-specific.md#transform-if-statements-using-pattern-matching-into-a-case) | An `if` condition pattern-matches (`if {:ok, contents} = ...`) to control flow, which may compromise readability. |
| [Moving "with" clauses without pattern matching](references/elixir-specific.md#moving-with-clauses-without-pattern-matching) | A `with` starts or ends with a clause that has no `<-`, so it matches nothing and gains nothing from the `with`, which can confuse readers. |
| [Remove redundant last clause in "with"](references/elixir-specific.md#remove-redundant-last-clause-in-with) | The last clause of a `with` matches a pattern identical to the value the `with` returns when every pattern matches, so the clause is redundant. |
| [Replace "Enum" collections with "Stream"](references/elixir-specific.md#replace-enum-collections-with-stream) | A pipeline runs several eager `Enum` operations over a large collection, and each one builds an intermediate collection. |
| [Generalise a process abstraction](references/elixir-specific.md#generalise-a-process-abstraction) | A `Task` or `Agent` is used beyond its purpose, for example a `Task` that runs as a long-lived server and keeps exchanging messages with clients. |

### Traditional (25): mostly from Fowler's catalog, or independent of language

| Refactoring | When |
|---|---|
| [Rename an identifier](references/traditional.md#rename-an-identifier) | An identifier's name does not convey its purpose. |
| [Moving a definition](references/traditional.md#moving-a-definition) | A function, macro or struct uses another module's data or functions more than its own, or another module uses it more. |
| [Add or remove a parameter](references/traditional.md#add-or-remove-a-parameter) | A function needs more information from its callers, or no longer needs some of what they pass. |
| [Grouping parameters in tuple](references/traditional.md#grouping-parameters-in-tuple) | A long parameter list makes a function's interface confusing and bug-prone. |
| [Reorder parameter](references/traditional.md#reorder-parameter) | A function's parameter order does not keep related concepts together, which confuses callers and invites errors that go unnoticed. |
| [Extract function](references/traditional.md#extract-function) | A function serves several purposes and grows long, often with comments that explain a run of lines. |
| [Inline function](references/traditional.md#inline-function) | A function body only delegates to another call, so its purpose is as clear as its name and keeping it adds nothing. |
| [Folding against a function definition](references/traditional.md#folding-against-a-function-definition) | Some code duplicates what an existing function computes. |
| [Extract constant](references/traditional.md#extract-constant) | Magic numbers appear directly in expressions, or one number is scattered across the codebase. |
| [Temporary variable elimination](references/traditional.md#temporary-variable-elimination) | Temporary variables only hold a result to return or an intermediate value. |
| [Extract expressions](references/traditional.md#extract-expressions) | An expression is large and hard to understand, or repeats. |
| [Splitting a large module](references/traditional.md#splitting-a-large-module) | A module does the work of two or more and becomes large, poorly cohesive, and hard to maintain. |
| [Remove nested conditional statements in function calls](references/traditional.md#remove-nested-conditional-statements-in-function-calls) | Nested conditional statements, such as a `case` passed as a function argument, can hurt readability without need. |
| [Move file](references/traditional.md#move-file) | A project file containing code (modules, macros, structs) belongs in another directory. |
| [Remove dead code](references/traditional.md#remove-dead-code) | Unused code makes a codebase longer and harder to maintain. |
| [Introduce a temporary duplicate definition](references/traditional.md#introduce-a-temporary-duplicate-definition) | A change to some code needs trying out without losing the original definition. |
| [Introduce overloading](references/traditional.md#introduce-overloading) | A function needs a variation for use in another context. |
| [Remove import attributes](references/traditional.md#remove-import-attributes) | `import` shortens calls but hides where a called function comes from, which hurts readability. |
| [Introduce import](references/traditional.md#introduce-import) | Calls use fully qualified names (`Module.function(args)`) for another module's functions. |
| [Group Case Branches](references/traditional.md#group-case-branches) | A divide-and-conquer function handles its base cases and recursive cases in a single `case`. |
| [Move expression out of case](references/traditional.md#move-expression-out-of-case) | The same expression ends every branch of a `case`. |
| [Simplifying checks by using truthness condition](references/traditional.md#simplifying-checks-by-using-truthness-condition) | Code uses `is_nil/1` and an `if`/`else` block to return a default when a value is `nil`. |
| [Reducing a boolean equality expression](references/traditional.md#reducing-a-boolean-equality-expression) | A boolean expression chains several equality comparisons of the same variable with `or`. |
| [Transform "unless" with negated conditions into "if"](references/traditional.md#transform-unless-with-negated-conditions-into-if) | An `unless` tests a negated condition, so the block runs only when a negated condition is not met, which is confusing. |
| [Replace conditional with polymorphism via Protocols](references/traditional.md#replace-conditional-with-polymorphism-via-protocols) | A conditional picks its action by data type, and the same `if..else`, `case` or `cond` sequence repeats or grows with each new type (Switch Statements). |

### Functional (32): pattern matching, higher-order functions and other FP features

| Refactoring | When |
|---|---|
| [Generalise a function definition](references/functional.md#generalise-a-function-definition) | Functions in one module have equivalent expression structures, the Duplicated Code smell. |
| [Introduce pattern matching over a parameter](references/functional.md#introduce-pattern-matching-over-a-parameter) | A function branches on its parameter values with `if`, `unless`, `cond` or `case`, and grows into a Long Function. |
| [Turning anonymous into local functions](references/functional.md#turning-anonymous-into-local-functions) | The same anonymous function is defined at several points (Duplicated Code). |
| [Merging multiple definitions](references/functional.md#merging-multiple-definitions) | Complementary functions, such as `take/2` and `drop/2`, contain near-identical code (Duplicated Code). |
| [Splitting a definition](references/functional.md#splitting-a-definition) | A recursive function returns a tuple; split it into one recursive function per element. The inverse of Merging multiple definitions. |
| [Inline macro](references/functional.md#inline-macro) | A macro does what a function or an existing language construct could (Unnecessary Macros). |
| [Transforming list appends and subtracts](references/functional.md#transforming-list-appends-and-subtracts) | Code calls `Enum.concat/2` to append to a list or `Enum.reject/2` to subtract elements from one. |
| [From tuple to struct](references/functional.md#from-tuple-to-struct) | Code passes a tuple whose elements cannot be named, which exposes details of the data representation and makes the code less readable. |
| [Struct guard to matching](references/functional.md#struct-guard-to-matching) | A guard calls `is_struct/1` or `is_struct/2` for a check that pattern matching alone can do, which makes the code verbose and less readable. |
| [Struct field access elimination](references/functional.md#struct-field-access-elimination) | A function accesses struct fields directly, in its guard or its body. |
| [Equality guard to pattern matching](references/functional.md#equality-guard-to-pattern-matching) | A variable extracted from a struct field is used only in an equality comparison in a guard. |
| [Static structure reuse](references/functional.md#static-structure-reuse) | A function rebuilds identical tuples or lists at several points. |
| [Simplifying guard sequences](references/functional.md#simplifying-guard-sequences) | A guard holds redundant propositions, such as a type check beside a comparison that already implies the type. |
| [Converts guards to conditionals](references/functional.md#converts-guards-to-conditionals) | A multi-clause function tells its clauses apart with guards. |
| [Widen or narrow definition scope](references/functional.md#widen-or-narrow-definition-scope) | Turn an anonymous function nested in a named one into a named function, or a named function into a nested anonymous one. |
| [Introduce Enum.map/2](references/functional.md#introduce-enummap2) | A list expression generates each element by calling the same function. |
| [Merging match expressions into a list pattern](references/functional.md#merging-match-expressions-into-a-list-pattern) | A function has a series of match expressions. |
| [Function clauses to/from case clauses](references/functional.md#function-clauses-tofrom-case-clauses) | Map a multi-clause function's clauses onto one `case` in a single clause, or the reverse. |
| [Transform a body-recursive function to a tail-recursive](references/functional.md#transform-a-body-recursive-function-to-a-tail-recursive) | A recursive function makes its recursive call somewhere other than as the last operation before returning (body recursion). |
| [Eliminate single branch](references/functional.md#eliminate-single-branch) | A control statement has only one possible flow, such as a `case` statement with a single branch. |
| [Transform to list comprehension](references/functional.md#transform-to-list-comprehension) | Code calls `Enum.map/2` or `Enum.filter/2` to build a new list from an existing one. |
| [Nested list functions to comprehension](references/functional.md#nested-list-functions-to-comprehension) | Nested `Enum.map/2` and `Enum.filter/2` build a new list, visiting the original more than once. |
| [List comprehension simplifications](references/functional.md#list-comprehension-simplifications) | A one-generator comprehension becomes `Enum.map/2` or `Enum.filter/2`; the inverse of the two comprehension entries above. |
| [Closure conversion](references/functional.md#closure-conversion) | An anonymous function is a closure: it accesses variables outside its scope. |
| [Replace pipeline with a function](references/functional.md#replace-pipeline-with-a-function) | A pipeline of built-in higher-order functions, such as `Enum.filter/2 \|> Enum.count/1`, does what one function call can do. |
| [Remove single pipe](references/functional.md#remove-single-pipe) | A pipe has only two members: a variable or zero-arity function call, then a call to a function of arity one or more. |
| [Simplifying pattern matching with nested structs](references/functional.md#simplifying-pattern-matching-with-nested-structs) | A function clause pattern matches deep into nested structs to extract a value, which makes the code messy and hard to understand. |
| [Improving list appending performance](references/functional.md#improving-list-appending-performance) | Code appends elements to the end of a list. |
| [Convert nested conditionals to pipeline](references/functional.md#convert-nested-conditionals-to-pipeline) | Nested conditionals such as `if..else` and `case` sequence calls to functions that return `{:ok, _}` or `{:error, _}`, which makes the code confusing. |
| [Replacing recursion with a higher-level construct](references/functional.md#replacing-recursion-with-a-higher-level-construct) | A function iterates by hand-written recursion where a built-in such as `Enum.reduce/3` would do. |
| [Replace a nested conditional in a "case" statement with guards](references/functional.md#replace-a-nested-conditional-in-a-case-statement-with-guards) | A `case` clause nests an `if..else` to perform a more complex check. |
| [Replace function call with raw value in a pipeline start](references/functional.md#replace-function-call-with-raw-value-in-a-pipeline-start) | A pipeline starts with a function call instead of a raw value. |

### Erlang-specific (11): OTP, typespecs and behaviours

| Refactoring | When |
|---|---|
| [Typing parameters and return values](references/erlang-specific.md#typing-parameters-and-return-values) | A named function has no typespec. |
| [Moving error-handling mechanisms to supervision trees](references/erlang-specific.md#moving-error-handling-mechanisms-to-supervision-trees) | A process handles errors in a defensive style, such as `try..rescue` in a `GenServer` callback. |
| [From meta to normal function application](references/erlang-specific.md#from-meta-to-normal-function-application) | Code calls `apply/3`, which takes the module, function name, and argument list at runtime, although all three are known at compile time. |
| [Remove unnecessary calls to length/1](references/erlang-specific.md#remove-unnecessary-calls-to-length1) | A function calls `length/1` in guards to check whether a list is empty. |
| [Add type declarations and contracts](references/erlang-specific.md#add-type-declarations-and-contracts) | A data structure recurs in typespecs, such as a tuple of three integers in a `@spec`. |
| [Introduce processes](references/erlang-specific.md#introduce-processes) | One process, such as a singleton `GenServer`, serves many clients and becomes a bottleneck. |
| [Remove processes](references/erlang-specific.md#remove-processes) | Code uses processes, callbacks, and message passing for work a regular module could do with function calls. |
| [Add a tag to messages](references/erlang-specific.md#add-a-tag-to-messages) | Processes exchange untagged messages, so the receiver treats every message the same way whatever its format. |
| [Register a process](references/erlang-specific.md#register-a-process) | Senders address a process by its PID, so each sender must know that ID. |
| [Behaviour extraction](references/erlang-specific.md#behaviour-extraction) | A function could recur in different modules, playing a special role in each. |
| [Behaviour inlining](references/erlang-specific.md#behaviour-inlining) | A behaviour instance implements callbacks that should be eliminated. |

## Credits

The refactorings, their examples and their side-conditions come from the [Catalog of
Elixir Refactorings][catalog] (MIT, copyright Lucas Francisco da Matta Vegi), condensed
at commit `e40dc9e`. The smell map, the direction table and the rules above are this
skill's own. [references/sources.md](references/sources.md) says what was kept and how
to update it; [LICENSES.md](LICENSES.md) reproduces the license.

[catalog]: https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md
