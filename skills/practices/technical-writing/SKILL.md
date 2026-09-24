---
name: technical-writing
description:
  Writes, revises, and reviews technical documents for a defined audience, with every
  material factual claim traceable to evidence. Use when writing or reviewing a README,
  runbook, ADR, RFC, design doc, technical spec, investigation report, incident
  write-up, tutorial, how-to guide, API reference, docstring, or an engineering
  explanation of how a system behaves.
---

STARTER_CHARACTER = ✍️

# Technical writing

Help the reader complete a task or understand a technical subject. Match the detail to
the request.

Load [unslop](../unslop/SKILL.md) before drafting, revising, or reviewing. It owns
voice, vocabulary, sentence style, and length budgets. This skill owns document
structure and factual accuracy.

## Pick the mode

| Request | Do | Output |
|---|---|---|
| Write | Establish the task, pick a structure, draft, then run "Review before delivery" | The document |
| Revise | Edit the file in place. Keep technical claims and qualifications unless evidence supports a correction | The revised document, no editing report |
| Review | Check the document against the checklist below without editing it | Findings in the format under "Report review findings" |

## Establish the writing task

Identify the audience, what they already know, and what they need from the document.
Use the request and existing material. Ask only when a missing answer would change the
content. Follow the requested language, format, and project conventions.

Keep three things apart in the text: verified behavior, proposals, and unknowns.
Describe existing behavior only from supplied material or inspected code.

## Organize around the reader's purpose

Choose a structure that answers the reader's questions in order:

- **Tutorial:** state what the learner will build, the prerequisites, and what they
  should see after each step.
- **Task guide:** show how to reach one outcome, the conditions that change the steps,
  and how to recognize success.
- **Reference:** make inputs, outputs, defaults, limits, and failure behavior easy to
  find within the stated scope.
- **Explanation:** connect the concept to its context, causes, consequences, and
  trade-offs.
- **Technical spec or RFC:** read [technical-specs.md](references/technical-specs.md).

One README can combine these. Split files when that helps readers find what they need,
and link between them with enough context to understand each page alone.

Open with the result, problem, or capability the reader came for. Put prerequisite
concepts before the material that depends on them. Write headings that let a reader
find an answer without reading the whole document.

## Write the details

- One point per paragraph. Each sentence follows from the one before.
- Explain a term the first time an unfamiliar reader meets it. Then use that same term.
- Put symbols, commands, and paths in code formatting, exactly as they appear in the
  code.
- Put prerequisites and warnings before the step they affect.
- Say whether the reader performs an action or the system performs it automatically.
- Keep causes, conditions, and consequences explicit.
- Use numbered lists for sequences and bullets for everything else. Keep list items
  parallel.
- Write link text that names the destination.
- Give meaningful images and diagrams a text alternative.
- For each example, state the inputs and the expected result, mark values the reader
  must replace, and name the environment or version it needs. Label output as expected
  or as actually observed.

Worked example (adapted from pstack):

> Before: Configuration of the proto import budget script parameters is performed via
> budget.json. Note that running with --write, which updates the committed budget to
> reflect the current count, should only be done when lowering it. If exceeded, CI
> fails.
>
> After: `budget.mjs` reads the committed budget from `budget.json` and counts the files
> that import protos. If the count exceeds the budget, CI fails. Run
> `budget.mjs --write` only to lower the budget.

## Back every claim with a receipt

Do not state behavior, thresholds, field availability, rule names, schema shape,
ownership, or deployment status as fact without checking the source first. Asserted
limits and rule names that turn out wrong each cost a correction round.

Make material factual claims traceable to evidence that supports them. A citation's
presence is not proof: check whether its contents establish the specific claim.
Use inline citations or a clearly mapped source for a paragraph or related claims.
Match the presentation to the artifact; short explanations and docstrings do not need
an evidence table or a citation on every sentence. Ordinary definitions do not need
receipts unless disputed or dependent on a specific implementation.

Useful evidence includes:

- Code: `path/to/file.ex:120` or a permalink to the exact lines.
- Database or warehouse: the query actually run, plus the row count returned.
- Logs or metrics: the query actually run, plus a link.
- Docs or tickets: the URL.
- Supplied facts or excerpts: attribute them to the user's supplied material when
  provenance matters. A URL is not required. Do not present them as independently
  verified or claim to have run a supplied query.

If a material claim lacks support, label it `UNVERIFIED:` and preserve the uncertainty.
Do not silently delete an unresolved operational claim while editing. Unsupported
promotional claims with no factual content may be removed. Claim that a command or
example ran only if it actually ran. These rules take precedence over unslop's budgets.

In an investigation report, incident write-up, or other finding, lead with the supported
result and place the evidence immediately after it. Use a table when several claims
and sources need comparison; a short paragraph may suffice. Distinguish observations
from inferences, and do not draw a stronger conclusion than the evidence supports.

| Claim | Source | Result |
|---|---|---|
| Sessions expire after 24h | `lib/app/session.ex:44` | `@ttl_seconds 86_400` |
| 3 accounts affected | `SELECT … WHERE …` | 3 rows |

## Review before delivery

1. Check that the document answers the reader's question, and that each step gives the
   information needed to perform it. State when coverage is partial.
2. Compare a revision with its source for changed conditions, guarantees, exceptions,
   or uncertainty.
3. For a runbook, investigation report, incident write-up, or any draft with many
   factual claims, use one verifier subagent when delegation is available and permitted.
   Otherwise perform the same check directly. Check that each material claim's source
   supports it, supplied evidence is attributed accurately, and unresolved claims are
   marked `UNVERIFIED:`. A source location alone does not establish the claim.
4. Run unslop's "Check the result".

Finish when the requested material is covered and the remaining unknowns are explicit.

## Report review findings

Check the document against these items. The IDs are stable so findings can cite them.

- **T1 Purpose:** the opening states the result, problem, or capability the reader came
  for.
- **T2 Order:** prerequisites come before the material that needs them.
- **T3 Steps:** each step can be performed with the information given, and success is
  recognizable.
- **T4 Receipts:** material claims have supporting evidence or an `UNVERIFIED:` label;
  supplied facts are not presented as independently verified.
- **T5 Conclusions:** findings follow from their evidence, with observations and
  inferences distinguished and supporting evidence easy to locate.
- **T6 Status:** verified behavior, proposals, and unknowns are distinguishable.
- **T7 Identifiers:** symbols, paths, and commands match the code.
- **T8 Examples:** each example states inputs, expected result, and requirements.

List findings most important first, one line each:

```
<location> · <ID> <name> · <problem> · Fix: <fix>
```

For example:

```
runbook.md:22 · T4 receipts · "retries stop after 5 attempts" has no source · Fix: cite the config line or mark UNVERIFIED:
README.md:8 · T2 order · the install step uses `make seed` before explaining it · Fix: move the seed section above
```

Report sentence-level problems with unslop's `U` IDs in the same list.

Read [sources.md](references/sources.md) when maintaining this skill.
