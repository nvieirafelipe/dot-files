---
name: writing-commit-messages
description:
  Writes and reviews commit messages. Follows Conventional Commits 1.0.0 where the
  repository uses it and the repository's own subject style elsewhere. Use when drafting
  a message for staged changes or a diff, rewording, amending, or squashing commits,
  writing a revert, reviewing a commit subject or body, choosing a commit type, scope, or
  breaking-change marker, or writing the PR title that a squash merge turns into a commit.
---

STARTER_CHARACTER = 📝

# Writing commit messages

Write a message that tells a future reader what changed and why. Base it on the actual
change and follow the repository's conventions.

Load [unslop](../unslop/SKILL.md) before drafting or reviewing. It owns voice,
vocabulary, and the rule that a body appears only when the subject leaves the reason
unclear. This skill owns the message format and its accuracy against the change.

## Establish what belongs in the commit

- Use the supplied diff or commit range. For a pending commit, inspect
  `git status --short` and `git diff --cached`; use `git diff` to separate unstaged work.
  Never describe unstaged changes as part of a staged commit.
- If nothing is staged, use a supplied change set or ask what the commit should
  contain. Read untracked files only when they belong to that scope.
- For an amend, squash, or fixup, describe the resulting commit as a whole, not the
  sequence of edits that produced it. `git diff --cached HEAD~1` shows what an amended
  commit will contain.
- Identify the resulting behavior and the reason for the change. Read nearby code when
  the diff alone does not establish either. Do not invent motivation, issue numbers,
  compatibility guarantees, or test results.
- When the changes fit more than one type or serve unrelated purposes, propose a split.
  Keep tests and supporting edits with the behavior they establish. Drafting a message
  does not authorize staging, committing, or rewriting history.

## Choose the format

Read the repository's rules before drafting. Earlier sources win:

1. The user's explicit request.
2. Repository configuration: a commit linter, a `commit-msg` hook, a commit template
   (`git config commit.template`), or contributing notes.
   [commit-linters.md](references/commit-linters.md) lists the files that reveal each
   linter.
3. Recent history: `git log --no-merges -30 --format=%s`.

Use Conventional Commits when the user asks for it, when configuration requires it, or
when most recent subjects match `^[a-z]+(\([^)]+\))?!?: `. Otherwise match the subject
style of recent history and apply only the defaults under "Make the message useful".
A configured linter's rules (allowed types and scopes, length limits, subject case)
override this skill's defaults.

Do not suggest installing a commit linter while drafting a message. Recommend one only
when the user asks how to enforce or adopt a convention; the linter reference lists a
choice per ecosystem.

## Follow Conventional Commits

Based on the [1.0.0 specification][spec] and its [summary][summary]:

```text
type(scope)!: description

body

footers
```

Scope, `!`, body, and footers are optional.

- Use `feat` when the commit adds a feature and `fix` when it fixes a bug; the
  specification requires both. Other types are allowed.
- A scope is a parenthesized noun naming a section of the codebase. Follow the prefix
  with a colon, a space, and a short description.
- Separate the body and footer sections from the subject and from each other with one
  blank line. Footers may follow the subject directly when there is no body.
- Mark incompatibility with `!` immediately before the colon, a
  `BREAKING CHANGE: explanation` footer, or both. Any type can break compatibility.
  With `!` alone, the description explains the breaking change.
- Footer tokens use hyphens instead of spaces, except `BREAKING CHANGE`. Separators are
  `: ` or ` #`; values may span lines until the next footer. `BREAKING-CHANGE` is an
  equivalent token. Breaking-change tokens are uppercase; parsers treat everything else
  as case-insensitive.
- SemVer mappings are `fix` to PATCH, `feat` to MINOR, and breaking changes to MAJOR.
  Other types imply no bump by themselves. Actual releases depend on repository
  tooling.

## Make the message useful

These are writing defaults, not requirements of the specification. Explicit
preferences and repository configuration win when they differ.

- Use lowercase types. Pick the established type that fits: `feat`, `fix`, `docs`,
  `test`, `refactor`, `perf`, `build`, `ci`, `style`, `revert`, or `chore`. `style`
  means formatting that does not change meaning, such as whitespace or semicolons; it
  does not mean CSS or UI styling. Reserve `chore` for maintenance without a more
  informative type. File extensions alone do not determine the type.
