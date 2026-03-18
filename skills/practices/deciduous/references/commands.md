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

Multi-user synchronization:
- Event-based, append-only architecture
- Changes are git-mergeable
- No conflict resolution needed for concurrent edits

## /serve-ui

Launches web viewer at localhost:3000:
- Auto-refresh on graph changes
- Supports DAG, timeline, chains, archaeology, and Q&A views
- Keyboard navigation (j/k/g/G/Space in archaeology view)

## /sync-graph

Exports graph data to JSON for GitHub Pages deployment.
Enables sharing the decision graph as a static site.

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
- Connects the complete timeline
- Enables archaeology view navigation
