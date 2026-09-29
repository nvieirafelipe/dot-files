---
name: mermaid-master
description: Generates Mermaid diagrams with automatic type selection, syntax validation, and live preview. Use when creating diagrams, drawing a decision diagram or decision tree for a guideline, runbook or policy (given X, what do I do?), visualizing architecture, documenting flows, generating design docs, converting code to diagrams, or when any task benefits from a visual representation.
---

STARTER_CHARACTER = 🧜📊

## Diagram type selection

Before writing any diagram, determine the best type for the
situation. Match the **intent** to the type:

- Answer one question a reader asks while reading a
  guideline, runbook or policy ("given X, what do I do?")
  → decision diagram, see the section below. Everything
  else in this list shows structure, which answers no
  question.
- Show how components connect → `flowchart` or `graph`
- Show request/response between actors → `sequenceDiagram`
- Show lifecycle or modes → `stateDiagram-v2`
- Show data model relationships → `erDiagram`
- Show class hierarchy → `classDiagram`
- Show project timeline → `gantt`
- Show proportions → `pie`
- Show branching history → `gitGraph`
- Show brainstorming/hierarchy → `mindmap`
- Show chronological events → `timeline`
- Show user experience steps → `journey`
- Show metrics over axes → `xychart-beta`
- Show nested containers → `block-beta`
- Show system context (C4) → `C4Context`
- Show quadrant analysis → `quadrantChart`
- Show requirements traceability → `requirementDiagram`
- Show packet structure → `packet-beta`
- Show system architecture → `architecture-beta`
- Show Kanban board → `kanban`

For full syntax and examples of each type, see
[references/diagram-types.md](references/diagram-types.md).

**Proactive suggestion:** when explaining any system with 3+
components, API flows, auth sequences, class hierarchies,
database schemas, or state machines — suggest a diagram even
if the user didn't ask for one.

**Multi-zoom principle:** complex systems need multiple
diagrams at different abstraction levels. Offer a summary
flow first, then detail subgraphs on request. Decision
diagrams never use subgraphs: one question per diagram.

## Decision diagrams

When the diagram answers a question the reader asks while
reading a guideline, runbook or policy, use the format in
[references/decision-diagrams.md](references/decision-diagrams.md).
It is the default for every decision tree. Where it
conflicts with a general rule in this file, the format
wins. Essentials:

- One diagram, one question; the start node states it.
- Every diamond is a condition the text states, in the
  text's words; every result box is an action the text
  states. Where the text is silent, the diagram is
  silent: no invented fall-through, no default leaf.
- Order the questions as the text orders them.
- `flowchart TB`, a plain tree: no subgraphs, no `~~~`,
  no shared end node.
- No labels ("Q1:", "RESULT", "Start:"), no numbering,
  no MUST or SHOULD inside nodes. `✓` opens a result
  box, `⚠` a no-match box; no other glyphs.
- Node IDs: `start`, `q1`..`qN`, a short noun per result.
- `<br/>` line breaks, three to five short lines per box.
- `style` lines with the light palette (green start,
  indigo result, orange hand-off, red no-match), not
  `classDef`.
- A `click` link only on nodes that carry a
  `See: <Section>` line, at most one each; never the
  section the diagram sits in.
- The preview validates syntax; judge width in the
  destination renderer, not in the CLI.

## Mandatory preview

Every diagram MUST be previewed before being considered done.

**Preview priority** (use the first available method):

1. **MCP live preview** — if `mermaid_preview` tool is
   available (from claude-mermaid MCP server), use it with
   a stable `preview_id` for iterative refinement. The
   browser auto-updates on each call with the same ID.

2. **mmdc CLI** — validate and export:
   ```bash
   # Validate only
   echo '<diagram>' | mmdc -i /dev/stdin -o /dev/null 2>&1

   # Export to PNG/SVG/PDF
   mmdc -i diagram.mmd -o diagram.png -b transparent \
     -t default  # themes: default, dark, neutral, forest
   ```

3. **Kroki API** — no local install needed:
   ```bash
   echo '<diagram>' | base64 | \
     curl -s "https://kroki.io/mermaid/svg/$(cat -)" \
     -o diagram.svg
   ```

4. **ASCII rendering** — if `beautiful-mermaid` npm package
   is installed (it is a library, not a CLI):
   ```bash
   node -e "
     const bm = require('beautiful-mermaid');
     bm.render(\`<diagram>\`).then(r => console.log(r));
   "
   ```

5. **Inline code block** — last resort when no renderer is
   available. Write the diagram in a fenced mermaid block
   and tell the user to paste it into
   `mermaid.live` for preview.

After preview, ask: "Does this capture what you need, or
should I adjust the layout/detail level?"

## Syntax safety

Apply these rules to every diagram before preview. Violations
are the #1 cause of rendering failures.

**Critical rules (prevent 90% of errors):**

- Quote any label with special characters:
  `A["Label: with colon"]` not `A[Label: with colon]`
