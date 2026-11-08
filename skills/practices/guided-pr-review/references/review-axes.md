# Review axes

Three axes, reviewed independently. A change can pass one and fail another: code that
follows every convention can build the wrong thing, and code that does exactly what the
issue asked can break the repository's conventions. Tag every finding with its axis,
keep the axes in separate parts of the report, and name the worst item of each axis in
the summary. Do not let a pile of findings on one axis bury a single finding on another.

| Axis | Question | Report section |
|---|---|---|
| Spec | Does the change build what was asked? | "Spec", with the acceptance criteria table |
| Behavior | Does it work, stay safe, and stay fast, and would the tests notice if it broke? | Findings in each chapter, and "Tests and verification" |
| Design and standards | Does it follow the repository's documented standards and keep the code easy to change? | Findings in each chapter |

## Spec

Quote the spec line for each finding.

- **Missing or partial:** a requirement with no implementation, or one implemented for
  some inputs only.
- **Scope creep:** behavior nobody asked for. It may be fine; it still needs a reason.
- **Looks wrong:** implemented, but the implementation does not do what the spec says.
- **Not yet wired:** implemented but unreachable because no flow calls it yet. Say so,
  since it changes the severity of everything else in that code.

Build the acceptance criteria table from the spec: one row per criterion, a status (Met,
Partial, Missing, Pending, Not applicable), and the evidence.

## Behavior

### Correctness

- Edge cases: empty, missing, null, zero, boundary values, duplicates, very large inputs.
- Error paths, not only the happy path. What happens when a dependency fails or times
  out?
- Off-by-one errors, race conditions, ordering assumptions, and state that can go stale
  or inconsistent.
- Contract changes: a public function, payload, schema, configuration key, or log line
  that a consumer depends on.

### Security

- Input validated at the boundary where it enters the system.
- Data from outside (APIs, files, user content, configuration) treated as untrusted.
- Secrets kept out of code, logs, and error messages.
- Authentication and authorization checked where the change needs them.
- Queries parameterized and output encoded; no string-built SQL, shell, or HTML.
- New dependencies from trusted sources, with no known vulnerabilities.

### Performance

- N+1 queries, and calls inside loops that could be batched.
- Unbounded loops, fetches, or lists; missing pagination or limits.
- Blocking work on a hot path or a request path.
- Large allocations or repeated work in code that runs often.

Quantify when possible ("one query per offer, so 40 queries for a typical page") rather
than "could be slow".

### Tests

Read test names before the implementation; they state the intended behavior. Then ask:

- Do the tests check behavior, not implementation details?
- Are the edge cases and error paths above covered?
- Would a test fail if the change were broken? Answer by experiment when running code is
  allowed: invert one condition the change adds, run the suite, restore the file. A
  mutation that stays green is a finding that names the missing test case.
- Does a bug fix come with a test that fails without the fix?

### The author's verification

Check what the author says they ran against what the evidence shows: CI on the reviewed
head, the commands in the PR description, screenshots for UI changes, a before and after
for behavior changes. A claim with no evidence is `UNVERIFIED:`.

## Design and standards

### Documented standards

The repository's documented standards are the authority on style. Cite the rule with a
permalink at a commit and quote it. A breach of a documented rule can be Required. Skip
anything tooling already enforces. Grep the base branch for precedent before calling a
pattern a violation; precedent lowers the severity.

### Readability

- Names say what a thing does or holds, and match the project's vocabulary.
- Control flow is direct: no deep nesting, nested ternaries, or clever tricks.
- No dead code: unused variables, compatibility shims nothing uses, commented-out code.
  List dead code and ask before suggesting its deletion.
- Could the same behavior take fewer lines or fewer concepts?
- Comments explain intent that the code cannot; they do not narrate the code.

### Architecture

- Follows the existing patterns, or the new pattern has a reason.
- Module boundaries hold, and dependencies point in the right direction.
- A refactor reduces the number of concepts a reader must hold, rather than moving them
  somewhere else.
