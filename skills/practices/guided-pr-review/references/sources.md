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
  each other. Here they are two of three axes, and the summary names the worst item per
  axis.
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

`assets/report-viewer.html` loads three libraries from jsDelivr, pinned by version and
by Subresource Integrity hash:

- [marked 12.0.2](https://github.com/markedjs/marked): MIT.
- [DOMPurify 3.1.6](https://github.com/cure53/DOMPurify): Apache-2.0 or MPL-2.0.
- [Mermaid 11.4.1](https://github.com/mermaid-js/mermaid): MIT.

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

[addy]: https://github.com/addyosmani/agent-skills/blob/301b02b12bff98e4688e6984af6556802322bbde/skills/code-review-and-quality/SKILL.md
[addy-license]: https://github.com/addyosmani/agent-skills/blob/301b02b12bff98e4688e6984af6556802322bbde/LICENSE
[pocock]: https://github.com/mattpocock/skills/blob/4ae2317ddb22b046e26455e4f9c9b3aaaf62212d/skills/engineering/code-review/SKILL.md
[pocock-license]: https://github.com/mattpocock/skills/blob/4ae2317ddb22b046e26455e4f9c9b3aaaf62212d/LICENSE
[vp-localnav]: https://github.com/vuejs/vitepress/blob/main/src/client/theme-default/components/VPLocalNav.vue
[vp-sidebar]: https://github.com/vuejs/vitepress/blob/main/src/client/theme-default/components/VPSidebar.vue
[docusaurus-toc]: https://github.com/facebook/docusaurus/blob/main/packages/docusaurus-theme-classic/src/theme/TOCCollapsible/index.tsx
[primer-tree]: https://primer.style/product/components/tree-view/guidelines
[apg-disclosure]: https://www.w3.org/WAI/ARIA/apg/patterns/disclosure/examples/disclosure-navigation/
