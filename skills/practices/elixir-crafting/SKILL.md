---
name: elixir-crafting
description: Applies XP discipline and Elixir anti-pattern awareness when writing, reviewing, fixing, or refactoring Elixir code. Use when working on .ex/.exs files, implementing features, reviewing pull requests, or debugging in Elixir projects.
---

STARTER_CHARACTER = 🔨⚗️

## Core loop

Every code change follows this cycle:

1. **Write a failing test** for the behaviour you want
2. **Implement the simplest thing** that makes it pass
3. **Refactor** to remove duplication and improve clarity
4. **Review** the result against anti-patterns and design
   rules before committing

Do not skip steps. Do not combine steps. Wear one hat at a
time — either adding functionality or refactoring, never both.

## Simple design rules (Beck)

Code is well-designed when, in priority order:

1. It passes all tests
2. It reveals intention — a reader understands *what* and
   *why* without comments
3. It has no duplication of logic (once and only once)
4. It uses the fewest modules, functions, and abstractions
   needed

When in doubt, remove complexity. It is cheaper to add it
later when you understand the need than to carry speculative
abstractions now. YAGNI.

## Writing code

### Assertive style

Elixir code should fail fast on unexpected input. Prefer:
- Pattern matching in function heads over conditional branching
- `map.key` (static access) over `map[:key]` for required keys
- `and`/`or`/`not` over `&&`/`||`/`!` for boolean operands
- Separate function clauses over multi-branch `case`/`cond`

### Function design

- One return type per function — do not change the return
  shape based on options. Split into separate functions.
- Keep parameter lists short — group related data in maps
  or structs when a function takes more than 3 arguments.
- Avoid boolean parameters that switch behaviour. Use atoms
  to represent distinct states (`:admin`, `:editor`, not
  `admin: true, editor: false`).
- Use multi-clause functions only when clauses handle the
  same concept. Unrelated logic gets separate functions with
  specific names.

### Naming and communication

- Module, function, and variable names are the primary
  documentation. Rename before adding a comment.
- Comments explain *why*, never *what*. If code needs a
  *what* comment, rename or restructure.
- Module attributes for domain constants
  (`@five_min_in_seconds 300`) instead of magic numbers.

### Typespecs

- Write `@spec` for every public function.
- Use custom types (`@type`) for domain concepts instead of
  raw primitives — `@type postal_code :: String.t()` over
  bare `String.t()`.
- Specs serve as documentation and enable Dialyzer to catch
  contract violations early.

### Structs and data

- Keep structs under 32 fields — beyond that the BEAM
  switches from flat to hash map representation, losing
  memory optimisation.
- Group optional fields in a nested map or separate struct.
- Use structs for domain concepts; use maps for transient
  or unstructured data.

## Testing

- Write the test before the implementation (red-green-refactor).
- Match the project's existing patterns for factories, setup
  blocks, and assertion style.
- Use factories for test data — never inline structs or direct
  Repo calls in test setup.
- Never mock modules unless they implement a behaviour.
- When a test fails 3 times, stop and diagnose. Do not retry
  blindly.

## Refactoring

Refactoring is a separate activity from feature work. When
refactoring:
- The system behaviour does not change
- All tests pass before and after
- Each refactoring step is small and independently verifiable
- Commit refactoring separately from feature changes

Triggers for refactoring:
- Duplicated logic across modules
- A function that is hard to name (doing too many things)
- A change requires touching many unrelated files
- A new developer cannot understand a module in 5 minutes

## Reviewing code

When reviewing Elixir code (your own or others'), check
against known anti-patterns. See
[references/anti-patterns.md](references/anti-patterns.md)
for the complete catalogue with examples and fixes.

Quick review checklist:
- Does the code follow the assertive style? (fail fast, no
  silent nils)
- Are functions single-purpose with consistent return types?
- Are there any `with` blocks with complex `else` clauses?
- Is `String.to_atom/1` used on external input?
- Are processes used for code organisation instead of
  runtime concerns?
- Is process interaction scattered across multiple modules?
- Are macros used where functions would work?
- Does `use` import more than needed?

## Process design

- Processes model runtime properties (concurrency, state,
  fault isolation) — not code organisation.
- All long-running processes live in a supervision tree.
- Centralise process interaction in one module — do not
  scatter `GenServer.call` across consumers.
- Extract data before sending to a process — do not copy
  large structures (like `conn`) across process boundaries.

## Continuous feedback

- Run `mix compile --warnings-as-errors` after every change.
- Run `mix format --check-formatted` before committing.
- Run `mix dialyzer` to validate typespecs.
- Run `mix credo --strict` for style consistency.
- Run relevant tests after each logical change, full suite
  before committing.

## XP practices in context

For the detailed mapping of XP practices to Elixir
development, see
[references/xp-elixir.md](references/xp-elixir.md).

The practices that matter most for AI-assisted development:
- **Simple design** — resist the urge to over-abstract
- **TDD** — the test comes first, always
- **Refactoring** — continuous, small, safe improvements
- **Coding standards** — consistency enables collective
  ownership
- **Small releases** — each commit is a working increment
- **Sustainable pace** — do not rush; quality over speed
