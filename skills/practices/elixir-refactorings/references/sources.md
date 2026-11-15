# Sources and local decisions

Read this when maintaining the skill, not when using it.

## The catalog

[lucasvegi/Elixir-Refactorings][repo], `README.md` at commit [`e40dc9e`][readme]
(2025-05-08), by Lucas Francisco da Matta Vegi and Marco Tulio Valente, ASERG/DCC/UFMG.
MIT; the notice is in [LICENSES.md](../LICENSES.md). Collected on 2026-11-14. The
authors ask that uses of the catalog cite their 2025 paper (see "The papers"); the
citation is in the Credits section of `SKILL.md`.

The catalog holds 82 refactorings in four groups: 14 Elixir-specific, 25 traditional, 32
functional and 11 Erlang-specific. Its introduction says 55 came from a review of the
scientific literature on other functional languages, 21 from a review of grey literature
(blogs, forums, talks), and 6 from a study mining software repositories. 27 entries
carry a `Source:` line: 21 grey literature, 5 mining study, 1 extended literature
review. The paper's dataset names a sixth refactoring from the mining study, Remove
processes, which the README leaves untagged (see "The papers"). By the counts, the
other 54 untagged entries are the 2023 short paper's literature-review set; the
dataset's SLR sheet uses older names, so this was not matched name by name.

Upstream fields per entry: name, category, motivation, examples, and, for some entries,
side-conditions and mechanics. 71 entries have a side-conditions field, but three keep
their conditions inside HTML comments (Pipeline for database transactions, Transform
nested "if" statements into a "cond", Generalise a process abstraction), and Pipeline
using "with" comments out two of its three. Commented-out conditions count as not
stated, so 14 entries say "None stated". Only Rename an identifier has a mechanics
field.

## What the reference files keep

- The name, exactly as upstream, so a name in a review comment or commit message can be
  searched in the catalog.
- **When:** the motivation, condensed. Smells named upstream are kept.
- **Before / After:** one example pair, trimmed to the lines that change. The code is
  upstream's, not modernised or corrected.
- **Side-conditions:** every one upstream states, condensed. They are what makes a
  refactoring safe to propose, so none was dropped. "None stated" where upstream is
  silent.
- **Mechanics** for Rename an identifier, the one entry upstream gives them for.
  **Steps** in Add a tag to messages, Behaviour extraction and Behaviour inlining:
  upstream labels no mechanics there, and the steps summarise its motivation and
  example.
- **Reverse** where upstream names an inverse.
- **Caution (this skill, not upstream)** where an upstream example changes behavior, or
  where the move is unsafe on code its side-conditions do not rule out; see "Upstream
  slips".
- Third-party example credits as upstream gives them, and a link to each entry's line at
  the pinned commit, which carries the full text and the remaining examples.

Left out: extra examples, the introduction's call for community feedback, navigation
links, and the acknowledgments. [RefactorEx][refactorex], a VS Code extension the
catalog's introduction says can apply some of these refactorings semi-automatically, is
not used by the skill.

## Upstream slips

On 2026-11-15, every example with code was run on Elixir 1.19.4 and Erlang/OTP 28: the
before and after code as written, stubs only for placeholders, and the same inputs for
both, edge cases included. The Ecto examples ran on Ecto 3.13 against an in-memory
SQLite database. Each finding below is upstream's: every code line in the reference
files appears in the README entry it links to. Line numbers are at `e40dc9e`. The
examples that entries borrow from [Elixir-Code-Smells][smells] were read at commit
`2c2ed33` (2024-09-12).

### Examples that change behavior

The catalog presents these as behavior-preserving. Each entry carries a "Caution (this
skill, not upstream)" note with the difference and how to avoid it.

- Defining a subset of a Map: `Map.take/2` leaves out absent keys, which the hand-built
  map stored as `nil`.
- Modifying keys in a Map: with `"latitude"` absent, no `"lat"` key is added; with
  `"lat"` already present, which value survives depends on iteration order.
- Simplifying Ecto schema fields validation: `__schema__(:fields)` includes `:id`, which
  the hand-written list left out, so every changeset without an id fails.
- Pipeline using "with": the after code returns `valid_move`'s own error, where the
  before code returned `{:error, :invalid_move}`. The upstream side-condition that would
  prevent this is inside an HTML comment (README line 421).
- Pipeline for database transactions: `Repo.transaction/1` on a Multi returns a map of
  changes or a four-element error tuple, and the public `update_refused_challenges/2`
  returns a changeset instead of writing.
- Transform "if" statements using pattern matching into a "case": the before code raises
  `MatchError` when the match fails; the after code calls `do_something_else()`.
- Generalise a process abstraction: `GenServer.call/2` times out after 5 seconds, where
  the bare `receive` waited forever (README line 951 says behavior stays the same).
- Folding against a function definition: `report/1` divides by `length(list)`, so the
  after code ignores `students_amount`.
