# No-slop PR descriptions

Source: <https://noslopgrenade.com/>

PR description is async chat with reviewer, not essay. Goal: reviewer
scans it in 30 seconds, knows what to look at, knows how to verify.

## Core rule

> "If they wanted an AI essay, they would have asked ChatGPT
> themselves. They asked you because they wanted your human judgment."

A wall of AI-generated PR prose is a "slop grenade" — it destroys
dialogue. The reviewer cannot push back, cannot clarify, cannot ask
"why" without first extracting the one sentence buried under the
walls of context. Match the medium: PR body = short, scannable,
human.

## Budgets

Qualitative rules get argued with. Numbers do not.

| Artifact | Budget |
|---|---|
| PR description | 30 lines of content you wrote |
| PR or review comment | 1–3 sentences each |
| Summary bullets | 6 |
| Commit body | Only when the subject does not carry the "why" |

Count the lines before showing the draft and state the count. The
budget covers prose you wrote: HTML comments, the repo template's
fixed boilerplate, and the reviewer-instructions block do not count
against it. Over budget means cut content, not reflow it.

## Banned vocabulary

Never emit these in a PR body, a review comment, or a commit
message:

- Em dash (`—`). Colon, comma, parenthesis, or full stop instead.
- `leverage`, `robust`, `seamless`, `comprehensive`, `delve`,
  `crucial`, `pivotal`, `utilize`, `facilitate`, `in order to`
- Marketing register: `powerful`, `streamlined`, `elegant solution`
- Invented nouns for ordinary things ("persisted email event",
  "the checkout journey")
- Tricolon padding ("fast, reliable, and maintainable") where one
  adjective carries the meaning
- "It is worth noting that", "One might ask whether", "In
  conclusion", "Great question", "Let me break down"

## DO

- **Match the medium.** PR body fits on one screen. Summary in 3–6
  bullets max. Test plan as a checklist.
- **Lead with the change.** First bullet says what the PR does in
  one sentence. Reviewer should not have to read three paragraphs
  to learn the topic.
- **Link, don't lecture.** Linked story / parent PR / design doc
  carries context — do not re-narrate it. If a reviewer needs the
  history, they will click.
- **Name the diff shape.** New module path, behavior change, schema
  field added/removed. Reviewer uses these to know what to grep.
- **Test plan = reviewer's verification checklist.** Each box is a
  thing the reviewer (or CI) checks, not a thing you already ran.
- **Trust the reviewer.** They know the codebase. Skip the
  "what is `Entity.Order`" tour.

## DON'T

- **No "v0 vs v1" history paragraphs.** Belongs in `plan.md` /
  worklog / commit messages, not the PR body.
- **No restating commit messages.** PR body summarizes the diff;
  commits explain the steps. Different audiences.
- **No "🤖 Generated with Claude Code" footers.** Telegraphs slop.
  If the human author had nothing to add, the description is too
  long.
- **No "scope / out of scope / future work" essays.** If something
  is out of scope, say so in one bullet or not at all.
- **No "in conclusion", "great question", "let me break down",
  "as a recommendation"** — strip filler the human would never type.
- **No moduledoc-style architecture lectures.** The code documents
  itself; the PR documents the change.
- **No pre-answering every objection.** Leave reviewer space to ask.
  Their pushback may surface a real concern you missed.

## Template (short form)

```markdown
## Summary

One sentence explaining what changed.

- Bullet: concrete change (new module, behavior shift, schema diff).
- Bullet: concrete change.
- Bullet: concrete change.

Base: `<branch>` (if not the repo default).
Closes: <story/issue link>.

## Test plan

- [ ] CI green
- [ ] <thing reviewer should manually check>
- [ ] <thing reviewer should manually check>
```

When the change is one commit and trivial, the body can be
1–2 sentences plus the test plan. Skip the bullets.

## Self-check before submitting

Read the draft as the reviewer would:

1. Could a one-sentence Slack reply have conveyed the same?
   → Use the one sentence.
2. Is any paragraph restating something already in the linked
   story / parent PR / commit message? → Cut it.
3. Is there a sentence the human author would never type
   ("great question", "let me break down", "in conclusion")?
   → Cut it.
4. Is the test plan a checklist of what reviewer verifies, or a
   diary of what you ran? → Convert to reviewer-facing checks.
5. Is there an AI-attribution footer? → Remove.
6. `wc -l` the body. Over 30? → Cut, do not reflow.
7. `grep` the body for the banned vocabulary above, em dash
   included. Any hit? → Rewrite that sentence.
8. Does every factual claim (behavior, threshold, field, owner)
   carry its receipt, a file:line or a link? → Source it or
   label it `UNVERIFIED:`.

If any answer needs cutting, cut before showing the draft to the
user. Slop is harder to remove after the user approves it.
