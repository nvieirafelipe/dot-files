# Quality Enforcement

Three layers keep good practices applied and self-fixing. Each
layer catches what the layer below cannot. Nothing is duplicated;
each has a single responsibility.

| Layer | Catches | Fix mode | Where |
|-------|---------|----------|-------|
| **Mechanical gate** | Compile, format, Credo, test, Dialyzer, Playbill drift, ExUnit failures recorded in `plan.livemd` | Auto-fix (`mix format`) or block | Hooks in `SKILL.md` |
| **Semantic lint** | XP/testing antipatterns not expressible as a Credo rule | Block on commit | [semantic-lint.md](semantic-lint.md) |
| **Reviewer gate** | Design-level issues (naming, abstraction, factory coverage, doctest completeness) | Block on push/PR creation | [reviewer-gate.md](reviewer-gate.md) |

## Layer 1 — Mechanical gate (already wired)

Hooks in `SKILL.md` run:

- `mix format` (whole project) before every commit, then re-stage
  previously-staged `.ex/.exs` files (auto-fix). The formatter
  runs on the whole project so plugin-driven reordering (e.g.
  Quokka `autosort` reshuffling map fields across files) lands
  consistently. If `mix format --check-formatted` is still dirty
  after the auto-fix, the hook **blocks the commit** with a
  diff so the user can stage the remaining files explicitly.
- `mix compile --warnings-as-errors && mix format --check-formatted
  && mix credo --strict && mix test` after every commit (block on
  fail)
- Full suite + `mix dialyzer` + `playbill verify` on
  `plan.livemd` + a `grep` that fails the gate if the
  notebook's recorded output reports any ExUnit failure
  (`[1-9][0-9]* failure` line), before every push / PR
  creation (block on fail). See
  [solution-verifier.md](solution-verifier.md#the-two-pass-conditions)
  for the rationale of the two orthogonal checks.

**Known pitfall:** Quokka's `autosort` plugin reorders struct,
map, and schema fields alphabetically on `mix format`. If you
author fields in logical order and only run `mix format
--check-formatted` (which does NOT rewrite files) before a
commit, the commit will slip by the naked check but the
post-commit or pre-push gate will flip red on the next run.
Always run bare `mix format` (not just the check) before
committing, or rely on the pre-commit auto-fix hook above.

**Caveat for manual users:** `git commit --no-verify` skips
git-native hooks but **does not** skip Claude Code tool-use
hooks — those always fire. If you still see format errors
after a commit, check that your session PID is registered in
`.claude/.codeberg-workflow` (the gate hooks no-op outside
registered sessions).

When a hook blocks (`exit 2`), fixing the failure is the
highest-priority next action. Do not start a new step or respond
to unrelated requests until the gate passes.

## Layer 2 — Semantic lint (regex-based)

Runs on every `git commit`. Scans staged test files for patterns
that production tools (Credo, Dialyzer) cannot detect: per-field
assertions, bare `%{...}` fixtures, `{:ok, _} = ...` matches in
assertions, mocks returning bare `:ok`, and `length(x) == N`
checks.

See [semantic-lint.md](semantic-lint.md) for the full pattern
list, hook snippet, and override protocol.

## Layer 3 — Reviewer gate (human-in-the-loop)

Before push/PR creation, the pre-push hook requires an
**approved review artifact** at
`{SNIPPETS_DIR}/review.md`. The artifact is produced by running
the `nvieirafelipe-elixir-xp` pre-PR self-review (or spawning an
Elixir PR-review agent on the branch diff)
and recording findings + resolution + explicit `APPROVED` marker.

See [reviewer-gate.md](reviewer-gate.md) for the review.md
template, approval semantics, and the full checklist source.

## Growing the enforcement set

The regex list is intentionally small and curated. Every PR
discussion or Claude session that flags the *same* antipattern
twice is a signal the pattern belongs in semantic-lint. During
the PR phase, when reviewing planned vs actual work, scan the
worklog's Error log and PR review comments (human or agent) for
repeated corrections. If a pattern appears twice or more, append
it to the regex backlog in
[semantic-lint.md](semantic-lint.md#backlog) and promote it on
the next story/issue that touches the same area.

## Durable enforcement — custom Credo checks

Anything the semantic-lint regex catches is a candidate for
promotion to a repo-local Credo check. Credo checks survive
across skills, hook configs, and AI agents; regex hooks only fire
inside this workflow. When the same pattern is flagged three
times across stories/issues, lift it into
`.credo.exs` as a custom check — then remove the regex from
semantic-lint. The skill owns transient enforcement; the repo
owns permanent enforcement.
