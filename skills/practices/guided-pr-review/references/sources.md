# Sources and local decisions

Collected on 2026-11-02. The upstream skills were read at the commits linked below. Most
of their text was paraphrased and merged. Two parts stay close to the originals: the
structural remedies list in `review-axes.md` follows Osmani's list item by item, and the
smell table follows Pocock's twelve smells and their fixes. Both licenses are reproduced
in [LICENSES.md](../LICENSES.md).

## The author's guided review practice

The story-first flow, the chapters, the notes file, the verify-or-drop loop, the review
log, the verifier pass, the comment drafts, the posting commands, and most pitfalls come
from the author's notes on a review of four PRs across two repositories, done with an
assistant in late 2026. Employer-specific names, guidelines, and examples were replaced
with neutral ones. The notes reported that the verifier checked about 95 claims, used
about 250k tokens, and found 2 wrong, about 10 imprecise line ranges or versions, and 3
unsupported readings of the contract, none of which changed a verdict.

The GitHub limits in the pitfalls were checked on 2026-11-02 with gh 2.100.0 against
public `rust-lang/rust` PRs: `gh pr view --json files` returned 100 of 283 files for
#165244, and `gh pr diff` on #165234 (306 files) failed with "HTTP 406: Sorry, the diff
exceeded the maximum number of files (300)".

## The briefing sections

On 2026-11-15 the author compared seven reports this skill wrote that month, on work and
personal repositories, with what they wanted from a report: the context of the change
in a minute, the discussion that led to it, the tradeoffs, the assumptions, and a
challenge to each. The reports ran 470 to 950 lines, and their first 28 to 39 lines held
heads, CI, and standards, ahead of the summary and the story. "Assum" appeared in one of
the seven, and the discussion before the change appeared mostly as review threads near
the end. Two sections
that worked had been improvised outside the template: a "Why each part is there" table
(part, why it is needed, what breaks without it), and an options table (option, change,
gains, costs) written in a separate notes file. The Brief, the trail, the decisions and
assumptions sections, the reading guide, the options format, and the Provenance section
came out of that comparison; the two improvised tables became template formats.

The Forgejo path of `fetch-pr.sh` was checked on 2026-11-15 against Codeberg (API
version `17.0.0-100-2254cb0+gitea-1.22.0` in its `swagger.v1.json`) with a development
build of `tea`, on public `forgejo/forgejo` PRs. Codeberg serves `refs/pull/<n>/head`;
`pulls/<n>/files` entries have no `patch` field; inline comments come per review from
`pulls/<n>/reviews/<id>/comments`; `issues/<n>/comments` takes only `since` and
`before`; and `tea api` printed the 404 error JSON and exited 0. Posting a review to
Forgejo was not tried: its comments take `new_position`, whose meaning was not checked.
Three of five reviews of a personal project that month had reviewed a Codeberg PR, each
with data fetched by hand in its own layout.

## Addy Osmani, code-review-and-quality

[`skills/code-review-and-quality/SKILL.md`][addy] in `addyosmani/agent-skills`.
[License][addy-license]: MIT, copyright (c) 2025 Addy Osmani.

Adapted:

- The approval standard: approve a change that improves the code's health overall.
- The five review axes. Correctness, security, and performance became the Behavior
  axis; readability and architecture joined repository standards under Design and
  standards.
- Reading tests early, and the mutation probe for "would the tests catch a regression".
- Checking findings against callers and guards, separating pre-existing defects from
  regressions, and accepting zero findings as a result.
- Severity labels (Critical, Required, Consider, Nit, FYI), leading with what matters,
  and checking the author's verification story.
- Structural remedies, change sizing, dependency and lockfile review, dead code
  handling, and the honesty rules.

Left out: the review-speed targets, the change-description guidance beyond one line,
the multi-model pattern (the verifier pass covers the second look), and the
rationalization and red-flag tables.

## Matt Pocock, code-review

[`skills/engineering/code-review/SKILL.md`][pocock] in `mattpocock/skills`.
[License][pocock-license]: MIT, copyright (c) 2026 Matt Pocock.

Adapted:

- Separate Spec and Standards axes that are reported apart and never reranked against
  each other. Here they are two of three axes, and the Brief's "Look at first" list takes
  the worst item of each axis before a second item from any one axis.
- Pinning the fixed point and failing early on a bad ref or an empty diff.
- The order for finding the spec, and the search for standards documents.
- The code smell baseline as judgment calls that a documented repository standard
  overrides, skipping what tooling enforces.
- Parallel readers with fresh contexts, one per axis.

Left out: the issue-tracker setup command, the 400-word limit per reader, and verbatim
aggregation of the readers' reports (here their findings go through verify-or-drop
first).

## Martin Fowler, Refactoring

The smell names in the baseline come from chapter 3, "Bad Smells in Code", of
*Refactoring: Improving the Design of Existing Code* (second edition, 2018), through the
Pocock skill's selection of twelve.

## Viewer dependencies

`assets/report-viewer.html` loads four libraries from jsDelivr, pinned by version and
by Subresource Integrity hash:

