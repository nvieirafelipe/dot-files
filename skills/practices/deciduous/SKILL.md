---
name: deciduous
description: Records architectural decisions as a queryable graph with Deciduous. Use when logging decision rationale, recovering session context, tracking approach pivots, bootstrapping decision history from git, or when the user mentions deciduous, decision graph, or decision tracking.
---

STARTER_CHARACTER = 🌳

## What Deciduous is

A living decision graph for codebases. It captures *why* code
looks the way it does — not just *what* changed. The graph
connects Goals → Options → Decisions → Actions → Outcomes →
Observations → Revisits into a queryable DAG backed by SQLite.

## Prerequisites

Check if `deciduous` is available:

```bash
which deciduous 2>/dev/null
```

If not found, install it:

```bash
brew install deciduous
```

If not available, tell the user to install from
https://deciduous.dev/ and do not proceed.

Once available, initialize in the project if not already:

```bash
[ -d .deciduous ] || deciduous init
```

## Node vocabulary

- **Goal** — what needs accomplishing
- **Option** — an approach considered
- **Decision** — the choice made and its rationale
- **Action** — implementation work performed
- **Outcome** — observable result
- **Observation** — insight that attaches anywhere in the graph
- **Revisit** — pivot point where a prior approach was superseded

## Commands

### `/decision-graph` — bootstrap from git history

Analyzes commit history and builds a retroactive decision
graph. Nodes are backdated to commit timestamps and grounded
in real SHAs.

Use **once per repo** to bootstrap, or when onboarding to an
unfamiliar codebase.

### `/work` — start a work transaction

Creates a Goal node before implementation begins. Subsequent
Actions and Outcomes are linked automatically through to
commit.

Use **every time you start a unit of work**. This is the
"begin transaction" for decision tracking.

### `/decision` — log a choice

Records Options considered, the Decision made, and the
rationale. Also manages edges, attachments, and exports.

Use **at architectural inflection points** — choosing between
approaches, making trade-offs, picking libraries or patterns.

### `/recover` — restore session context

Rebuilds active goals, attached documents, branch state, and
recent commits. Audits for disconnected nodes.

Use **at the start of every new session**, especially after
context compaction.

### `/document` — generate docs from the graph

Traces callers, tests, and dependencies for a file or
directory and generates documentation.

Use **before refactoring or onboarding** to understand what
you are about to touch.

### `/sync` — team synchronization

Append-only, git-mergeable event sync across team members.

Use **on team projects** when multiple people need shared
decision context.

### `/serve-ui` — local graph viewer

Launches localhost:3000 with DAG, timeline, chains,
archaeology, and Q&A views. Auto-refreshes.

Use **when you need to visually navigate** the decision
history or present it to others.

### `/sync-graph` — export for GitHub Pages

Exports graph data to JSON for static deployment.

Use **for sharing the graph externally** — stakeholders, new
hires, async reviews.

## Skills (contextual guides)

### `pulse`

Reads code within a scope and maps it to decisions. Shows
active goals and completion status.

Use for **quick health checks** — "where are we on this
subsystem?"

### `narratives`

Maintains `.deciduous/narratives.md` — a living doc of how
subsystems evolved, with pivot tracking.

Runs **continuously** as the system evolves. It is the prose
companion to the graph.

### `archaeology`

Turns narratives into graph structure. Creates Revisit nodes
and marks old approaches as superseded.

Use **when approaches change** — the pivot happened, now
record it properly.

## Integration with plan files

When generating plan files (e.g. `plan.md` for story
workflows or any structured implementation plan), bridge
decisions to the Deciduous graph:

1. After finalizing the `## Decisions` table in the plan,
   run `/decision` for each row to create Decision nodes
   linked to the current Goal
2. Include the Options you considered — not just the choice
   made — so the graph captures the full decision space
3. When deviating from a plan during implementation, create
   a Revisit node linking the original Decision to the new
   approach

This keeps the plan as the readable artifact and the graph
as the queryable, cross-project knowledge base.

## Typical workflows

**New repo, no history:**
`/work` → implement → `/decision` at inflection points →
commit → repeat

**Existing repo, onboarding:**
`/decision-graph` → `/serve-ui` → explore the timeline →
`pulse` on the subsystem you will touch

**Resuming work (new session):**
`/recover` → review active goals → continue

**Pivot happened:**
`archaeology` → creates Revisit chain → `narratives`
updates the evolution doc

## Versioning strategy

The SQLite database (`.deciduous/deciduous.db`) should NOT be
versioned — it's a binary file that git can't diff or merge.
Instead, version the JSON export:

1. Run `deciduous sync` before committing to export the graph
2. Commit `docs/graph-data.json` and `docs/git-history.json`
3. The `.deciduous/config.toml` and `.version` are versioned
4. The database is local — rebuilt from events or fresh