- Introduce overloading: the new clause sits above the original and reprices orders the
  original handled (`150.0` on 25 December: `105.0` before, `15.0` after).
- Simplifying checks by using truthness condition: `price || "$100"` returns `"$100"`
  for `false`, where the `is_nil/1` version returned `false`.
- Converts guards to conditionals: the bare `raise FunctionClauseError` loses the
  module, function and arity from the error message.
- Transform a body-recursive function to a tail-recursive: float sums differ, because
  the accumulator adds in the opposite order.
- Simplifying pattern matching with nested structs: the after clause accepts other
  structs and plain maps, and raises `BadMapError` or `KeyError` where the before raised
  `FunctionClauseError`.
- Replacing recursion with a higher-level construct: `factorial(0)` returns `0`, since
  `1..0` counts down; negative arguments return a number where the before recursed
  without end; float sums differ; `sum_list/1` accepts ranges.
- Transforming list appends and subtracts: `[1, 2, 1] -- [1]` is `[2, 1]`; the
  `Enum.reject/2` form gives `[2]`.
- Moving error-handling mechanisms to supervision trees: the caller exits instead of
  getting a reply, and the restarted process starts from its initial value, although
  upstream says it restarts "with their last state" (README line 4465). The linked
  supervisor starts its children unlinked, so it never restarts them.
- Remove unnecessary calls to length/1: `[_|_]` matches improper lists that the guards
  rejected.
- Introduce processes: one task per write loses write order and read-after-write, and a
  failed write no longer crashes anything.
- Remove processes: the linked example turns `add/3` into `add/2`, which breaks the
  entry's own side-condition (README line 4698).
- Add a tag to messages: upstream says existing `send_msg/2` calls keep their behavior
  (README line 4760); they now send and return `{:msg, msg}`.
- Register a process: the receiver exits after one message, so a later send to its name
  raises `ArgumentError`.

### Traps the side-conditions miss

These examples behave the same, but the same move on other code does not, and no
side-condition rules that code out. Each entry carries a Caution note:

- Reducing a boolean equality expression: `in` compares strictly, so `1.0 in [1, 2]` is
  `false`.
- Equality guard to pattern matching: patterns compare strictly, so the pattern `1`
  rejects `1.0`.
- Simplifying guard sequences: since OTP 27, `f === 0.0` rejects `-0.0`, which
  `is_float(f) and f == 0.0` accepts.
- List comprehension simplifications: a generator with a pattern skips non-matching
  elements, where `Enum.map/2` raises.
- Replace a nested conditional in a "case" statement with guards: a guard needs `true`,
  where `if` takes any truthy value.
- Closure conversion: the returned function gains an argument, so callers that pass one
  argument raise `BadArityError`.
- Remove redundant last clause in "with": with an `else`, the removed clause's failure
  no longer reaches the `else`.
- Replace "Enum" collections with "Stream": side effects run in a different order.

### Differences on unusual input only

No Caution note; the entry's side-conditions cover them or the input is unlikely:

- Extract function: a failed match raises `FunctionClauseError` instead of
  `MatchError`.
- Remove dead code: the removed `v2 / 2` raised `ArithmeticError` for integers too large
  for a float, such as `10 ** 400`.
- Eliminate single branch: `CaseClauseError` becomes `MatchError`, as its second
  side-condition says.
- Improving list appending performance: element order changes, which its side-condition
  allows.
- Transforming list appends and subtracts: `++` needs a list on the left where
  `Enum.concat/2` takes any enumerable; the side-conditions limit it to lists.

### Code kept as written

The entries quote upstream, so these stay. Read them as shapes, not code to paste:

- Default value for an absent key in a Map: the before code's `if` has no `end`.
- Pipeline for database transactions: `Ecto.Multi.run/3` gets a one-argument function
  (README line 504); Ecto passes the repo and the changes so far, and raises
  `FunctionClauseError` otherwise.
- Generalise a process abstraction: `@impl` without `true` (line 972), and no `init/1`.
- Splitting a large module: `def calculate_shipping(zip_code, _), do` followed by a `do`
  block does not compile (line 1758), and `do: # something` is a placeholder that does
  not compile either.
- Move expression out of case: `Integer.is_odd/1` is a macro. Without `require Integer`
  the code compiles with a warning and raises `UndefinedFunctionError` when it runs.
- Convert nested conditionals to pipeline: the after code uses `marker`, which nothing
  binds.
- From tuple to struct: a three-element tuple becomes a four-field struct.

## The papers

