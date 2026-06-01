---
name: nvieirafelipe-elixir-xp
description: Applies personal Elixir XP practices (coding, testing, docs, commits) to personal Elixir repos (tostao, etc). Relaxed sibling of vio-elixir-xp — drops Vio-specific DB helpers, sigil requirement, LiveView conventions, and upstream sync, but still enforces core discipline.
paths: "**/*.ex,**/*.exs,**/mix.exs,**/.formatter.exs"
---

STARTER_CHARACTER = 🇧🇷👨🏽‍💻

# Personal Elixir XP (nvieirafelipe)

Curated rules for shipping Elixir in personal repos (tostao, side projects). Composes with generic XP/TDD/Elixir skills. Drops employer-specific rules (DynamoDB helpers, `~w(...)a` sigil requirement, LiveView conventions, upstream sync). Keeps the core testing and coding discipline.

## Protected branches — `main` and `master` are off-limits

NEVER touch `main` or `master` directly. No exceptions, no "temporary" detours.

Forbidden without explicit user instruction naming the branch:
- `git checkout main` / `git switch main` / `git checkout master` / `git switch master`
- `git commit` while `HEAD` is on `main`/`master`
- `git merge <x>` while on `main`/`master` (local merges included — no "I'll merge then branch")
- `git rebase <x>` onto a workspace positioned on `main`/`master`
- `git push` to `origin/main` or `origin/master`, force or not
- `git reset` / `git restore` that rewrites `main`/`master`
- Cherry-pick, apply patch, stash pop, or any write onto `main`/`master`
- Creating a PR with base branch `main`/`master` without user confirmation of the target

Required flow for every change:
1. Confirm current branch is NOT `main`/`master` before any write: `git rev-parse --abbrev-ref HEAD`.
2. If on `main`/`master`, create a feature branch first: `git checkout -b <feature>`.
3. All commits, rebases, resets happen on the feature branch.
4. Integration with `main`/`master` happens only via PR reviewed and merged by the user on the remote. Never locally.

If a task seems to require a direct write to `main`/`master` (hotfix, revert, sync), STOP and ask the user. They decide, not the tool.

## When this skill applies

- Editing `*.ex` / `*.exs` in personal Elixir repos (tostao, spikes, side projects).
- Reviewing Elixir changes in same.
- Preparing a PR — use the pre-PR self-review checklist below.

## Compose with installed skills

Defer to these for generic discipline; this skill layers personal-specific rules on top.

- `xp` — TUBE simple design, YAGNI, refactor mercilessly, courage.
- `elixir-crafting` — assertive style, single return shape, typespecs, formatter/credo feedback loop.
- `tdd` — red-green-refactor cadence.
- `refactoring` — when code gets messy.

If a companion skill is missing, the matching reference file in this skill captures the rule so the practice still applies.

## What differs from vio-elixir-xp

Drops:
- DB-backed assertion helpers (`assert_persisted_schema`, `put_loaded_state`) — personal projects will define their own DB test helpers as needed.
- `~w(...)a` sigil requirement for atom lists — bare `[:a, :b, :c]` is fine.
- LiveView conventions — no LV in personal repos currently.
- Vio upstream sync, SessionStart hook, `references/upstream/`.
- Dialyzer as mandatory — optional, run only if `mix dialyzer` is configured.

Adds / changes:
- Alphabetical key ordering extends to **all maps and structs**, not only Ecto schema / migration / TypedStruct defs. Every literal, every pattern match.

Keeps (from vio):
- Full-struct equality assertions.
- Subject alias + blank line.
- Named setup returns `{:ok, kw}` tuple.
- Factories mandatory — no inline `%{}` / `%Mod{}` literals in tests, no production builders for fixtures (exception: subject under test).
- Parameterized tests via module-level `for` + `@tag`.
- Mocks return per-`@spec` values, never generic `:ok`.
- No boolean args — tagged atoms + function heads.
- No nested `if` in `case` — flatten via `with` / `else`.
- `@doc` with `## Examples` + `@spec` on every public function.
- Realistic UUIDs in doctest samples.
- Commit split by architectural layer, verify split preserves tree.

