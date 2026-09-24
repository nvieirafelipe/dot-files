# Sources and adaptation

Consulted on 2026-09-24. These sources inform the skill; their full conventions are not
automatically requirements for every document.

- Author's writing rules: the receipt rule, the `UNVERIFIED:` label, the evidence table
  before the conclusion, and the single verifier pass came from the author's personal
  agent instructions. The current skill allows result-first findings, grouped evidence,
  attributed supplied facts, and direct verification when delegation is unavailable.
  Verification checks source support, not just citation presence. Employer-specific
  examples were replaced with neutral ones. Voice and style rules from the same source went to
  [unslop](../../unslop/SKILL.md).
- [pstack technical-writing, by backnotprop][pstack]: starting point for
  purpose-aware structure, precise terminology, readable sentences, and ambiguity
  checks. The worked example in SKILL.md is adapted from it. This adaptation uses fresh
  wording, allows composite documents, and omits upstream skill dependencies, repository
  conventions, and blanket grammar restrictions.
  [Upstream license](https://github.com/backnotprop/pstack/blob/main/LICENSE): MIT,
  copyright 2026 Lauren Tan.
- [MDN: Creating effective technical documentation, Dipika Bhattacharya][mdn]: audience
  context, logical progression, connected paragraphs, useful examples, accessibility,
  and descriptive link text. Sentence-length advice is treated as a readability signal
  rather than a fixed limit.
- [Google developer style highlights](https://developers.google.com/style/highlights):
  general direction on reader-facing instructions. The page has no before/after
  examples, so none were taken from it. Offered under
  [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) unless otherwise noted.
- [Write the Docs guide](https://www.writethedocs.org/guide/), specifically
  [Documentation principles][principles] and
  [How to write software documentation][beginners]: reader needs, navigability, bounded
  completeness, common examples, and keeping documentation aligned with software. Small
  amounts of repeated context can help readers; independent copies of detailed facts
  create maintenance risk.
- [Stack Overflow: A practical guide to writing technical specs, Edidiong
  Asikpo][specs]: basis for the conditional spec reference, including the check of
  reading a draft as its implementer would. Its outline is reduced to decision-relevant
  questions rather than reproduced as a mandatory template.

[pstack]: https://github.com/backnotprop/pstack/blob/main/skills/technical-writing/SKILL.md
[mdn]: https://developer.mozilla.org/en-US/blog/technical-writing/
[principles]: https://www.writethedocs.org/guide/writing/docs-principles/
[beginners]: https://www.writethedocs.org/guide/writing/beginners-guide-to-docs/
[specs]: https://stackoverflow.blog/2020/04/06/a-practical-guide-to-writing-technical-specs/
