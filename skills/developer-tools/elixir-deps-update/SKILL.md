---
name: elixir-deps-update
description: Update this project's Hex dependencies and open a PR documenting every version change. Works on GitHub (via gh) and Codeberg/Gitea/Forgejo (via tea).
disable-model-invocation: true
---

# Update Elixir Dependencies & Open a PR

Update this project's outdated Hex dependencies — all of them by default, or all
but a set the user opts out of — verify with `mix precommit`, then open a pull
request whose body documents every direct and transitive version change with a
`diff.hex.pm` link, a version-anchored changelog link, and inlined changelog
highlights.

Forge-agnostic: the workflow is identical on GitHub and on the Gitea family
(Codeberg, Gitea, Forgejo). Only the PR-creation command and the autolink rules
for quoted changelog text differ, and both are called out where they diverge.

## Requirements

- Elixir/`mix` project with a `precommit` alias
- `python3`, `curl`, `jq`
- A forge CLI matching the remote, authenticated, with access to this repo:
  - **GitHub** — `gh`
  - **Codeberg / Gitea / Forgejo** — `tea` (`tea login ls` shows a login for the host)

## Workflow

### 1. Preflight — detect the forge, clean tree, fresh branch

Identify which forge this repo lives on and which branch to target. List **all**
remotes and push URLs — `git remote get-url origin` alone returns only the fetch
URL and will mislead you on a mirrored repo:

```bash
git remote -v
git remote get-url --push --all origin
BASE=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
BASE=${BASE:-$(git remote show origin | sed -n 's/.*HEAD branch: //p')}
```

Read the hosts and pick the forge — this choice drives step 7's quoting rules
and step 8's PR command:

- only `github.com` appears → **GitHub**, use `gh`
- only a Gitea-family host appears (`codeberg.org`, a Gitea/Forgejo instance) →
  **Gitea family**, use `tea`
- **more than one host appears** → mirrored repo. Do not guess. Ask the user
  which forge should receive the PR, and name the hosts you found so the answer
  is one word. A single remote can carry several push URLs (`origin` pushing to
  both a Codeberg canonical and a GitHub mirror is a common layout, and its
  fetch URL may be the mirror), so this is not an exotic case.

Verify the CLI is present and authenticated before doing any work; if it isn't,
stop and tell the user rather than reaching the end with an un-openable PR:

```bash
gh auth status          # GitHub
tea login ls            # Gitea family — the remote's host must appear here
```

Confirm `git status` is clean. If there are uncommitted changes, stop and ask
the user how to proceed — don't fold unrelated work into a dependency PR.

Get onto an up-to-date base and cut a branch named for the update — packages
when few, otherwise the date:

```bash
git checkout "$BASE" && git pull
git checkout -b deps/update-$(date +%Y-%m-%d)
```

`$BASE` is written as a shell variable throughout for readability, but each
command below may run in a fresh shell — substitute the actual branch name you
resolved here rather than assuming the variable is still set.

**Done when:** the forge and base branch are known, the matching CLI is
authenticated, and you're on a new branch off an up-to-date base with a clean
tree.

### 2. Identify outdated dependencies

```bash
mix hex.outdated
```

Read the output and split it into:

- **Safe** — only the patch or minor version changed (no major bump)
- **Breaking** — the major version changed (e.g. `1.x` → `2.x`)

Present both lists to the user so they can see what's on the table.

**Done when:** every outdated package is classified safe or breaking and shown
to the user.

### 3. Choose what to update

The default is to update **everything**. Ask the user whether they want to opt
any packages out of this run; the default answer is none. Record the resulting
update set (all outdated packages minus any they skip).

**Done when:** there is an explicit update set and the user has had the chance to
exclude packages.

### 4. Apply the updates

- Taking the whole set: `mix deps.update --all`.
- Skipping some: list only the ones to take — `mix deps.update dep_a dep_b …`.
- For a **breaking** bump the user chose to take, first widen the constraint in
  `mix.exs` to allow the new major, then `mix deps.update <dep>`.

**Done when:** `mix.lock` reflects exactly the intended set and `mix deps.get`
runs clean.

### 5. Handle breaking changes

For each major bump taken, before moving to the next one:

1. Find the changelog or upgrade guide — try `https://hexdocs.pm/<pkg>/changelog.html`
   first, then the package root `https://hexdocs.pm/<pkg>` for a "Changelog",
   "Upgrade Guide", or "Migration Guide" link.