This keeps the decision history human-readable, git-diffable,
and merge-friendly. The JSON export is what powers the web
viewer and GitHub Pages deployment.

## Responding to hooks

Deciduous installs two Claude Code hooks. Follow these rules
when they fire:

### Post-commit reminder (after `git commit`)

The hook outputs the commit hash, message, pending action/outcome
count, and (when applicable) sweep + checkpoint hints. You MUST:

1. Derive a suggested outcome description from the commit message
2. Find the most recent action node to link to:
   ```bash
   deciduous nodes | grep '\[action\]' | tail -1
   ```
3. Present the user with pre-filled commands and ask for
   confirmation before running them:
   ```
   Deciduous: link this commit to the decision graph?

   deciduous add outcome "<derived description>" -c 95 --commit HEAD
   deciduous link <outcome_id> <action_id> -r "<derived reason>"
   deciduous status <action_id> completed
   deciduous status <outcome_id> completed

   Want me to run these, or adjust anything?
   ```
4. Only run the commands after the user confirms or adjusts.
5. Do NOT silently skip this step or treat it as optional.
6. If the hook surfaces a **sweep hint** (pending count > 10), offer
   a status sweep alongside the commit link. Group the pending IDs
   by shipped vs. not-shipped, then propose:
   ```bash
   deciduous status <id> completed   # for shipped action/outcome
   deciduous status <id> rejected    # for options not chosen
   deciduous status <id> cancelled   # for abandoned work
   ```
7. If the hook surfaces a **checkpoint hint** (event log > 256KB),
   propose `deciduous events checkpoint --clear-events` after the
   commit link is in.

### Pre-edit guard (before `Edit`/`Write`)

The hook blocks edits when no recent action/goal node exists.
When blocked:

1. Derive a suggested action description from the task context
2. Find the most recent goal node to link to:
   ```bash
   deciduous nodes | grep '\[goal\]' | tail -1
   ```
3. Present the user with pre-filled commands and ask:
   ```
   Deciduous: no recent action node. Create one before editing?

   deciduous add action "<derived description>" -c 85
   deciduous link <goal_id> <action_id> -r "<derived reason>"

   Want me to run these, or adjust anything?
   ```
4. Only run after user confirms. Then retry the edit.

## Graph health maintenance — MANDATORY

Status drift is the #1 health problem: commits land but nodes
stay `pending`, pulse fills with stale entries, and rationale
becomes hard to query. Apply these rules every session.

### After every commit that implements an action

```bash
# 1. New outcome node, linked to the commit
deciduous add outcome "Brief result description" -c 90 --commit HEAD

# 2. Link outcome -> action that produced it
deciduous link <outcome_id> <action_id> -r "Result of <action>"

# 3. Flip both nodes to completed once verified
deciduous status <action_id> completed
deciduous status <outcome_id> completed
```

### When a decision lands

```bash
deciduous status <chosen_option_id>  completed
deciduous status <rejected_option_id> rejected   # NOT pending
deciduous status <decision_id>       completed
```

`rejected` is the correct terminal state for unchosen options —
keeps the alternatives signal while clearing the pending bucket.

### Periodic sweeps (weekly, or when pulse looks noisy)

```bash
# 1. List pending action/outcome nodes
deciduous nodes | awk '$3=="pending" && ($2=="action"||$2=="outcome")'

# 2. Flip shipped -> completed, unshipped -> rejected/cancelled
deciduous status <id> completed
deciduous status <id> rejected

# 3. Checkpoint events when log >256KB
deciduous events checkpoint --clear-events

# 4. Auto-associate commits to recent action/outcome nodes
deciduous audit --associate-commits --dry-run
deciduous audit --associate-commits --yes

# 5. Re-run pulse to confirm
make deciduous-pulse   # or: deciduous pulse
```

### Health targets

| Metric | Target |
|--------|--------|
| Coverage gaps | 0 (every action has ≥1 outcome) |
| Pending action/outcome | <10 (hook nags above this) |
| Event log per author | <256KB (hook nags above this) |
| Options ÷ decisions | ≥1.5 (alternatives logged) |
| Confidence unset | 0 (always pass `-c <0-100>`) |

## Anti-patterns

- Logging every small implementation detail as a Decision
  node. Reserve Decision nodes for choices with alternatives.
- Skipping Options. The graph is most valuable when it shows
  what you *didn't* pick and why.
- Forgetting `/recover` on session start. Context compaction
  silently drops decision rationale — the graph is your
  insurance.
- Leaving action/outcome nodes `pending` after the commit
  lands. Flip status at the same time as the commit-link.
- Leaving unchosen options `pending`. Use `rejected` so the
  pending bucket only contains genuinely open work.
- Letting the event log grow past 256KB without checkpointing.
  Rebuild gets slow and merges get noisy.

## References

- [commands.md](references/commands.md) — detailed command
  reference with flags and examples
- [views.md](references/views.md) — description of each
  graph view and when to use it