The catalog cites two papers. "Understanding refactorings in Elixir functional language"
(Empirical Software Engineering 30, article 108, 2025,
[doi:10.1007/s10664-025-10652-y][emse]; [authors' copy][emse-pdf]) presents the
82-refactoring catalog. Its replication package, [Zenodo 11372758][zenodo], holds the
extraction sheets for each study. "Towards a Catalog of Refactorings for Elixir"
([ICSME 2023 NIER][icsme]) is the preliminary version, with 54 refactorings in three
groups.

Checked against the 2025 paper and its "Elixir Refactorings Prospection Dataset" sheet
on 2026-11-15:

- Every one of the 82 names appears in the paper's Tables 6 to 10, 17 and 18, in the
  same group as in the README. The group counts in its Table 5 (25, 32, 11, 14) and the
  provenance counts (55 literature review, 21 grey literature, 6 mining study) match.
- The paper's one-line description of each refactoring agrees with the entry's **When**
  text.
- The dataset's GLR and MSR sheets mark 21 and 6 refactorings as new. The 21 match the
  README's grey-literature tags, and five of the six match its mining-study tags. The
  sixth, Remove processes, was split from the literature review's "From function to
  process" (also listed as "Introduce/remove concurrency"), whose other half is
  Introduce processes; the README does not tag it.
- The ICSME paper's 54 split into 21 traditional, 23 functional and 10 Erlang-specific
  refactorings. Adding the tagged entries and Remove processes to each group gives the
  2025 counts.
- Section 3.2 says each repository entry gives its mechanics and side conditions. The
  README marks both fields optional, and only Rename an identifier has mechanics.

Not used by the skill: the paper's count of sources per refactoring, and its survey of
144 developers on the relevance and prevalence of each refactoring. Its Table 13 lists
nine refactorings that score high on the mean of the two: Extract function, Pipeline
using "with", Extract constant, Remove dead code, Extract expressions, Transform nested
"if" statements into a "cond", Rename an identifier, Moving a definition, and Reducing a
boolean equality expression. The least relevant were Introduce import (1.77 of 5), Group
case branches (1.84) and Introduce a temporary duplicate definition (2.19).

## Upstream discussion

The repository's four open issues report no slips in the examples. Two bear on how this
skill uses the catalog. In [issue #2][issue2], the author says an entry offers an
alternative to weigh, not a rule that the "before" code is wrong. In [issue #3][issue3],
the author says inverse pairs such as Introduce import and Remove import attributes are
intentional, as Extract and Inline are in Fowler's catalog. [Issue #4][issue4] questions
the name Replace pipeline with a function; the author kept it so that survey links would
not break.

## Local decisions

- **Smell map.** `SKILL.md` keys the catalog on the names its consumers already use: the
  twelve smells in guided-pr-review's `review-axes.md`, the official anti-patterns in
  elixir-crafting, and the anti-patterns in nvieirafelipe-elixir-xp. Upstream says nine
  smells are removed by specific entries; those rows say "catalog". Every other row is
  this skill's judgment and says so, including Unsupervised processes, whose entry only
  links the smell's corrected code (README line 4465).
- **Direction.** Several entries run both ways, and some point against rules in
  elixir-crafting and nvieirafelipe-elixir-xp (assertive map access, function heads over
  conditionals, structs over tuples). Project standards and those skills pick the
  direction; `SKILL.md` marks the entries.
- **Review severity.** A refactoring opportunity is Consider unless a documented
  standard requires it. Entries that change laziness, recursion or process structure
  also get a runtime check, since "behavior-preserving" there depends on side-conditions
  a diff rarely proves.
- **Layout.** `SKILL.md` carries the rules, the smell map and a one-line index; one
  reference file per upstream group holds the entries, so a lookup loads one group.

## Updating

1. `gh api repos/lucasvegi/Elixir-Refactorings/commits/main --jq .sha` for the new head.
2. Download its `README.md` and diff `grep -n '^### '` against the names in the four
   reference files. New, renamed or removed entries are the work.
3. Re-check changed entries against their upstream text, then replace the pinned SHA in
   every link (`git grep -l e40dc9e5f1b8d775f29dc25c4f47938a9c563770`) and fix the line
   numbers, which shift with any upstream edit.
4. Run each changed example, before and after, on the same inputs, and update its
   Caution note and "Upstream slips". Then recount the notes
   (`grep -c 'Caution (this skill' references/*.md`) and fix the "21" and "8" in the
   Index section of `SKILL.md`.

[repo]: https://github.com/lucasvegi/Elixir-Refactorings
[readme]: https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md
[refactorex]: https://github.com/gp-pereira/refactorex
[emse]: https://doi.org/10.1007/s10664-025-10652-y
[emse-pdf]: https://homepages.dcc.ufmg.br/~mtov/pub/emse2025-elixir-refactorings.pdf
[smells]: https://github.com/lucasvegi/Elixir-Code-Smells/tree/2c2ed33646a9c2bb9d8122c71cb2fafffbae6ac0
[zenodo]: https://doi.org/10.5281/zenodo.11372758
[icsme]: https://homepages.dcc.ufmg.br/~mtov/pub/2023-icsme-nier-elixir.pdf
[issue2]: https://github.com/lucasvegi/Elixir-Refactorings/issues/2
[issue3]: https://github.com/lucasvegi/Elixir-Refactorings/issues/3
[issue4]: https://github.com/lucasvegi/Elixir-Refactorings/issues/4
