# XP Practices Applied to Elixir

Extreme Programming practices mapped to Elixir development
and AI-assisted workflows.

## Values

### Communication

Elixir expresses communication through code:
- Module and function names tell the story
- Pipelines read as prose — data flows left to right
- Pattern matching in function heads documents expected
  shapes
- Typespecs declare contracts between modules
- Behaviours make interfaces explicit

When collaborating with AI, communicate intent clearly —
state what the code should do, not how to type it.

### Simplicity

Do the simplest thing that works. In Elixir:
- Prefer functions over GenServers for stateless logic
- Prefer `with` over nested `case` for multi-step
  operations
- Prefer pattern matching over conditional branching
- Avoid premature abstraction — three similar functions
  are better than one generic function with mode flags
- Let the standard library do the work — do not reimplement
  `Enum`, `Map`, or `String` operations

### Feedback

Elixir provides fast feedback loops:
- `iex` for interactive exploration
- `mix test --stale` for incremental test runs
- `mix compile --warnings-as-errors` catches issues early
- Dialyzer validates type contracts
- Credo enforces style consistency

Shorten the feedback loop. Run tests after every change,
not at the end of a feature.

### Courage

Courage means:
- Deleting code that is not pulling its weight
- Refactoring unfamiliar modules (collective ownership)
- Rewriting instead of patching when the design is wrong
- Raising concerns about complexity in code review
- Trusting the test suite and making bold changes

The test suite is the safety net that makes courage safe.

### Respect

- Do not commit code that breaks compilation or tests
- Do not introduce complexity that slows down peers
- Match the project's existing patterns and conventions
- Write code for the reader, not the writer

## Practices

### Test-Driven Development

The most important XP practice for Elixir:

1. Write a test that describes the desired behaviour
2. Run it — it should fail (red)
3. Write the minimum code to pass (green)
4. Refactor while tests stay green
5. Repeat

In Elixir, tests also serve as usage documentation. A
reader should understand how to call a module by reading
its test file.

### Simple design (Beck's 4 rules)

Applied to Elixir:

1. **Passes the tests** — all tests green, Dialyzer clean,
   no compiler warnings
2. **Reveals intention** — module names match domain
   concepts, function names describe actions, pattern
   matching documents data shapes
3. **No duplication** — extract shared logic into private
   functions within the same module before reaching for
   shared modules
4. **Fewest elements** — no speculative modules, no
   premature behaviours, no GenServers that could be
   functions

### Refactoring

Continuous improvement of existing code. Elixir-specific
refactoring opportunities:
- Extract complex `with` chains into named private
  functions
- Replace boolean options with separate function clauses
- Move process interaction from scattered modules into a
  single interface module
- Replace `String.to_atom/1` with explicit mappings
- Convert large structs to nested structures
- Replace macros with functions where possible

Each refactoring is a separate commit with no behaviour
change.

### Pair programming / AI-assisted development

When working with AI, the same principles apply:
- **Driver/navigator dynamic** — one writes, one reviews.
  The AI writes, you review. Or you describe intent, the
  AI implements.
- **Frequent rotation** — switch between AI writing code
  and you writing code. Do not delegate everything.
- **Shared understanding** — both you and the AI should
  understand the full context. Provide domain knowledge;
  let the AI provide language idioms.
- **Immediate review** — review each change as it happens,
  not in bulk at the end.

### Collective code ownership

Any developer can modify any module. This requires:
- Consistent coding standards (enforced by `mix format`
  and Credo)
- Comprehensive test coverage (enforced by TDD)
- Clear naming that does not require tribal knowledge
- Typespecs that document contracts without needing to
  read implementations

### Continuous integration

Every commit should:
- Compile without warnings
- Pass all tests
- Pass Dialyzer
- Pass Credo
- Be formatted with `mix format`

Integrate frequently. Small commits that each pass all
checks are better than large commits that "work together."

### Small releases

Each commit is a releasable increment:
- It compiles
- All tests pass
- It does not break existing functionality
- It adds or changes one logical thing

If a feature requires multiple steps, each step is a
commit that leaves the system in a working state.

### Coding standards

Elixir has strong conventions:
- `mix format` is the authority on style
- Credo enforces structural guidelines
- Module structure: moduledoc, typespecs, public functions,
  private functions
- Naming: snake_case for functions/variables, PascalCase
  for modules, SCREAMING_SNAKE for module attributes
- No trailing commas in argument lists
- Pipes start from a named value, not a function call

### Sustainable pace

- Do not optimise prematurely
- Do not add features "while you're in there"
- One change at a time — either add functionality or
  refactor, never both
- If a task is taking too long, stop and reassess the
  approach
