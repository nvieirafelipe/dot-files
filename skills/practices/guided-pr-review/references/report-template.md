# Report template

The report is one Markdown file, `review.md`, rendered to `review.html` by
`scripts/render-report.sh`. It is a briefing the reviewer reads before the code: the
context, how the change came about, the decisions and assumptions behind it with a
challenge to each, and a guide to the code. Then the code in chapters, then what to post.
It speeds up the reviewer's own reading of the code; it does not replace it.

Use `##` for sections and chapters, `###` for groups inside them, and `####` for each
decision, finding, comment draft, and fix. The viewer builds its table of contents from
all three levels, and anchors follow GitHub's heading slugs, so a link works in both.

Link to a heading by its whole slug: lowercase, punctuation dropped, each space a hyphen,
and `-1`, `-2` added to repeats. `#### C2` is `#c2`, but
``#### F2 · Required · Behavior · `lib/foo.ex:40-52` `` is
`#f2--required--behavior--libfooex40-52`, not `#f2`. Assumptions are table rows with no
anchor of their own; link them as `[A2](#assumptions)`.

The viewer renders only these raw HTML tags: `details`, `summary`, `br`, `kbd`, `sub`,
and `sup`, plus HTML comments. Any other raw HTML in a block shows as literal text, so a
quoted PR body cannot break the page. Write tables and links in Markdown, and put quoted
PR text in a code span, a fenced block, or a `>` quote.

Omit a section that has nothing to say, except "Checked, no issue found": an empty one
there means the chapter was not reviewed. A change with no real decision omits
"Decisions and tradeoffs"; a trail with nothing on record still keeps "How we got here"
with its "Not found" rows.

## Sections

1. **Title and status line:** what the change does, "Local review. Not posted.", the
   current head, the mode, and "Provenance at the end".
2. **Brief:** at most 25 lines of text. What and why, how the change came about, the
   verdict, and up to three items to look at first, which are the only items the Brief
   points to.
3. **How we got here:** the discussion trail, one row per thing said or decided, each
   marked with its provenance.
4. **Decisions and tradeoffs:** one block per decision that shaped the change, with the
   alternatives, their gains and costs, and a challenge.
5. **Assumptions:** what the change takes for granted, stated or inferred, each with what
   breaks if it is false and how it was checked.
6. **Reading guide:** why, what is new, what does not change yet, one diagram, then the
   order to read the code in, what to expect at each stop, and where the code departs
   from the trail or the spec.
7. **Spec:** the acceptance criteria table, then missing, scope creep, and looks-wrong
   findings. When every row is Met and nothing follows, the table goes in `<details>`.
8. **Merge plan:** for stacks and multi-repository changes, or, in local mode, a
   proposal to split the branch into PRs.
9. **Chapters:** one per PR, or per layer inside a large PR, in dependency order.
10. **Tests and verification:** what the tests cover, mutation probes and their results,
    and the author's verification claims against the evidence.
11. **Beyond this PR:** proposals that go past the PR's scope, in the options format,
    and pre-existing issues.
12. **Comment drafts:** an index, then one block per draft. In local mode, the fix list
    takes its place.
13. **Provenance:** the reviewed heads, CI, local runs, readers, standards applied,
    sources read and sources out of reach, and the detail of the review threads.
14. **Review log:** every hypothesis and challenge, the check, and the outcome, including
    the dropped ones, then the earlier rounds.

## Provenance labels

Every row of the trail, every decision's rationale, and every assumption carries one
label:

- **Stated:** someone wrote it down. Give a short quote and a link or path.
- **Inferred:** the report concludes it from code, commits, or behavior. Give the
  receipt, and never attribute an inference to the author.
- **Not found:** the record holds no answer. When the answer matters, it becomes a
  Question finding with a draft. Do not fill the gap with a plausible reason.

## Skeleton

````markdown
# <Issue key or PR>: <what the change does>

Local review. Not posted. Head `<sha>`, mode full | quick (Not verified). Provenance at
the end.

## Brief

**What and why.** <Two sentences: what changes, and the problem it answers.>

**How we got here.** <One or two sentences: what was proposed, what was chosen, and what
was left open. Say "No recorded discussion" when the trail is empty.>

**Verdict.** <Per PR or branch, one line each: "#77: approve with suggestions".>

**Look at first.**

1. <Up to three items in all, each a link to a decision, an assumption, or a finding,
   with its axis and one line on why it needs the reviewer's judgment. Take the worst
   item of each axis before a second item from any one axis.>

<One line for each axis with nothing worth the reviewer's time, such as "Design and
standards: nothing above a Nit.">

<The rest of the Brief links to none of the other sections' items.>

## How we got here

Re-fetched <YYYY-MM-DD HH:MM>.

