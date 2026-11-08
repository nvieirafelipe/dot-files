# Report template

The report is one Markdown file, `review.md`, rendered to `review.html` by
`scripts/render-report.sh`. Write it for a reviewer who has not read the code yet:
story first, then code in chapters, then what to post. Use `##` for sections and
chapters, `###` for groups inside them, and `####` for each finding, comment draft, and
fix.
The viewer builds its table of contents from all three levels, and anchors follow
GitHub's heading slugs, so `[C2](#c2)` works in both.

The viewer renders only these raw HTML tags: `details`, `summary`, `br`, `kbd`, `sub`,
and `sup`, plus HTML comments. Any other raw HTML in a block shows as literal text, so a
quoted PR body cannot break the page. Write tables and links in Markdown, and put quoted
PR text in a code span, a fenced block, or a `>` quote.

Omit a section that has nothing to say, except "Checked, no issue found": an empty one
there means the chapter was not reviewed.

## Sections

1. **Header:** title, "Local review. Not posted.", spec links, date, mode, the reviewed
   heads table, CI state, what ran locally, and the standards applied.
2. **Summary:** the verdict per PR, the worst item per axis, and the few items that
   matter before merge, most important first.
3. **The change:** why, what is new, what does not change yet, the PR graph, and one
   diagram of the changed components or the new flow.
4. **Spec:** the acceptance criteria table, then missing, scope creep, and looks-wrong
   findings.
5. **Merge plan:** for stacks and multi-repository changes, or, in local mode, a
   proposal to split the branch into PRs.
6. **Chapters:** one per PR, or per layer inside a large PR, in dependency order.
7. **Tests and verification:** what the tests cover, mutation probes and their results,
   and the author's verification claims against the evidence.
8. **Beyond this PR:** proposals that go past the PR's scope, and pre-existing issues.
9. **Already raised:** points other reviewers or bots made, re-fetched before writing.
   Omitted in local mode.
10. **Comment drafts:** an index, then one block per draft. In local mode, the fix list
    takes its place.
11. **Review log:** every hypothesis, the check, and the outcome, including the dropped
    ones.

## Skeleton

````markdown
# <Issue key or PR>: <what the change does>

Local review. Not posted.

- Spec: <issue link>, <RFC or contract link>, or "no spec available"
- Date: <YYYY-MM-DD> · Mode: full | quick (Not verified)
- Reviewed heads (all line numbers refer to these):

| PR | Repository | Base | Head |
|---|---|---|---|
| [#77](<url>) <title> | <repo> | `main` | `e94fdc2` |
| [#78](<url>) <title> | <repo> | #77 branch | `7a90b66` |

- CI: <state per head, from `gh pr checks`>. Local runs: <what ran, or "none">.
- Standards applied: <files, as permalinks at a commit>.

## Summary

<Two or three sentences: what the change achieves and whether it meets the spec.>

| PR | Verdict |
|---|---|
| #77 | Approve with suggestions |
| #78 | Approve once the author answers Q1 |

Worst item per axis:

- **Spec:** <item, or "none">
- **Behavior:** <item, or "none">
- **Design and standards:** <item, or "none">

Before merge:

1. <Item, with a link to its finding.>

## The change

**Why.** <The current behavior, and what the issue or RFC changes, in one sentence.>

**What is new.**

1. <New endpoint, call, or behavior.>

**Not changed yet.** <What still works the old way; for example, "no flow calls the new
functions".>

**How the PRs relate.** <One sentence, then the PR graph from diagrams.md.>

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

- <A risk that turned out fine, with its evidence.>

## Tests and verification

- <What the tests cover, as behaviors.>
- Mutation probe: <condition inverted at path:line>, `<command>`, <result>. Or "not run".
- Author's claims: <claim>, <evidence or `UNVERIFIED:`>.

## Beyond this PR

### Proposals

### Pre-existing issues

## Already raised

Re-fetched <YYYY-MM-DD HH:MM>.

- <Who raised it, where, the point, its state.>

## Comment drafts

| ID | PR | Anchor | Label | Topic |
|---|---|---|---|---|
| C1 | #78 | `lib/foo.ex:47` | Question | <topic> |

<Drafts in the format below.>

## Review log

| ID | Hypothesis | Check | Outcome |
|---|---|---|---|
| H1 | <what might be wrong> | <what was traced or run> | Kept as F2 / Downgraded / Dropped |
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

A review of a branch with no PR keeps the same sections, with three changes.

The heads table has one row per branch. When the review covers uncommitted work, the
head column names the `-wip` snapshot, and every `path:line` refers to it:

```markdown
| Branch | Base | Merge base | Head |
|---|---|---|---|
| `feature/retry` | `origin/main` | `1a2b3c4` | `9f8e7d6` + work tree `5d4c3b2` |
```

The summary verdict is "Ready for a PR", "Fix first", or "Split first", with the split
proposal in the Merge plan section.

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

## Notes file

`notes.md` is the working file, kept from step 2 onward. It is never posted.

```markdown
# <Issue key> review notes

Heads: <repo#pr sha, ...>. CI: <state>. Mode: <full | quick>.

## Candidate findings

1. <finding> · axis: <Spec | Behavior | Design> · evidence: <path:line> ·
   status: open | kept | downgraded | dropped

## Checked, no issue

- <claim> · <evidence>

## Open questions for the reviewer

- <question>
```

## Lint before delivery

- Code lines stay within the repository's line limit. To find long lines, with `98`
  replaced by that limit: `awk '/^```/{c=!c; next} c && length($0)>98' review.md`.
- Every `path:line` names the head it refers to, directly or through the heads table.
- Every comment draft and fix is one to three sentences; a fix may add a code block.
- Run unslop's "Check the result" on the prose.