## Reference layout

- [references/testing.md](references/testing.md) — Subject alias, describe/test naming, full-struct equality, factories, parameterized tests, mocks, shared setups.
- [references/coding.md](references/coding.md) — module structure, naming, pattern matching, `with` vs `case`, no boolean args, full alphabetical ordering.
- [references/documentation.md](references/documentation.md) — `@doc` `## Examples`, `@spec` per public function, realistic UUIDs, `#{inspect(__MODULE__)}` style.
- [references/commits-and-prs.md](references/commits-and-prs.md) — split by architectural layer, PR self-review checklist.
- [references/anti-patterns.md](references/anti-patterns.md) — recurring Elixir anti-patterns with fixes.

## Pre-PR self-review checklist

Run before pushing. Dialyzer optional (skip if project has no dialyzer config).

```
Personal Elixir PR self-review:
- [ ] Current branch is NOT `main` or `master` — `git rev-parse --abbrev-ref HEAD` confirms a feature branch
- [ ] No local commits, merges, rebases, resets, or pushes touched `main`/`master`
- [ ] Formatter clean: mix format --check-formatted
- [ ] Credo clean: mix credo --strict (if credo configured)
- [ ] Dialyzer clean: mix dialyzer (if dialyzer configured)
- [ ] Compile clean with warnings as errors: mix compile --warnings-as-errors
- [ ] All tests pass: mix test
- [ ] Every public function touched by this PR (new OR modified signature/behavior) has `@spec` + `@doc` with an `## Examples` block — MUST pass before moving to the PR phase
- [ ] Examples are executable doctests whenever the function is pure / deterministic (no DB, no process state, no `DateTime.utc_now/0`, no randomness). `mix test` runs them automatically
- [ ] Non-executable examples (DB-backed, LiveView, side-effectful) still ship as `## Examples` blocks for intent, but are not indented with `iex>` prompts that would be executed
- [ ] Doctests use realistic UUIDs ("a56dcb6a-110b-4efc-a563-178838f4143c"), not "abc123"
- [ ] Tests use `alias Mod, as: Subject` + blank line + other aliases
- [ ] Tests assert full struct equality, not pattern-matched fields
- [ ] All test maps/structs (inputs + expected) come from factories — no inline `%{...}` or `%Mod{...}` literals, no production builders
- [ ] Named setup returns {:ok, kw} tuple
- [ ] Mocks return per-spec values (not generic :ok)
- [ ] ALL maps and structs sorted alphabetically by key (literals, pattern matches, schema/migration/TypedStruct defs)
- [ ] Module attributes/directives ordered (moduledoc → behaviour → use → import → require → alias → attrs → types → functions)
- [ ] No boolean argument switching behaviour — use tagged atoms
- [ ] No nested `if` inside `case` — flatten to `with` + `else`
- [ ] Multi-layer feature: commits split by layer, each compiles standalone
- [ ] Verify split: git diff <pre-split-backup> HEAD must be empty
- [ ] PR title is short (under 70 chars)
- [ ] PR description: summary + test plan
```

## Workflow

1. Open personal Elixir repo.
2. Implement change with `tdd` cadence — failing test first.
3. Apply rules from `references/testing.md` and `references/coding.md`.
4. Refactor per `xp` and `elixir-crafting`. Personal anti-patterns: `references/anti-patterns.md`.
5. Documentation: `references/documentation.md` for every public function.
6. Commits: split by layer per `references/commits-and-prs.md`.
7. Run pre-PR checklist above. Fix every box before push.

## Install

Run `bash install.sh` from the skill directory. Symlinks the skill into `~/.claude/skills/` and offers to install missing companion skills (`xp`, `elixir-crafting`, `tdd`, `refactoring`) from `output_skills/`.
