# Sources and local decisions

Collected on 2026-10-31.

## Conventional Commits 1.0.0

The "Follow Conventional Commits" section restates the [specification][spec] and its
[summary][summary]. The examples labeled as the specification's come from its summary
(multi-paragraph body with footers) and its FAQ (revert).

FAQ answers adopted as defaults:

- "What do I do if the commit conforms to more than one of the commit types?" Make
  multiple commits. The skill proposes a split.
- "How should I deal with commit messages in the initial development phase?" Proceed as
  if already released. The skill marks breaking changes before 1.0.
- "How does Conventional Commits handle revert commits?" The spec leaves reverts to
  tooling and suggests a `revert` type with a `Refs:` footer of SHAs. The skill uses that
  suggestion.
- "Are the types in the commit title uppercase or lowercase?" Any casing, consistently.
  The skill defaults to lowercase, matching commitlint.

## commitlint defaults

[`@commitlint/config-conventional`][config-conventional] sets these rules, which the
skill's defaults follow or stay within:

- `type-enum`: build, chore, ci, docs, feat, fix, perf, refactor, revert, style, test.
- `type-case`: lower-case.
- `subject-case`: never sentence-case, start-case, pascal-case, or upper-case.
- `subject-full-stop`: never `.`.
- `header-max-length`, `body-max-line-length`, `footer-max-line-length`: 100.

The skill's 72-column limit is stricter than commitlint's 100 and matches committed's
default `line_length` of 72 ([reference][committed-ref]). Its aim of about 50
characters matches committed's default `subject_length`.

## Local decisions

- **Format gate.** Conventional Commits applies only when the user asks, configuration
  requires it, or most recent subjects use it. The author's dot-files repository had 1
  Conventional Commits subject in its last 200 non-merge commits, so an unconditional
  rule would have broken its convention.
- **No unsolicited linter advice.** Adding a linter changes dependencies, hooks, and CI,
  which is a repository decision. Suggesting a Conventional Commits linter in a
  repository that does not use the convention would also contradict the gate.
- **Run the existing linter.** A configured linter knows the allowed types, scopes, and
  limits. Running it on the draft replaces guessing.
- **unslop owns voice.** The body-only-when-needed rule lives in unslop's output
  budgets; this skill keeps guidance on what a body should contain.
- **Quoted heredoc for commits.** Inside `-m "..."`, the shell runs backtick text as a
  command and expands `$`.

Linter detection, check commands, and usage figures live in
[commit-linters.md](commit-linters.md), with their own sources.

[spec]: https://www.conventionalcommits.org/en/v1.0.0/#specification
[summary]: https://www.conventionalcommits.org/en/v1.0.0/#summary
[config-conventional]: https://github.com/conventional-changelog/commitlint/blob/master/%40commitlint/config-conventional/src/index.ts
[committed-ref]: https://github.com/crate-ci/committed/blob/main/docs/reference.md