- Choose the type for the purpose of the whole change. Tests accompanying a bug fix
  belong under `fix`. An internal rewrite that preserves behavior can use `refactor`;
  fixing incorrect behavior is still `fix`.
- Include a scope only when it helps locate the change. Reuse scopes from history or
  from the linter's allowed list instead of listing files or inventing a taxonomy.
- Start the description with an imperative verb: `reject`, `preserve`, `add`, or
  `remove`. Name the behavior or object. Avoid subjects such as "update code", "misc
  fixes", or "improve handling" that conceal the actual change.
- In Conventional Commits, start the description lowercase; commitlint's default rules
  reject a capitalized one. In other repositories, follow the capitalization in
  history.
- Keep the whole header, prefix included, at 72 characters or fewer, and aim for about
  50. Shorten wording without losing the distinguishing detail. Omit the final period.
- Wrap body and footer lines at 72 columns.
- When a body is needed, explain the trigger, previous behavior, or tradeoff that a
  future reader would otherwise have to reconstruct. Avoid file inventories and
  line-by-line diff narration.
- A change breaks compatibility when an existing consumer must change: a public API,
  CLI flag, configuration key, environment variable, event payload, or a schema change
  that needs a migration. An internal refactor does not. Mark breaking changes before a
  1.0 release too. When the subject cannot say what consumers must change, say it in
  the breaking-change footer.
- For a revert in a Conventional Commits repository, use the `revert` type with a
  description of what is reverted, and list the reverted SHAs in a `Refs:` footer.
  Elsewhere, keep the `Revert "<subject>"` message that `git revert` writes.
- Include issue references and trailers only when their values are known, together in
  the final paragraph. Do not add credit or verification claims unless an applicable
  instruction requires them.
- In a squash-merge repository, the PR title becomes the commit subject; GitHub appends
  the PR number as `(#123)`. Apply these rules to the PR title.

## Examples

A documentation-only correction needs no body:

```text
docs(setup): correct the config directory path
```

A fix can explain the condition that made it necessary:

```text
fix(cache): include locale in response keys

Requests for different locales shared a key, allowing a cached French
response to reach an English client.
```

A breaking change can show the replacement consumers need:

```text
feat(cli)!: replace --output with --format

BREAKING CHANGE: Use --format=json instead of --output=json in scripts.
```

The specification's example of a multi-paragraph body with several footers:

```text
fix: prevent racing of requests

Introduce a request id and a reference to latest request. Dismiss
incoming responses other than from latest request.

Remove timeouts which were used to mitigate the racing issue but are
obsolete now.

Reviewed-by: Z
Refs: #123
```

The specification's suggested revert:

```text
revert: let us never again speak of the noodle incident

Refs: 676104e, a215868
```

A repository whose history uses plain imperative subjects gets no prefix:

```text
Open the line under the review cursor in nvim with E
```

## Check the draft

- Check that every claim matches the intended diff, the type describes its purpose,
  and any incompatible change is marked.
- When the repository has a commit linter installed, run it on the draft before
  delivering. [commit-linters.md](references/commit-linters.md) lists the command for
  each. Write the draft to a temporary file outside the repository. Do not install a
  linter to check a draft.

## Deliver

Return one ready-to-use message in a code block unless the user requests another
format or alternatives. For a review, explain material problems and supply a corrected
message. For a commit that is already pushed or released, do not suggest rewriting
history unless the user asks.

When asked to commit, pass the message through a quoted heredoc. Inside `-m "..."`
double quotes, the shell runs any text in backticks as a command and expands `$`.

```bash
git commit -F - <<'EOF'
fix(cache): include locale in response keys

Requests for different locales shared a key, allowing a cached French
response to reach an English client.
EOF
```

Read [sources.md](references/sources.md) when maintaining this skill.

[spec]: https://www.conventionalcommits.org/en/v1.0.0/#specification
[summary]: https://www.conventionalcommits.org/en/v1.0.0/#summary