| When | Where | Said or decided | Provenance |
|---|---|---|---|
| <date> | <issue, PR thread, design doc, commit, chat> | <the point, in a few words> | Stated: [link](<url>) |
| <date> | <commit `abc1234`> | <decision visible only in the code> | Inferred: `path:line` |
| | | <a question the record should answer> | Not found: [F4](#<slug of the F4 heading>) |

## Decisions and tradeoffs

#### D1 · <the choice, in a few words>

| | Chosen: <option> | Alternative: <option> |
|---|---|---|
| Gains | <what it buys> | <what it would buy> |
| Costs | <what it costs> | <what it would cost> |
| Source | Stated: [link](<url>) | Stated: <where it was proposed> |

<Optional, when the decision has several parts:>

| Part | Why it is needed | What breaks without it |
|---|---|---|
| <part, with `path:line`> | <reason, with its provenance> | <the failure it prevents> |

**Challenge.** <The strongest case against the choice, with evidence, and the concrete
failure it predicts. What would change the decision. Outcome: Holds, Questionable (a
Consider or Question finding), or Broken (a finding), with its link.>

## Assumptions

| ID | Assumption | Kind | Evidence | If false | Check | Status |
|---|---|---|---|---|---|---|
| A1 | <what the change takes for granted> | Stated: <source> | <what supports it> | <what breaks> | <what was checked, or the cheapest check> | Holds |
| A2 | <...> | Inferred: `path:line` | <none found> | <what breaks> | <cheapest check> | Open: [F4](#<slug of the F4 heading>) |

## Reading guide

**Why.** <The current behavior, and what the issue or RFC changes, in one sentence.>

**What is new.**

1. <New endpoint, call, or behavior.>

**Not changed yet.** <What still works the old way; for example, "no flow calls the new
functions".>

**How the PRs relate.** <One sentence, then the PR graph from diagrams.md.>

<One diagram of the changed components or the new flow.>

Read in this order:

1. `<path:lines>`, <what it is>. Expect <what the trail and spec lead the reader to
   expect>. **Differs:** <where the code departs from the trail or the spec, with
   `path:line`>, or nothing.
2. `<test path>`, <n> tests. Expect <the behaviors>. **Missing:** <a case the trail
   names that no test covers>, or nothing.

## Spec

| Criterion | Status | Evidence |
|---|---|---|
| <criterion, quoted or paraphrased from the spec> | Met | `lib/foo.ex:40-52`; test `test/foo_test.exs:88` |

<Missing, scope creep, and looks-wrong findings, in the finding format below.>

## Merge plan

1. <Merge order, with the reason for each step.>

## Chapter 1: #77, <topic>

**Before:** <one or two sentences>. **After:** <one or two sentences>.

`lib/foo.ex:40-52` at `e94fdc2` (<what this shows>)

```elixir
<trimmed snippet with short inline comments>
```

<details>
<summary>More context: <file or function></summary>

```elixir
<longer snippet>
```

</details>

### Findings

<Findings in the format below.>

### Checked, no issue found

<details>
<summary><n> checks</summary>

- <A risk that turned out fine, with its evidence.>

</details>

## Tests and verification

- <What the tests cover, as behaviors.>
- Mutation probe: <condition inverted at path:line>, `<command>`, <result>. Or "not run".
- Author's claims: <claim>, <evidence or `UNVERIFIED:`>.

## Beyond this PR

### Proposals

<In the options format below.>

### Pre-existing issues

## Comment drafts

| ID | PR | Anchor | Label | Topic |
|---|---|---|---|---|
| C1 | #78 | `lib/foo.ex:47` | Question | <topic> |

<Drafts in the format below.>

## Provenance

| PR | Repository | Base | Head |
|---|---|---|---|
| [#77](<url>) <title> | <repo> | `main` | `e94fdc2` |
| [#78](<url>) <title> | <repo> | #77 branch | `7a90b66` |

All line numbers refer to these heads.

- Date: <YYYY-MM-DD>. Mode: full | quick (Not verified).
- CI: <state per head, from `gh pr checks`>. Local runs: <what ran, or "none">.
- Readers: <the sub-agent readers that ran, or "none">.
- Standards applied: <files, as permalinks at a commit>.
- Sources read: <issue, design doc, threads, notes, each with a link or path>.
- Out of reach: <sources the trail points to but the review could not read, such as a
  chat thread or a meeting>.

### Review threads

- <Who raised it, where, the point, the author's reply, its state.>

## Review log

| ID | Hypothesis or challenge | Check | Outcome |
|---|---|---|---|
| H1 | <what might be wrong> | <what was traced or run> | Kept as F2 / Downgraded / Dropped |
| V1 | Verifier: <the claim it disputed> | <the source re-read> | Now reads "<the corrected text, quoted as it stands in the report>" |

### Earlier rounds

| Round | Head | What changed |
|---|---|---|
| 1 | `e94fdc2` | <first review> |
````

## Finding

One heading per finding, so the table of contents lists them. The ID is stable across
revisions of the report; do not renumber when a finding is dropped.

````markdown
#### F2 · Required · Behavior · `lib/foo.ex:40-52`

<What happens, for which input, and the evidence: callers traced, the guard that is
missing, the test that would fail. Label anything unproven `UNVERIFIED:`. Say whether it
is a regression or already on the base, and whether any flow reaches it today.>

Suggested change:

```elixir
<code>
```

Draft: [C2](#c2).
````

In local mode, the last line links the fix instead: `Fix: [Fix F2](#fix-f2).`

## Options

When a finding or a proposal has more than one viable fix, replace "Suggested change"
with the current code, one snippet per option, and a table that includes leaving the
code as it is. End with the recommendation and its reason. A finding with one obvious fix
keeps "Suggested change".

````markdown
Current, `lib/foo.ex:52`:

```elixir
<code>
```

Option A, <name> (recommended):

```elixir
<code>
```

Option B, <name>:

```elixir
<code>
```

| | A | B | Keep as is |
|---|---|---|---|
| Gains | <...> | <...> | <...> |
| Costs | <...> | <...> | <...> |
| Risk | <...> | <...> | <...> |

Recommendation: A, because <reason tied to the trail or the spec>.
````

## Comment draft

A checkbox line the reviewer ticks to pick the draft, then the body in a `~~~markdown`
fence so the viewer's copy button copies it verbatim and code fences inside it survive.
The anchor line must be inside the PR diff at the reviewed head.

````markdown
#### C2

- [ ] Post · #78 · `lib/foo.ex:47` (also `:52`) · Required

~~~markdown
<One to three sentences: the observation, then the question or the concrete suggestion.
Prefix with Critical:, Nit:, Consider:, or FYI: when the label is not Required.>
~~~
````

## Local mode

A review of a branch with no PR keeps the same sections, with four changes.

The heads table in Provenance has one row per branch. When the review covers uncommitted
work, the head column names the `-wip` snapshot, and every `path:line` refers to it:

```markdown
| Branch | Base | Merge base | Head |
|---|---|---|---|
| `feature/retry` | `origin/main` | `1a2b3c4` | `9f8e7d6` + work tree `5d4c3b2` |
```

The verdict is "Ready for a PR", "Fix first", or "Split first", with the split proposal
in the Merge plan section.

The trail comes from the issue, commit messages, the reviewer's notes (plans, worklogs,
design notes), and what the reviewer says. There are no review threads, so Provenance
has no "Review threads" list.

The fix list replaces the comment drafts: an index table like the drafts index, then one
block per fix, named after its finding so the ID stays stable. The checkbox marks the
fixes the reviewer wants applied. The fenced body is an instruction the reviewer can
paste into a prompt.

````markdown
#### Fix F2

- [ ] Fix · `lib/foo.ex:47` · Required

~~~markdown
<What to change and why, in one to three sentences. Add a short code block when the
change is not obvious from the sentence.>
~~~
````

## Later rounds

When the change gets a new round (new commits, fixes applied, a rebase), the report
describes the current head. Rewrite the Brief and every section above the chapters for
it, update the chapters, and add a row to "Earlier rounds" in the review log. Save the
previous report as `review.round-<n>.md` before rewriting it. Do not stack "delta"
sections or per-head verdicts at the top. Keep any section a workflow appends after the
review log, such as a `## Status` line that a push hook reads.

## Notes file

`notes.md` is the working file, kept from step 2 onward. It is never posted.

```markdown
# <Issue key> review notes

Heads: <repo#pr sha, ...>. CI: <state>. Mode: <full | quick>.

## Trail

- <date> · <where> · <said or decided> · Stated: <link> | Inferred: <receipt> | Not found

## Decisions

1. <choice> · alternatives on record: <options or none> · rationale: <provenance>

## Assumptions

1. <assumption> · Stated: <source> | Inferred: <path:line> · if false: <what breaks> ·
   status: open | holds | broken

## Expectations

- <From the trail, expect X in Y.> · met | differs: <path:line>

## Candidate findings

1. <finding> · axis: <Spec | Behavior | Design> · evidence: <path:line> ·
   status: open | kept | downgraded | dropped

## Checked, no issue

- <claim> · <evidence>

## Open questions for the reviewer

- <question>
```

## Lint before delivery

- The Brief holds at most 25 lines of text, blank lines aside:
  `awk '/^## /{b=($0=="## Brief"); next} b && NF' review.md | wc -l` prints 25 or less.
- The Brief points to at most three items:
  `awk '/^## /{b=($0=="## Brief"); next} b' review.md | grep -o '](#[^)]*)' | sort -u | wc -l`
  prints 3 or less.
- Every verifier correction landed: for each V row in the review log, the quoted text
  after "Now reads" is found in the section it corrects, and the old text is gone.
- Every in-report link resolves: `scripts/check-anchors.sh review.md` prints nothing and
  exits 0.
- Every row of the trail and every assumption carries Stated, Inferred, or Not found.
- No rationale is attributed to the author without a Stated source.
- Code lines stay within the repository's line limit. To find long lines, with `98`
  replaced by that limit: `awk '/^```/{c=!c; next} c && length($0)>98' review.md`.
- Every `path:line` names the head it refers to, directly or through the heads table.
- Every comment draft and fix is one to three sentences; a fix may add a code block.
- Run unslop's "Check the result" on the prose.