- Escape parentheses inside labels: `["fn(x)"]`
- Never use reserved words as bare node IDs: `end`,
  `default`, `style`, `class`, `graph`, `subgraph`
- Use descriptive node IDs: `authService` not `A`
- Semicolons in sequence diagram messages need HTML entity:
  `A->>B: check status#59; retry` (use `#59;`)
- Subgraph IDs need quoted display names:
  `subgraph auth["Authentication"]`
- No emoji in node text — use text labels or color coding
  (decision diagrams keep the `✓` and `⚠` text glyphs)
- No bare `number.space` patterns in labels (conflicts
  with list syntax). Use circled numbers: ①②③
- `%%` for comments, never single `%`
- Frontmatter `---` must be the very first line if present
- v11+: arrowless edges (`---`) broken in v11.0-11.4,
  use `~~~` or upgrade past v11.4

For the complete 20-item validation checklist, see
[references/syntax-rules.md](references/syntax-rules.md).

## Styling

Apply semantic styles to make diagrams self-explanatory:

```
classDef primary fill:#4F46E5,stroke:#3730A3,color:#fff
classDef success fill:#059669,stroke:#047857,color:#fff
classDef warning fill:#D97706,stroke:#B45309,color:#fff
classDef danger fill:#DC2626,stroke:#B91C1C,color:#fff
classDef neutral fill:#6B7280,stroke:#4B5563,color:#fff
classDef storage fill:#2563EB,stroke:#1D4ED8,color:#fff
classDef external fill:#7C3AED,stroke:#6D28D9,color:#fff
```

**Every `classDef` MUST include `color:` property** for
text readability. Missing `color:` is a common anti-pattern.
Decision diagrams are the exception: they use `style`
lines with light fills, so the default text colour stays
readable.

## Code-to-diagram

When the user provides source code or asks to diagram a
codebase component:

1. Read the actual source files — never fabricate
   structure from assumptions
2. Identify the architectural pattern (MVC, hex, pipeline,
   event-driven, etc.)
3. Choose diagram type based on what aspect to visualize:
   - Module dependencies → `flowchart`
   - Request lifecycle → `sequenceDiagram`
   - Data model → `erDiagram`
   - State machine → `stateDiagram-v2`
   - Class hierarchy → `classDiagram`

For framework-specific patterns (Spring Boot, FastAPI,
React, Node, Python ETL), see
[references/code-patterns.md](references/code-patterns.md).

## Complexity management

- Max 15 nodes per diagram — split into subgraphs or
  multiple diagrams if exceeded. Decision diagrams split
  into multiple diagrams only, never subgraphs
- Max 3 nesting levels for subgraphs
- Declaration order affects layout — reorder nodes to
  reduce line crossings
- Use `graph LR` for call/data flows, `graph TD` for
  dependency/hierarchy trees

**The isomorphism test:** does the visual structure mirror
the concept's behavior? If a pipeline is linear, the
diagram should be linear. If a system fans out, the diagram
should fan out. Diagrams that don't pass this test mislead
more than they help.

**The education test:** does the diagram teach something,
or just label boxes? Every node should carry evidence
(a function name, a data format, a protocol). Generic
labels like "Process" or "Handler" fail this test.

## Output formats

Adapt the output to context:

- **In a PR or markdown doc** → fenced mermaid code block
- **In a design doc** → PNG/SVG export via mmdc or Kroki
- **In a LiveBook notebook** → `playbill mermaid` cell
- **In terminal** → ASCII via beautiful-mermaid
- **For iteration** → MCP live preview

When exporting images, default to transparent background
and `default` theme unless the user specifies otherwise.

## Workflow

1. **Understand intent** — what question should the diagram
   answer? Ask if unclear.
2. **Select type** — use the selection guide above.
   Explain your choice briefly.
3. **Research** — read actual code/docs. Never fabricate.
4. **Draft** — write the diagram applying syntax rules.
5. **Validate** — run through syntax checklist.
6. **Preview** — render using the best available method.
7. **Iterate** — refine based on feedback. Reuse the same
   `preview_id` for MCP previews.
8. **Export** — save in the format that fits the context.

## Error recovery

If rendering fails:

1. Read the error message — mmdc and Kroki return specific
   line numbers
2. Check against the syntax rules (quoting, reserved words,
   special characters)
3. Simplify — remove styling, reduce nodes, check for
   unsupported features in the target Mermaid version
4. For persistent failures, see
   [references/troubleshooting.md](references/troubleshooting.md)

## References

Load these only when the task requires deeper guidance:

- [references/decision-diagrams.md](references/decision-diagrams.md)
  — the decision diagram format: content rules, shape,
  palette, renderer notes, overrides of this file
- [references/diagram-types.md](references/diagram-types.md)
  — syntax and examples for all diagram types
- [references/syntax-rules.md](references/syntax-rules.md)
  — complete 20-item validation checklist, v11 changes
- [references/code-patterns.md](references/code-patterns.md)
  — framework-specific code-to-diagram patterns
- [references/troubleshooting.md](references/troubleshooting.md)
  — 28 common errors with fixes, error recovery strategies
