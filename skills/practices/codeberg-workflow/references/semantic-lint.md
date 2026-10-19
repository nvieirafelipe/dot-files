# Semantic Lint

Regex-based pre-commit scan for XP/testing antipatterns that
Credo, Dialyzer, and formatter cannot detect. Runs on staged
`*_test.exs` and `*.ex` files during `git commit`. Blocks the
commit (`exit 2`) on match.

## Curated patterns

Each pattern has a name, regex, rationale, and the rule it
enforces (linked to the authoritative source).

| # | Name | Regex | Enforces |
|---|------|-------|----------|
| 1 | Per-field assertion | `^\s*assert\s+\w+\.\w+\s*==` | Full-struct equality (user rule: *never per-field assertions*) |
| 2 | Tagged-tuple match in assertion | `assert\s+\{:ok,\s*\w+\}\s*=` | `assert subject == {:ok, expected}` form |
| 3 | Inline bare map/struct fixture | `assert.*=\s*%\{` or `(setup\|test).*=\s*%[A-Z]\w+\{` | Factories, never inline literals |
| 4 | Length-equals check | `length\(.+\)\s*==\s*\d+` | Pattern match on full list shape |
| 5 | Mock returning bare `:ok` | `expect\(.*,.*fn.*->\s*:ok\s*end\)` | Mocks return per-`@spec` values |
| 6 | Legacy atom list | `@\w+\s+\[:\w+(,\s*:\w+)+\]` | `~w(...)a` sigil for atom lists |
| 7 | `Factory` import from prod module | `alias\s+\w+\.Entity\.\w+,\s*as:\s*Factory` | Never call prod code to build fixtures |

## Hook snippet

Added to the PreToolUse `git commit` hook chain in `SKILL.md`,
*after* `mix format` and *before* the post-commit quality gate:

```bash
STAGED=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -E '\.(ex|exs)$')
[ -z "$STAGED" ] && exit 0

HITS=""
scan() {
  local name="$1" pattern="$2"
  local found
  found=$(echo "$STAGED" | xargs grep -nE "$pattern" 2>/dev/null)
  [ -n "$found" ] && HITS="$HITS\n[$name]\n$found\n"
}

scan "per-field-assertion"       '^\s*assert\s+\w+\.\w+\s*=='
scan "tagged-tuple-assertion"    'assert\s+\{:ok,\s*\w+\}\s*='
scan "inline-map-fixture"        'assert.*=\s*%\{'
scan "length-equals"             'length\(.+\)\s*==\s*[0-9]+'
scan "mock-returns-bare-ok"      'expect\(.*,.*fn.*->\s*:ok\s*end\)'
scan "legacy-atom-list"          '@\w+\s+\[:\w+(,\s*:\w+)+\]'

if [ -n "$HITS" ]; then
  printf '[codeberg-workflow] Semantic lint FAILED:\n%b\n' "$HITS" >&2
  echo 'Fix or override by adding `# lint:ignore <pattern-name>` on the offending line.' >&2
  exit 2
fi
exit 0
```

## Override protocol

A commit that *intentionally* violates a pattern (e.g. testing a
formatter's own behavior on `%{...}`) can add `# lint:ignore
<pattern-name>` on the same line. The scan `grep -v` filters
those lines before reporting. Overrides must be justified in the
commit message.

## Backlog

Growing list of candidate patterns observed in PR review or
Claude sessions but not yet promoted to the curated list above.
Promote when a pattern is flagged twice or more across
stories/issues.

<!-- Append `- <pattern-name> — <regex> — <source>` entries here. -->

- destructure-then-tuple-assert — `^\s+%\{[a-z_]+: [a-z_]+, [a-z_]+: [a-z_]+[^}]*\} = [a-z_.]+$`
  on added lines in `test/` (older tests may match, so scan the diff only) — first seen in a
  pre-PR review

Format:

```
- <pattern-name> — `<regex>` — first seen in issue-<N>, flagged again in issue-<M>
```

## When to add a new pattern

Triggers (any one is enough):

1. **PR discussion repeats itself** — a reviewer (human or
   agent) flags the same issue on two PRs within a short window.
2. **Claude self-correction repeats** — the worklog Error log
   shows the same class of mistake resolved twice.
3. **Custom Credo check is infeasible** — the pattern requires
   cross-file context or is cheaper as a regex than as a Credo
   AST walk.

Procedure:

1. Draft the regex against the offending test/file. Verify it
   matches the antipattern without false positives on the rest
   of the repo (`grep -rnE '<regex>' lib/ test/`).
2. Append to the [Backlog](#backlog) with a one-line rationale
   and links to both occurrences.
3. On the next story/issue, promote the entry to the curated
   table, add the `scan` line to the hook snippet, and remove
   from the backlog.

## When to promote to a Credo check

A regex is a transient scaffold. Promote to a repo-local Credo
check (under `.credo.exs` + a `Credo.Check.*` module) when:

- The pattern needs AST context (e.g. only flag in `test/` files,
  only flag inside `describe/test` blocks, only flag on public
  functions).
- Three or more repos would benefit.
- The regex has collected false-positive overrides and needs
  stronger filtering.

After the Credo check ships, remove the regex from this file.
