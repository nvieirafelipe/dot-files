# Sources and local decisions

Collected on 2026-09-24.

## Author's writing rules

The voice rules, banned vocabulary, output budgets, and claim rule came from the
author's personal agent instructions, adapted so the skill can be shared. Changes:

- Employer-specific examples were replaced with neutral ones ("the checkout journey").
- The chat-reply budget keeps the original wording, "as short as the answer allows".
- Material uncertainty survives shortening; technical-writing governs evidence when
  both skills apply. Supplied facts do not require an invented external citation.
- Rewrite examples preserve action status and avoid adding unsupported facts.
- Personal accounts retain first person; routine PR narration can be rewritten
  without changing attribution. Prose bullets use complete sentences.

The evidence table and verifier pass that went with the claim rule moved to
technical-writing, which owns fact-heavy documents. This skill keeps only the
editor-side guard: do not turn missing evidence into a confident sentence.

## Upstream skill

Based on [pstack's unslop skill][pstack]. Most patterns in
[patterns.md](patterns.md) adapt its rules 3, 5, 7 to 12, 15 to 18, 20, 22 to 33, with
rewritten examples. The [pstack license](https://github.com/backnotprop/pstack/blob/main/LICENSE)
is MIT, copyright 2026 Lauren Tan.

Where this skill differs from upstream:

- Colons and parentheses are allowed as em-dash replacements. Upstream allows only
  periods and commas.
- Upstream's rule numbers are not reused. This skill has its own stable `U` IDs.
- Upstream is explicit-only (`disable-model-invocation`). This skill is discovered
  automatically so it applies to all prose and technical-writing can call it.
- Upstream cuts a sentence if it could appear unchanged in another project's docs. Not
  adopted: shared instructions can be useful.

## Other sources

- [MDN: Creating effective technical documentation][mdn]: the vague link text example
  (U33), consistent terms (U10), and replacing ambiguous pronouns (U27).

## Dependency direction

technical-writing loads this skill. This skill names technical-writing as a typical
caller but never loads it.

[pstack]: https://github.com/backnotprop/pstack/blob/main/skills/unslop/SKILL.md
[mdn]: https://developer.mozilla.org/en-US/blog/technical-writing/
