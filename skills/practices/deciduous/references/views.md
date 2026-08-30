# Deciduous Graph Views

Served via `/serve-ui` at localhost:3000 with auto-refresh.

## DAG View

The raw directed acyclic graph of decisions.

- Shows all nodes and edges
- Color-coded by node type (Goal, Decision, Action, etc.)
- Good for seeing the full decision topology at a glance
- Best for: understanding the overall shape of a project's
  decision history

## Timeline View

Chronological navigation of decisions.

- Nodes arranged by date (backdated for retroactive graphs)
- Filterable by node type
- Best for: "what happened last month?" or "what decisions
  led to this state?"

## Chains View

Decision threads and dependencies.

- Follows edges from Goal → Options → Decision → Action →
  Outcome
- Shows complete decision threads
- Best for: tracing a single decision from motivation to
  result

## Archaeology View

Card-stack navigation of narratives.

- Built from `narratives` skill output
- Navigable with keyboard shortcuts:
  - `j` / `k` — next / previous card
  - `g` / `G` — first / last card
  - `Space` — expand card details
- Shows how subsystems evolved over time
- Highlights pivots (Revisit nodes) prominently
- Best for: understanding the *evolution* of a subsystem,
  not just its current state

## Q&A Interface

Natural language queries over the decision graph.

- Uses FTS5 full-text search across all stored interactions
- Answers grounded in actual graph data with evidence
- Best for: "why did we switch from X to Y?", "what
  alternatives did we consider for Z?"

## Choosing the right view

- "Show me everything" → DAG
- "What happened when?" → Timeline
- "Trace this decision" → Chains
- "How did this subsystem evolve?" → Archaeology
- "Why did we do X?" → Q&A
