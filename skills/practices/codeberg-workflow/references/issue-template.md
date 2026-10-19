# Issue templates

This skill expects every issue it acts on to follow a
canonical **WHY / WHAT / HOW / DEFINITION OF DONE /
REFERENCES** structure. The structure makes the issue body
load-bearing for the Plan phase: each section maps to a
specific input the planner needs.

| Section | Purpose | Used by Plan phase for |
|---------|---------|------------------------|
| Why? | Symptom + cost of not fixing | Goal statement; pivots only allowed if Why is preserved |
| What? | User-observable outcome | Acceptance criteria, demo verification |
| How? | Implementation strategy + decisions | Layered commit plan; deciduous decision nodes |
| Definition of done | Testable bullets | Solution verifier sections (one cell per bullet) |
| Out of scope | Explicit deferrals | Stops scope creep mid-PR |
| References | External docs / related issues | Plan phase context, doctest links |

## Seeding the template in a Codeberg/Gitea repo

Codeberg uses Gitea's issue-template convention. Templates
live at `.gitea/ISSUE_TEMPLATE/<name>.md` (front-matter
header + markdown body). Codeberg's web UI offers them as a
dropdown when opening a new issue.

Minimum starter set: `feature.md` and `bug.md`. Drop both at
`.gitea/ISSUE_TEMPLATE/` in the target repo root and commit.

Reference copies (canonical for this skill) live at
[../templates/feature.md](../templates/feature.md) and
[../templates/bug.md](../templates/bug.md). To install in a
fresh repo:

```bash
SKILL_DIR="$HOME/.claude/skills/codeberg-workflow"
REPO_ROOT="$(git rev-parse --show-toplevel)"
mkdir -p "$REPO_ROOT/.gitea/ISSUE_TEMPLATE"
cp "$SKILL_DIR/templates/"*.md "$REPO_ROOT/.gitea/ISSUE_TEMPLATE/"
git -C "$REPO_ROOT" add .gitea/ISSUE_TEMPLATE
git -C "$REPO_ROOT" commit -m "Add issue templates (feature, bug)"
```

The templates are also valid Forgejo templates (Forgejo
inherits the Gitea convention) and GitHub templates with one
caveat: GitHub expects `.github/ISSUE_TEMPLATE/`. If a repo
mirrors to GitHub, symlink or duplicate.

## Section rules

### Why?

- Lead with the symptom, not the mechanism. "User cannot
  set a due date in another time zone" beats "tasks table
  has no time_zone column".
- Cite concrete failure modes (failing sync, lost data,
  manual workaround required).
- Keep mechanism out — that belongs in How?.

### What?

- Bullets, observable outcomes only.
- "A user can…" / "The system records…" / "The dashboard
  displays…".
- No schemas, no module names, no library names. If a
  bullet mentions a class or table, move it to How?.

### How?

- Sub-headings welcome — Schema, Flow, UI,
  Migration, Backfill, etc.
- Every decision gets a one-line rationale. Open questions
  marked `OPEN:` so they cannot be silently lost.
- Migration order matters — call it out explicitly when the
  feature requires more than one DDL change.
- Reference external libs by name + why (e.g. "Req — already
  the project's HTTP client") rather than restating the lib's
  features.

### Definition of done

- Each bullet is something a reviewer can check. "Tests
  cover X" is fine; "Tests are good" is not.
- Always include a doctest requirement bullet for new public
  functions when the repo enforces doctests
  (`nvieirafelipe-elixir-xp`).
- DoD bullets become the Playbill verifier sections — keep
  them ordered and atomic.

### Out of scope

- Be specific. "Full offline mode" is too broad; "Queue
  edits made while offline" is right.
- Link to follow-up issues when they exist. Otherwise note
  "deferred to follow-up".

### References

- External API docs, RFCs, ISO standards.
- Related issues with their numbers.
- Prior PRs that touched the same area.

## Common gaps to catch during Plan-phase readiness check

When the planner reads an issue body it should flag and
resolve before writing `plan.md`:

1. **Contradictions** between sections — e.g. Why says
   "sync" but How says "async". Reconcile before planning.
2. **DoD bullets without How? coverage** — every observable
   in DoD needs an implementation slot in How?.
3. **Missing migration order** when How? changes more than
   one table.
4. **Open questions in How?** marked `OPEN:` — push back to
   the user for an answer before starting Implement phase.
5. **No Out-of-scope section** — scope creep risk.
6. **References block is empty** when the feature integrates
   a third-party API — find the docs.

If any of those gaps are present, the planner edits the
issue body (via `tea issues edit`) with the user's approval
before producing `plan.md`. The Codeberg issue is the
canonical source of truth — plan.md derives from it, not the
other way around.
