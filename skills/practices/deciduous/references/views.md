# Deciduous Graph Views

`deciduous serve` (or `/serve-ui`) starts the viewer on
localhost:3000; `-p <port>` changes the port. It refreshes as
the graph changes. The README for 1.0.12 lists five views,
summarized below.

The viewer supports branch filtering, full-text search with
type filters, deep links, and click-to-expand node details,
and the detail panel shows attached documents.

## Chains

Decision chains grouped by session: the story of one feature
from goal to outcome. Best for tracing a single decision from
motivation to result.

## Timeline

Nodes in chronological order, merged with git commits. Nodes
built by `/decision-graph` sit at their backdated commit
times. Best for "what happened last month?" and "what led to
this state?".

## Graph

A force-directed, interactive layout of every node and edge.
Best for seeing clusters and how far one area reaches into
another.

## DAG

The hierarchical goal → decision → outcome flow. Best for the
overall shape of a project's decision history.

## Archaeology

Narrative-driven navigation built from
`.deciduous/narratives.md` and the revisit chains that
`deciduous archaeology pivot` creates, with a Q&A panel for
questions such as "why did we switch from X to Y?". Keyboard
navigation: `j` / `k` for next and previous, `g` / `G` for
first and last, `Space` to expand. Best for how a subsystem
evolved, not just its current state.

With a graph server, the `ask_graph` MCP tool answers the same
kind of question over the whole server graph without the
viewer.

## Choosing a view

- "Trace this decision" → Chains
- "What happened when?" → Timeline
- "How do these areas connect?" → Graph
- "Show me the overall shape" → DAG
- "How did this subsystem evolve, and why?" → Archaeology
