# Syntax Validation Checklist

Run through this checklist before rendering any diagram.
These 20 rules prevent the vast majority of syntax errors.

## Pre-render checklist

1. **Frontmatter position** — if using `---` config, it
   must be the very first line of the diagram
2. **Diagram type declared** — first non-config line must
   be a valid diagram type (`graph`, `sequenceDiagram`,
   `stateDiagram-v2`, etc.)
3. **No bare reserved words as node IDs** — `end`,
   `default`, `style`, `class`, `graph`, `subgraph`,
   `click`, `linkStyle` cannot be node IDs. Wrap in quotes
   or use a prefix: `endNode["End"]`
4. **Special characters quoted** — any label containing
   `:`, `(`, `)`, `/`, `\`, `"`, `<`, `>`, `{`, `}`,
   `#`, `&`, `|` must be in double quotes inside brackets:
   `A["fn(x): result"]`
5. **Parentheses escaped** — `["process(data)"]` not
   `[process(data)]` (unquoted parens create shape syntax)
6. **Semicolons in sequence messages** — use `#59;` HTML
   entity, never raw `;`
7. **Comments use `%%`** — never single `%`. Single `%`
   causes parser errors
8. **Subgraph IDs with display names** — always use
   `subgraph id["Display Name"]` format
9. **No emoji in node text** — renderers handle emoji
   inconsistently. Use text labels
10. **No bare `N. ` in labels** — patterns like `1. ` or
    `2. ` conflict with markdown list parsing. Use
    circled numbers ①②③ or remove the period
11. **Node IDs are descriptive** — `authService`,
    `paymentGateway`, not `A`, `B`, `C`
12. **Edge labels quoted if complex** — `-->|"label text"|`
    for labels with spaces or special chars
13. **Balanced subgraph end statements** — every `subgraph`
    needs a matching `end`
14. **Direction after graph keyword** — `graph LR` not
    `graph` alone (defaults to TD but be explicit)
15. **No `style` in sequence diagrams** — `style` and
    `classDef` are not supported in `sequenceDiagram`
16. **`classDef` includes `color:` property** — every
    `classDef` must set text color for readability
17. **Max node count** — 15 nodes per diagram, 40 with
    subgraphs. Split beyond that
18. **Declaration order matters** — reorder node
    declarations to reduce line crossings. Nodes declared
    first appear higher/leftward
19. **Link text on same line** — `A -->|text| B` must be
    one line, no line breaks mid-edge
20. **Test with target version** — v11 has breaking changes
    (see below)

## Mermaid v11 breaking changes

- **Markdown-by-default** — node text renders as markdown.
  Backticks, asterisks, underscores in labels may format
  unexpectedly. Quote or escape them
- **Arrowless edges broken** — `---` (linkless edges) are
  broken in v11.0 through v11.4. Use `~~~` (invisible
  link) as workaround, or upgrade past v11.4
- **Configuration limits** — some `init` directives are
  restricted. Test theme/config changes

## Quick fix patterns

| Error | Fix |
|-------|-----|
| "Parse error" on a label | Quote it: `["label"]` |
| "Unexpected token" | Check for unquoted special chars |
| Diagram renders empty | Check diagram type spelling |
| Nodes overlap | Reduce node count or add `~~~` spacers |
| Subgraph won't render | Check `end` keyword balance |
| Styling has no effect | Verify `classDef` before `class` usage |
| Sequence arrow wrong | Use `->>` not `->` (single arrow is deprecated) |

## Line-by-line validation process

For complex diagrams, validate line by line:

1. Copy the diagram to a temporary file
2. Add nodes one at a time, testing after each addition
3. Add edges one at a time
4. Add styling last
5. If a line breaks rendering, isolate and fix it before
   continuing
