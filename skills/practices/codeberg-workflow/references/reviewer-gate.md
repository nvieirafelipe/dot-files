# Reviewer Gate

Human-in-the-loop checkpoint before push or PR creation. Blocks
on a missing, unapproved, or stale review. Catches design-level
issues that neither the mechanical gate nor semantic-lint can
detect (naming, abstraction, factory coverage, doctest
completeness, commit layering).

## Artifact: `{SNIPPETS_DIR}/guided-review/review.md`

The report the `guided-pr-review` skill writes in the guided
review step of [pr-phase.md](pr-phase.md#guided-review). The
workflow adds one section to it: `## Status`, last in the
report, whose first non-empty line is the gate's answer.

```markdown
## Status

APPROVED
```

The gate passes only when that line is exactly `APPROVED`. Any
other value, such as `NEEDS WORK`, or a report without the
section, blocks push. When the report holds more than one
`## Status` heading, the hook reads the last one.

## Setting the status

Write `## Status` after the final commit, from the report's
verdict:

- **Ready for a PR:** `APPROVED`.
- **Fix first:** `APPROVED` only when every Critical and
  Required finding is fixed, with the commit in the report's
  review log, or deferred by the user, with their reason in the
  review log. Otherwise `NEEDS WORK`.
- **Split first:** `NEEDS WORK` until the user decides on the
  split the report proposes in its Merge plan.

Before writing `APPROVED`, also confirm the process items the
review does not cover:

- [ ] `nvieirafelipe-elixir-xp` pre-PR checklist run and passed
- [ ] Worklog Session state reflects final phase
- [ ] Playbill Solution Critique has no remaining `TODO`
- [ ] `.snippets/issue-{ISSUE_NUMBER}/plan.md` all steps checked

## Standards checklist

Hand this list to the guided review's Standards reader. Each
item ends up as a finding or under "Checked, no issue found"
in the report.

- Every public function has a `@doc` with `## Examples`
- Every test asserts on the full struct or tuple, never field by
  field
- Every test fixture and expected value comes from a factory
- Every factory has a name that matches a domain scenario
- No boolean arguments introduced
- No nested `case` inside `with`
- Commits split by architectural layer

## Pre-push hook check

Appended to the existing PreToolUse hook chain in `SKILL.md` that
gates `git push` **to the `codeberg` remote** (plus `tea pulls create`
/ `gh pr create`); pushes to other remotes are not gated:

```bash
REVIEW="$ROOT/.snippets/$ISSUE/guided-review/review.md"
if [ ! -f "$REVIEW" ]; then
  echo "[codeberg-workflow] guided review missing at $REVIEW. Run the guided review before pushing." >&2
  exit 2
fi
STATUS=$(awk '/^## Status$/{f=1; s=""; next} f && NF && s=="" {s=$0} END{print s}' "$REVIEW")
if [ "$STATUS" != "APPROVED" ]; then
  echo "[codeberg-workflow] guided review Status is '$STATUS', expected 'APPROVED'. Resolve findings and re-approve." >&2
  exit 2
fi
```

## Regenerating on change

Every new commit after the review invalidates it. The pre-push
hook compares the report's mtime with the branch's last commit
and blocks if the report predates HEAD:

```bash
if [ "$(git log -1 --format=%ct HEAD)" -gt "$(stat -f %m "$REVIEW" 2>/dev/null || stat -c %Y "$REVIEW")" ]; then
  echo "[codeberg-workflow] guided review is older than HEAD. Re-review and re-approve." >&2
  exit 2
fi
```

After a new commit, run the guided review's snapshot again,
update the report's heads table and review log, and write
`## Status` again. Saving the report moves its mtime past HEAD.

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
