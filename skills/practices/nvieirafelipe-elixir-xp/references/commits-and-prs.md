# Commits and PRs — Personal Elixir

Reduce review time (for self + collaborators) by structuring commits and self-reviewing before pushing.

## Contents
- Protected branches (`main` / `master`)
- Split commits by architectural layer
- Verify a post-hoc split preserves the tree
- Pre-push self-review checklist
- PR description structure

## Protected branches — `main` / `master`

`main` and `master` are untouchable from this tool. Every change lives on a feature branch.

Before ANY git write operation, verify the current branch:

```bash
git rev-parse --abbrev-ref HEAD
```

If the output is `main` or `master`, stop. Create a feature branch first:

```bash
git checkout -b <feature-name>
```

Blocked operations on `main`/`master`:
- commit, amend, cherry-pick, stash pop, apply patch
- merge (including fast-forward), rebase, reset, restore
- push (with or without `--force`)
- `git checkout main -- <file>` to pull files (use the remote via PR instead)

Integration happens via a remote PR merged by the user. Not local, not temporary, not "just to test". If a workflow seems to require writing to `main`/`master`, surface the question to the user and let them decide.

## Split commits by architectural layer

When a feature spans persistence / domain / orchestration layers, land each layer as its own commit in dependency order.

Reviewer benefits:
- Each commit reads as one concern.
- Each commit compiles cleanly against the previous one — diff bisection works.
- Layer ownership is visible.

Order: bottom-up. Persistence first, then entity contracts, then orchestration. Tests for each layer ship in the same commit as the layer code.

## Verify the split

When splitting an existing branch into per-layer commits, post-split tree must equal pre-split tree.

```bash
git branch backup
# rebase / split commits as needed
git diff backup HEAD   # must produce no output
```

Empty diff = split preserved the change set. Non-empty diff = something drifted; reset to backup and try again.

## Pre-push self-review checklist

```
Personal Elixir PR self-review:
- [ ] Current branch is NOT `main` or `master` — `git rev-parse --abbrev-ref HEAD` confirms a feature branch
- [ ] No local commits, merges, rebases, resets, or pushes touched `main`/`master`
- [ ] Formatter clean: mix format --check-formatted
- [ ] Credo clean: mix credo --strict (if credo configured)
- [ ] Dialyzer clean: mix dialyzer (if dialyzer configured)
- [ ] Compile clean with warnings as errors: mix compile --warnings-as-errors
- [ ] All tests pass: mix test
- [ ] New public functions have @spec + @doc with ## Examples block
- [ ] Doctests use realistic UUIDs ("a56dcb6a-110b-4efc-a563-178838f4143c"), not "abc123"
- [ ] Tests use `alias Mod, as: Subject` + blank line + other aliases
- [ ] Tests assert full struct equality, not pattern-matched fields
- [ ] All test maps/structs come from factories — no inline `%{...}` or `%Mod{...}` literals
- [ ] Named setup returns {:ok, kw} tuple
- [ ] Mocks return per-spec values (not generic :ok)
- [ ] ALL maps and structs sorted alphabetically by key
- [ ] Module attributes/directives ordered
- [ ] No boolean argument switching behaviour — use tagged atoms
- [ ] No nested `if` inside `case` — flatten to `with` + `else`
- [ ] Multi-layer feature: commits split by layer, each compiles standalone
- [ ] Verify split: git diff <pre-split-backup> HEAD must be empty
- [ ] PR title is short (under 70 chars)
- [ ] PR description: summary + test plan
```

## PR description structure

Title: imperative, under 70 chars. Body details, not title.

```markdown
## Summary
- Bullet 1: what changed and why
- Bullet 2: notable design choice
- Bullet 3: anything reviewers should know

## Test plan
- [ ] Test 1
- [ ] Test 2

## Out of scope
- Anything considered and consciously deferred
```
