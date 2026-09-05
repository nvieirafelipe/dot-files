# Troubleshooting Guide

## Contents
- Common rendering errors
- Parser errors
- Styling issues
- Layout problems
- Version-specific issues
- Renderer-specific issues
- Recovery strategies

---

## Common rendering errors

### "Parse error on line N"
**Cause:** special characters in label text.
**Fix:** wrap label in `["double quotes inside brackets"]`.

### "Unexpected token 'end'"
**Cause:** `end` used as a node ID.
**Fix:** rename to `endNode["End"]` or `finish["End"]`.

### "Lexical error on line N"
**Cause:** unrecognized character or malformed syntax.
**Fix:** check for unescaped `<`, `>`, `{`, `}` in labels.

### "Duplicate node definition"
**Cause:** defining the same node ID with different labels.
**Fix:** define node label once, reference by ID elsewhere.

### Empty diagram renders
**Cause:** misspelled diagram type or missing content.
**Fix:** verify the type keyword (`graph`, not `Graph`).

### "Maximum text size exceeded"
**Cause:** diagram too large for renderer.
**Fix:** split into multiple smaller diagrams.

---

## Parser errors by diagram type

### Flowchart
- Missing `end` after `subgraph` → add matching `end`
- Edge crosses subgraph boundary → move node outside
- `style` before node declaration → declare node first

### Sequence Diagram
- Semicolon in message → replace with `#59;`
- Missing participant declaration → add `participant`
- `style` keyword used → not supported in sequence diagrams
- Activation without deactivation → add `deactivate`

### State Diagram
- `stateDiagram` without `-v2` → use `stateDiagram-v2`
- Spaces in state names → use underscores or quotes
- Nested state without `state Name { }` wrapper

### ER Diagram
- Missing relationship verb → add `: "relationship"`
- Spaces in entity names → use underscores
- Wrong cardinality symbol → check `||`, `o|`, `}|`, `}o`

### Class Diagram
- Method without return type → add `void` or return type
- Visibility symbol in wrong place → put `+/-/#/~` first

---

## Styling issues

### classDef not applying
- Defined after `class` usage → move `classDef` before
- Missing `color:` property → always include text color
- Typo in class name → class names are case-sensitive

### Theme not loading
- Invalid theme name → use: `default`, `dark`, `neutral`,
  `forest`
- Theme config in wrong position → put in frontmatter:
  ```
  ---
  config:
    theme: dark
  ---
  ```

---

## Layout problems

### Nodes overlapping
- Too many nodes → split diagram or use subgraphs
- Add invisible links `~~~` between nodes for spacing
- Reorder declarations — first-declared nodes get priority

### Unexpected node positions
- Declaration order determines layout priority
- Reverse the graph direction (`LR` ↔ `RL`, `TD` ↔ `BT`)
- Use subgraphs to force grouping

### Lines crossing excessively
- Reorder node declarations to match visual flow
- Split into multiple subgraphs
- Use `~~~` invisible links to guide layout
- Move related nodes adjacent in source order

### Subgraph sizing
- Empty subgraphs collapse → add at least one node
- Subgraphs too wide → reduce content or nest further

---

## Version-specific issues

### v11.0 - v11.4
- Arrowless edges `---` broken → use `~~~` or `-- -->`
- Markdown rendered by default in labels → escape
  backticks and formatting chars
- Some `init` directives restricted

### v10 → v11 migration
- Check for deprecated syntax
- Test all diagrams after upgrade
- Verify theme compatibility

---

## Renderer-specific issues

### mmdc (Mermaid CLI)
- Requires Node.js and puppeteer/playwright
- Timeout on large diagrams → increase with `--timeout`
- Transparent background → `-b transparent`
- Version mismatch → `mmdc --version` to check

### Kroki API
- No local install needed but requires internet
- Large diagrams may hit URL length limits → use POST
- SVG output recommended over PNG for quality
- Rate limiting possible on public instance

### beautiful-mermaid
- ASCII output may not support all diagram types
- Best for flowcharts and simple sequences
- Themes only apply to SVG output

### MCP live preview (claude-mermaid)
- Reuse `preview_id` for same diagram iterations
- New `preview_id` for each distinct diagram
- `style` not supported in sequence diagrams
- Browser must remain open for live reload

---

## Recovery strategies

When a diagram consistently fails to render:

**Strategy 1: Simplify**
1. Remove all styling (`classDef`, `style`, `class`)
2. Remove subgraphs — flatten to a single level
3. Reduce to 5 nodes maximum
4. If this renders, add back elements one at a time

**Strategy 2: Rebuild**
1. Start with the diagram type declaration only
2. Add one node
3. Add one edge
4. Test after each addition
5. The line that breaks it reveals the issue

**Strategy 3: Alternative type**
If a diagram type consistently fails for your content:
- `graph` instead of `flowchart` (more forgiving parser)
- `stateDiagram-v2` instead of `stateDiagram`
- Split `sequenceDiagram` into multiple smaller ones

**Strategy 4: External validation**
Paste the diagram into mermaid.live for interactive
debugging. The live editor shows parsing errors in
real-time with line numbers.