- Feature-specific logic stays out of shared modules; the change reuses the existing
  helper instead of adding a near-duplicate.
- Type boundaries are explicit. Question silent fallbacks, broad casts, and optional
  values that hide an unclear invariant.
- A new conditional bolted onto an unrelated flow is a design problem, not a nit.

### Code smell baseline

These come from chapter 3 of Martin Fowler's *Refactoring*. They apply even when the
repository documents nothing. Each is a judgment call, written as "possible Feature
Envy", never as a hard violation. A documented repository standard overrides the
baseline: where the repository endorses a pattern, suppress the smell.

| Smell | What it looks like in a diff | Usual fix |
|---|---|---|
| Mysterious Name | A name that does not say what the thing does or holds | Rename; if no honest name comes, the design is unclear |
| Duplicated Code | The same logic shape in more than one hunk or file | Extract the shared shape and call it from both places |
| Feature Envy | A function that uses another module's data more than its own | Move the function next to the data |
| Data Clumps | The same few fields or parameters travel together | Bundle them into one type |
| Primitive Obsession | A string or number standing in for a domain concept | Give the concept its own small type |
| Repeated Switches | The same conditional on the same type in several places | One dispatcher or lookup that both places share |
| Shotgun Surgery | One logical change forces scattered edits across many files | Gather what changes together into one module |
| Divergent Change | One module edited for several unrelated reasons | Split it so each part changes for one reason |
| Speculative Generality | Parameters, hooks, or abstractions the spec does not need | Delete them and inline until a real need appears |
| Message Chains | Long `a.b().c().d()` navigation | Hide the walk behind one function on the first object |
| Middle Man | A module or function that mostly delegates | Call the real target directly |
| Refused Bequest | An implementer that ignores most of what it inherits | Use composition instead of inheritance |

### Structural remedies

When a finding is structural, propose the move, not only the problem:

- Replace a chain of conditionals with a typed model or an explicit dispatcher.
- Collapse duplicate branches into one flow.
- Separate orchestration from business logic.
- Move feature logic out of a shared module into the module that owns the concept.
- Reuse the canonical helper instead of a near-duplicate.
- Make a type boundary explicit so the branching after it disappears.
- Delete a pass-through wrapper.
- Extract a helper, or split a large file.

Prefer the remedy that removes moving parts over one that spreads them around.

## Change-level checks

- **Size:** about 100 changed lines reads in one sitting, about 300 is fine for one
  logical change, and about 1000 should be split. A change that grows a file past about
  1000 lines is a signal to decompose first. Generated code, deletions, and mechanical
  refactors are exceptions.
- **Mixed purposes:** a refactor and a feature in one PR are two changes. For a stack,
  check that each PR compiles and passes on its own base.
- **Dependencies:** read the changelog for every bumped package, not only the version
  number; one dependency per change where possible; review the lockfile diff, including
  transitive changes; a hand-edited lockfile is a finding.
- **Description:** the PR title and body say what changed and why, and link the issue.
  With no PR yet, check the commit messages against the repository's convention
  instead.

## Severity

Label every finding. In posted comments, Required takes no prefix.

| Label | Meaning | Author action |
|---|---|---|
| Critical | Security hole, data loss, or broken behavior | Must fix before merge |
| Required | A real defect or a documented-standard breach | Fix before merge, or agree on a follow-up |
| Question | The evidence cannot settle it | Answer; the answer decides the rest |
| Consider | A suggestion worth weighing | Optional |
| Nit | Cosmetic or preference | Optional; ignore freely |
| FYI | Context, no action | None |

## Honesty

- Do not rubber-stamp. A verdict without evidence of review helps no one.
- Do not soften a real defect into "might be a minor concern".
- Push back on an approach with clear problems, and propose the alternative.
- When the author has context the reviewer lacks and disagrees, defer, and record why.
- Comment on the code, not the person.
