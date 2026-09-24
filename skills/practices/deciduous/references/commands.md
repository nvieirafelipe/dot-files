# Deciduous Command Reference

## /decision-graph

Analyzes git commit history and constructs a decision graph
retroactively.

Capabilities:
- Reads all commits, traces narrative threads
- Identifies what got built, replaced, and where pivots
  happened
- Creates backdated nodes grounded in commit SHAs
- Discovers major narrative threads automatically

Output: connected decision graph with nodes, edges, and
narrative groupings.

Run once per repo to bootstrap. Can be re-run to incorporate
new commits.

## /work

Starts a work transaction.

1. Creates a Goal node with verbatim user input
2. Goal is created *before* implementation begins
3. Subsequent Actions and Outcomes link automatically
4. Commits are associated with Outcome nodes

Pattern: `/work` → code → commit → outcome recorded.

## /decision

Full graph management command:
- Add nodes (any of the 7 types)
- Create edges between nodes
- Attach documents (screenshots, PDFs, diagrams)
- Sync with teammates
- Export to DOT/PNG formats
- Generate PR writeups from decision context

Attached documents get AI-generated descriptions for
searchability.

## /recover

Restores full context at session start:
- Queries active (incomplete) goals
- Lists attached documents
- Shows branch state and recent commits
- Audits for disconnected nodes
- Reports what is in-progress vs completed

Run at the start of every new session or after `/clear`.

## /document

Generates documentation for a file or directory by "shaking
the tree":
- Traces callers
- Locates tests
- Maps dependencies

Output: structured documentation of the target's role in
the codebase.

## /sync

Multi-user synchronization through `deciduous sync`:
- Reconciles `.deciduous/graph.json` with the local database,
  in both directions
- `graph.json` is one git-tracked file; concurrent edits
  conflict in git and the `deciduous merge-record` driver
  merges them record by record
- `deciduous sync --check` exits 1 when anything is pending
- With a `[remote]` graph server, `deciduous remote pull`,
  `push` and `status` replace it

## /serve-ui

Launches web viewer at localhost:3000:
- Auto-refresh on graph changes
- Supports DAG, timeline, chains, archaeology, and Q&A views
- Keyboard navigation (j/k/g/G/Space in archaeology view)

## /build-test

Builds the Deciduous project and runs its test suite.
Utility command for contributing to Deciduous itself.

## deciduous pulse

Maps current code state as decisions:
- Reads code within a scope
- Identifies "what decisions define this?"
- Creates connections from goals through options and decisions
- Displays summary: node counts, types, active goals with
  completion status

## deciduous narratives

Maintains `.deciduous/narratives.md`:
- Living evolution document for subsystems
- Identifies pivots (where approaches switched)
- Documents current vs historical state
- Finds supporting evidence in commits

## deciduous archaeology

Transforms narratives into graph structure:
- `archaeology pivot` creates pivot chains atomically
- Generates Revisit nodes
- Marks old approaches as superseded
  (`deciduous archaeology supersede <id>`)
- Connects the complete timeline
- Enables archaeology view navigation

## deciduous status

Flips a node between lifecycle states.

```bash
deciduous status <id> completed   # shipped / chosen / observed
deciduous status <id> rejected    # option not taken, or work abandoned
deciduous status <id> active      # current truth, still in use
deciduous status <id> pending     # rare: only to reopen
```

These four are the only values 1.0.8 accepts.

Run after every commit to flip the corresponding action +
outcome to `completed`. Run when a decision lands to flip
chosen options to `completed` and unchosen options to
`rejected`. Never leave shipped work `pending`.

## deciduous update

Refreshes the integration files after a binary upgrade.

```bash
deciduous check-update                 # what changed since the files were written
DECIDUOUS_NO_SERVER=1 deciduous update # no graph server
deciduous update --all ~/code          # every project under a directory
```

Files deciduous wrote are replaced; a user's Markdown keeps its
text with the new text appended in a marked block; a user's
script or TOML is left alone. Everything it changes is copied
to `.deciduous/update-backups/<time>/` first. Since 1.0.5 it
stops with exit 1 unless the project has a graph server or
`DECIDUOUS_NO_SERVER=1` is set.

## deciduous audit

Maintains graph data quality.

```bash
deciduous audit --associate-commits --dry-run  # preview
deciduous audit --associate-commits --yes      # apply
deciduous audit --associate-commits --min-score 60
```

Auto-associates git commits with action/outcome nodes by
title similarity. Run after a status sweep so the graph
links back to the SHAs that produced each outcome.

## deciduous pulse maintenance loop

Combine the maintenance commands into a single periodic
routine:

```bash
deciduous pulse                                            # diagnose
deciduous nodes | awk '$3=="pending"&&($2~/action|outcome/)' # list stale
deciduous status <id> completed                            # sweep
deciduous audit --associate-commits --yes                  # backlink
deciduous pulse                                            # verify
```
