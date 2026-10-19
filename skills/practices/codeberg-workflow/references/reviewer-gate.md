# Reviewer Gate

Human-in-the-loop checkpoint before push or PR creation. Blocks
on missing or unapproved review artifact. Catches design-level
issues that neither the mechanical gate nor semantic-lint can
detect (naming, abstraction, factory coverage, doctest
completeness, commit layering).

## Artifact: `{SNIPPETS_DIR}/review.md`

Written during the PR phase, before the pre-push gate. Template:

```markdown
# Review: issue-{ISSUE_NUMBER}

## Source

- Branch: {branch-name}
- Diff base: {origin/main or origin/master}
- Reviewer: {nvieirafelipe-elixir-xp self-review | Elixir PR-review agent | human}

## Checklist

- [ ] Every public function has a `@doc` with `## Examples`
- [ ] Every test asserts on full struct / tuple — no per-field
- [ ] Every test fixture / expected comes from a factory
- [ ] Every factory has a name that matches a domain scenario
- [ ] No boolean arguments introduced
- [ ] No nested `case` inside `with`
- [ ] Commits split by architectural layer
- [ ] `nvieirafelipe-elixir-xp` pre-PR checklist run and passed
- [ ] Worklog Session state reflects final phase
- [ ] Playbill Solution Critique has no remaining `TODO`
- [ ] `.snippets/issue-{ISSUE_NUMBER}/plan.md` all steps checked

## Findings

{One entry per finding. Each finding: file:line, pattern,
resolution. If no findings: "None".}

## Status

APPROVED
```

The gate requires the final line under `## Status` to be exactly
`APPROVED`. Any other value (`NEEDS WORK`, `DRAFT`, missing) is
treated as not approved and blocks push.

## How to produce the review

Pick one of three sources in order of increasing rigor:

1. **Self-review** — run the `nvieirafelipe-elixir-xp` pre-PR
   checklist manually against the branch diff. Fastest. Fill
   `review.md`, set `APPROVED`.
2. **Reviewer agent** — spawn an Elixir PR-review agent with
   `git diff $BASE..HEAD` attached. Copy findings into
   `review.md`. Resolve each before approving.
3. **Human reviewer** — open the Codeberg PR in draft state, ask
   a teammate to review, transcribe findings into `review.md`.
   Used when the change is risky or spans unfamiliar code.

## Pre-push hook check

Appended to the existing PreToolUse hook chain in `SKILL.md` that
gates `git push` **to the `codeberg` remote** (plus `tea pulls create`
/ `gh pr create`); pushes to other remotes are not gated:

```bash
REVIEW="$ROOT/.snippets/$ISSUE/review.md"
if [ ! -f "$REVIEW" ]; then
  echo "[codeberg-workflow] review.md missing at $REVIEW. Produce it before pushing." >&2
  exit 2
fi
STATUS=$(awk '/^## Status/{f=1;next} f && NF{print; exit}' "$REVIEW")
if [ "$STATUS" != "APPROVED" ]; then
  echo "[codeberg-workflow] review.md Status is '$STATUS', expected 'APPROVED'. Resolve findings and re-approve." >&2
  exit 2
fi
```

## Regenerating on change

Every new commit after the review was approved invalidates it.
The pre-push hook re-checks `review.md` mtime vs the branch's
last commit and blocks if the review predates HEAD:

```bash
if [ "$(git log -1 --format=%ct HEAD)" -gt "$(stat -f %m "$REVIEW" 2>/dev/null || stat -c %Y "$REVIEW")" ]; then
  echo "[codeberg-workflow] review.md is older than HEAD. Re-review and re-approve." >&2
  exit 2
fi
```

Re-reviewing after a small fix can reuse the previous findings;
rewrite only the resolution lines and bump the file's mtime via
a fresh `Write` of the full content.

## Relation to other gates

- **Mechanical gate** runs first (compile/format/credo/test/
  dialyzer/playbill). Hard fails block review — no point
  reviewing code that doesn't compile.
- **Semantic lint** runs on every commit. By the time a review
  starts, all commits are lint-clean. The reviewer focuses on
  what regex cannot see.
- **Reviewer gate** is the last checkpoint before shared
  infrastructure (push, PR). Findings that repeat across stories
  should be lifted into
  [semantic-lint.md backlog](semantic-lint.md#backlog) so future
  work catches them earlier.