2. Apply the code changes the upgrade requires.
3. Run step 6 verification. Only advance once it's green.

**Done when:** every major bump taken has its code changes applied and verifies
clean.

### 6. Verify

```bash
mix precommit
```

Fix whatever it reports — formatting (`mix format`), compile warnings, failing
tests — and re-run until it exits 0.

**Done when:** `mix precommit` passes with no changes left to make.

### 7. Draft the PR body

Extract the actual version changes from the lock diff and classify them:

```bash
git diff "$BASE" -- mix.lock \
  | python3 ~/.claude/skills/elixir-deps-update/scripts/parse_mix_lock_diff.py
```

This yields a JSON array holding one `{package, app, old_version, new_version,
status}` object per changed package. `package` is the Hex registry name — use
it to build the diff and hexdocs links. `app` is the lock's own key; it differs
from `package` only occasionally (see Notes). If the script warns on stderr
that lines look like Hex entries but didn't parse, stop and fix the script
rather than shipping a PR body that silently omits those packages.

Classify each as **direct** (named in the `deps/0` function of `mix.exs`) or
**transitive** (everything else):

```bash
sed -n '/defp deps do/,/^  end/p' mix.exs | grep -oE '\{:[a-zA-Z0-9_]+' | sed 's/{://' | sort -u
```

For each changed package `<pkg>` going `<old>` → `<new>`:

- **Diff link** (always available, no fetch): `https://diff.hex.pm/diff/<pkg>/<old>..<new>`
- **Changelog link + highlights** — where a library publishes its changelog
  varies, so walk the lookup ladder in
  [reference/finding-changelogs.md](reference/finding-changelogs.md) (hexdocs
  changelog page → hexdocs sidebar → Hex-API source repo → GitHub changelog
  files → Releases → compare view). Include **both** a link to the changelog
  and inline highlights:
  - **Link:** point at the changelog you actually read, and deep-link to the
    release with a version anchor when the page has one (`…/changelog.html#<anchor>`).
    Derive and verify the anchor per that reference — don't guess. When the diff
    spans several releases (a minor bump crossing multiple versions), anchor to
    the newest/target version so the reader lands at the top of the range
    (changelogs are reverse-chronological).
  - **Highlights:** quote the authors' entries with light cleanup; never invent.
    Requalify anything the forge will re-resolve against *this* repo — both
    GitHub and the Gitea family autolink a bare `#123` to your own issue 123 and
    a bare `@handle` to an unrelated account on *their own* host. Strip
    `@handle` credits, and rewrite issue references in the form the target forge
    resolves correctly:
    - **GitHub PR, upstream repo on GitHub** — `<owner>/<repo>#123`.
    - **Gitea-family PR** — a full URL
      (`https://github.com/<owner>/<repo>/issues/123`). `<owner>/<repo>#123`
      resolves against the *same instance*, so on Codeberg it points at a
      Codeberg repo that is unrelated or nonexistent.

    See
    [reference/finding-changelogs.md](reference/finding-changelogs.md#quoting-safely-cross-repo-references).
    If the ladder runs out, drop the changelog link, say "no changelog found",
    and keep the diff link.

Assemble the body. Join the diff and changelog links with ` · `; for one-line
transitive entries put both links and the note on the same line:

```markdown
## Summary
<1-2 sentences: dependency update, note if any breaking bumps needed code changes>

## Direct Dependencies
**<pkg>** `<old> → <new>`
[diff](https://diff.hex.pm/diff/<pkg>/<old>..<new>) · [changelog](<changelog-url>#<anchor>)
- changelog highlight
- changelog highlight

## Transitive Dependencies
**<pkg>** `<old> → <new>` — [diff](https://diff.hex.pm/diff/<pkg>/<old>..<new>) · [changelog](<changelog-url>#<anchor>) — <one-line note>
```

Omit a section entirely if it has no entries — no empty headers.

**Done when:** every package in the diff JSON has a diff link and either a
version-anchored changelog link with highlights, or an explicit "no changelog
found" note — no quoted highlight carries a bare `#123` or `@handle`, and on a
Gitea-family forge no upstream reference is left in `owner/repo#123` shorthand.

### 8. Commit and open the PR

Build a subject that **names the libraries updated**. Only a handful → name them
all (`update req, jason, phoenix_live_view`). A long list → name the prominent
ones and summarize the rest (`update phoenix, ecto, and 9 others`). Use the same
subject for the commit and the PR title.

Before pushing, scan the body file for references the target forge would resolve
against *this* repo or *this* instance:

```bash
grep -nE '(^|[^A-Za-z0-9_./-])#[0-9]+' <path>        # bare issue/PR refs (both forges)
grep -nE '(^|[^A-Za-z0-9_/-])@[A-Za-z0-9-]+' <path>  # bare @mentions (both forges)
grep -nE '(^|\s)[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+#[0-9]+' <path>  # Gitea family only
```

On **GitHub**, qualified refs (`owner/repo#123`) don't match the first two
greps, so every hit is either a verbatim upstream reference to fix or a
deliberate pointer at this repo (a "supersedes #192" in the summary is fine).

On the **Gitea family**, run the third grep as well: a qualified ref is *not*
safe there — it resolves against the same instance, so an upstream GitHub
reference must be a full URL instead. Every hit is a fix unless it names a repo
that really is on this instance.

Fix these before pushing — once the PR is open the bad links have already
back-linked onto whatever issues they hit.

Stage explicitly by name — the dependency files plus any source files touched
for a breaking bump. Never `git add -A` or `git add .`:

```bash
git add mix.exs mix.lock <any files changed for breaking bumps>
git commit -m "chore(deps): <subject>"
git push -u origin HEAD
```

Push to whichever remote serves the forge chosen in step 1 — on a mirrored repo
that may not be `origin`, and the PR command below fails if the branch never
reached the host it targets.

Then open the PR with the CLI for this forge:

```bash
# GitHub
gh pr create --base "$BASE" --title "chore(deps): <subject>" --body-file <path>

# Gitea family (Codeberg, Gitea, Forgejo)
tea pulls create \
  --base "$BASE" \
  --head "$(git branch --show-current)" \
  --title "chore(deps): <subject>" \
  --description "$(cat <path>)"
```

- Conventional-commit type + lowercase subject.
- Write the body to a real file either way. `gh` takes it via `--body-file` (not
  `--body -`); `tea` has no file flag, so pass the file's contents through
  `--description "$(cat <path>)"` — the double quotes keep newlines intact.
- No `Co-Authored-By` trailer and no AI attribution anywhere in the commit or PR.

Report the PR URL back to the user. `tea` prints the PR index rather than a
URL — compose it as `<remote-host>/<owner>/<repo>/pulls/<index>`.

## Notes

- Hex package names in `mix.lock` are usually the registry name, but the entry
  is `"app_name" => {:hex, :hex_name, ...}` and `diff.hex.pm` / hexdocs key off
  `hex_name`. They match in the vast majority of cases but occasionally differ.
  The parser returns `hex_name` as `package` and `app_name` as `app`, so build
  links from `package`.
- `mix.lock` entries use either `"app" => {:hex, ...}` or `"app": {:hex, ...}`
  depending on the Mix version that wrote them; the parser accepts both.
- If `mix hex.outdated` reports nothing outdated, tell the user and stop —
  don't cut a branch or open an empty PR.
- Forge detection comes from the remotes' hosts, not from which CLIs happen to
  be installed — having both `gh` and `tea` on the machine is common, and
  picking the wrong one fails only at the very last step.
- Where the *upstream package* is hosted is independent of where *this repo* is
  hosted. Nearly every Hex package lives on GitHub, so changelog lookup stays on
  GitHub even for a Codeberg-hosted project; only the PR body's own autolink
  rules follow the target forge.
- The Gitea family resolves `owner/repo#123` against its own instance, so the
  qualified form that is correct on GitHub is wrong on Codeberg. Full URLs are
  the only cross-forge-safe way to cite an upstream issue.

## Attribution

Original author: **Mike Zornek** (<zorn@zornlabs.com>), from
<https://github.com/zorn/dotfiles/tree/main/claude/skills/elixir-deps-update>
(commit `b039069`, 2026-08-14). Licensed MIT — see `LICENSE` in this directory.
Local modifications live in the `skill-factory` repo history.

Local changes on top of the original: forge detection from the `origin` remote,
a `tea` path for Codeberg/Gitea/Forgejo alongside the original `gh` path,
derived base branch instead of a hardcoded `main`, explicit-by-name staging
instead of `git add -A`, and per-forge rules for autolinked references in quoted
changelog text.