- [marked 12.0.2](https://github.com/markedjs/marked): MIT.
- [DOMPurify 3.1.6](https://github.com/cure53/DOMPurify): Apache-2.0 or MPL-2.0.
- [Mermaid 11.4.1](https://github.com/mermaid-js/mermaid): MIT.
- [highlight.js 11.11.1](https://github.com/highlightjs/highlight.js): BSD-3-Clause. The
  viewer loads the common bundle from `@highlightjs/cdn-assets` plus
  `languages/elixir.min.js`, which the bundle lacks. To add a language, load its file
  from the same `languages/` directory. A fence whose language is not loaded stays
  plain.

The token colours are the viewer's own CSS. They take their values from the
`--color-prettylights-syntax-*` tokens in [Primer Primitives][primer-primitives] 10.7.0
(MIT), the palette GitHub uses for code, so the light and dark themes match the rest
of the page.

To upgrade one, change the URL and recompute its hash:
`curl -sL <url> | openssl dgst -sha384 -binary | openssl base64 -A`.

## Viewer layout

The viewer's layout follows these patterns. It reuses no code from them, so
`LICENSES.md` does not list them.

- [VitePress `VPLocalNav.vue`][vp-localnav] and [`VPSidebar.vue`][vp-sidebar]: below
  60rem, a sticky bar with a menu button opens the sidebar as an off-canvas drawer,
  with body scroll locked while it is open.
- [Docusaurus `TOCCollapsible`][docusaurus-toc]: the in-page table of contents starts
  collapsed behind one toggle.
- [Primer TreeView guidelines][primer-tree]: the chevron only toggles and the label
  navigates; truncated labels need their full text reachable another way, so the
  drawer wraps labels instead of truncating them. The wide-screen column still cuts
  them to one line, with the full heading in a tooltip and one click away.
- [WAI-ARIA disclosure navigation][apg-disclosure]: each toggle is a button with
  `aria-expanded` and `aria-controls`, and Escape closes what it opened. This is
  simpler than the tree pattern's roving focus, which a table of contents does not
  need.

## Local decisions

- **Three axes.** Pocock's two axes keep a spec gap from hiding behind clean code; Addy's
  five axes catch defects neither spec nor standards name. Behavior holds the defects.
- **Reading order.** Addy reads tests before the implementation; the author's practice
  read production code first and scanned tests afterwards. The skill reads test names
  first for intent, production code in dependency order, then tests in full.
- **Verifier on by default.** It caught real errors in the worked example. `quick` mode
  skips it for a first look and marks the report "Not verified".
- **A briefing, not a replacement.** The reviewer reads the code anyway. The report gives
  them the context in one screen, says what to expect in the code and where it departs
  from the discussion, and keeps provenance detail at the end.
- **Provenance labels.** A report that explains why a change was made is tempted to
  supply reasons. Stated, Inferred, and Not found keep the author's reasons apart from
  the assistant's, and "Not found" turns a missing reason into a question.
- **Challenger on every full review.** Decisions and assumptions are cheap to list and
  easy to leave unexamined, and a reader with a fresh context argues against them better
  than the session that summarized them. It runs whatever the change's size; `quick`
  mode skips it.
- **No "Already raised" section.** Review threads are part of the discussion: their
  decisions go in the trail, and the per-comment detail goes in Provenance, re-fetched
  before posting.
- **Three items in the Brief.** In the first eval runs of the briefing, the Brief named
  the worst item per axis and then up to three items to look at first, which sent the
  reader to four to six items. The worst item of each axis now goes into the
  look-first list instead.
- **Corrections checked where they land.** In one eval run the review log recorded a
  verifier correction to a Spec row that the Spec table did not carry. The log now
  quotes the corrected text as the report reads, and the lint checks it.
- **Rounds rewrite the report.** Reports that stacked delta sections and per-head verdicts
  at the top were hard to read for the current state. Each round now rewrites the
  report for the current head and keeps the history in the review log.
- **Markdown canonical, HTML as a viewer.** Markdown diffs, renders on GitHub, and works
  offline. The viewer embeds the Markdown and renders it in the browser, so there is
  one source and no build step. It sanitizes the rendered HTML because reports quote PR
  bodies and comments, which are untrusted.
- **Report location.** Never inside a tracked path of the reviewed repository, so a
  review cannot be committed by accident.
- **Running PR code needs consent.** Running a PR's tests executes the PR.
- **Local mode.** A branch with no PR gets the same review. A snapshot commit, built
  through a temporary index, pins uncommitted work so its findings carry receipts while
  the checkout stays untouched. Findings end in a fix list, since there is nothing to
  post, and applying fixes waits for the reviewer as posting does.
- **No posting script.** `review.json` plus one `gh api` call is short enough to show
  the reviewer in full before posting.
- **Elixir remedies by name.** For Elixir diffs, structural remedies name an entry from
  the elixir-refactorings skill, which condenses Lucas Vegi and Marco Tulio Valente's
  Catalog of Elixir Refactorings (MIT). That skill's own `sources.md` and `LICENSES.md`
  carry the attribution; nothing from the catalog is copied into this skill.

[addy]: https://github.com/addyosmani/agent-skills/blob/301b02b12bff98e4688e6984af6556802322bbde/skills/code-review-and-quality/SKILL.md
[addy-license]: https://github.com/addyosmani/agent-skills/blob/301b02b12bff98e4688e6984af6556802322bbde/LICENSE
[pocock]: https://github.com/mattpocock/skills/blob/4ae2317ddb22b046e26455e4f9c9b3aaaf62212d/skills/engineering/code-review/SKILL.md
[pocock-license]: https://github.com/mattpocock/skills/blob/4ae2317ddb22b046e26455e4f9c9b3aaaf62212d/LICENSE
[vp-localnav]: https://github.com/vuejs/vitepress/blob/main/src/client/theme-default/components/VPLocalNav.vue
[vp-sidebar]: https://github.com/vuejs/vitepress/blob/main/src/client/theme-default/components/VPSidebar.vue
[docusaurus-toc]: https://github.com/facebook/docusaurus/blob/main/packages/docusaurus-theme-classic/src/theme/TOCCollapsible/index.tsx
[primer-tree]: https://primer.style/product/components/tree-view/guidelines
[apg-disclosure]: https://www.w3.org/WAI/ARIA/apg/patterns/disclosure/examples/disclosure-navigation/
[primer-primitives]: https://github.com/primer/primitives
