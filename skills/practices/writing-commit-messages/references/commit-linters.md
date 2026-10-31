# Commit linters

Collected on 2026-10-31 from each tool's repository and package registry. Use this file
to detect a repository's linter, check a draft with it, and choose one when the user
asks how to enforce a convention.

## Detect a linter

| Linter | Style it enforces | Revealed by |
|---|---|---|
| [commitlint] | Conventional Commits, through `@commitlint/config-conventional` | `commitlint.config.*`, `.commitlintrc*`, or a `commitlint` key in `package.json` |
| [commitizen] (Python) | Conventional Commits by default; custom rules possible | `.cz.toml`, `cz.toml`, `.cz.json`, `cz.json`, `.cz.yaml`, `cz.yaml`, or `[tool.commitizen]` in `pyproject.toml` |
| [cz-cli] (Node) | Prompts for a message; does not lint | `.czrc` or `config.commitizen` in `package.json` |
| [cocogitto] | Conventional Commits only | `cog.toml` |
| [convco] | Conventional Commits | `.convco`, or `.versionrc` (conventional-changelog's file, which convco also reads) |
| [committed] | `style = "none"` (default) or `"conventional"` | `committed.toml` |
| [git_ops] | Conventional Commits | `config :git_ops` in `config/*.exs` |
| [conventional-pre-commit] | Conventional Commits | hook id `conventional-pre-commit` in `.pre-commit-config.yaml` |
| [conform] | Conventional Commits, imperative mood, header length, DCO, GPG | `.conform.yaml` |
| [action-semantic-pull-request] | Conventional Commits on PR titles | `amannn/action-semantic-pull-request` in `.github/workflows/` |
| [commitlint-github-action] | commitlint rules on every commit in a PR | `wagoid/commitlint-github-action` in `.github/workflows/` |

Hook managers do not lint by themselves. Read the `commit-msg` entry to see which linter
it calls: `.husky/commit-msg`, a `commit-msg:` section in `lefthook.yml`,
`stages: [commit-msg]` in `.pre-commit-config.yaml`, or `config :git_hooks` in an
Elixir project.

Release tools that compute versions from commit types also imply Conventional Commits,
even without a linter: semantic-release (`.releaserc*`, or a `release` key in
`package.json`) and release-please (`release-please-config.json`).

committed defaults to a capitalized subject, while commitlint's default rules reject
one. Read the configured rules rather than assuming a tool's defaults.

## Check a draft

Run only a linter that is already installed. `npx --no` refuses to download a package
that is missing.

| Linter | Command |
|---|---|
| commitlint | `npx --no commitlint < "$draft"` |
| commitizen | `cz check --commit-msg-file "$draft"` |
| cocogitto | `cog verify --file "$draft"` |
| convco | `convco check --from-stdin < "$draft"` |
| committed | `committed --commit-file "$draft"` |
| git_ops | `mix git_ops.check_message "$draft"` |

Sources: commitlint reads stdin when `--edit`, `--env`, `--from`, and `--to` are
omitted ([CLI reference][commitlint-cli]). commitizen documents `--message` and
`--commit-msg-file` ([check command][cz-check]). cocogitto documents `cog verify --file`
([verify guide][cog-verify]). convco documents `--from-stdin` in its README. committed
documents `--commit-file` ([reference][committed-ref]). git_ops documents
`mix git_ops.check_message <path>` in the task's moduledoc.

## Recommend a linter

Recommend one only when the user asks how to enforce or adopt a convention.

| Repository | Recommend | Why |
|---|---|---|
| Node | commitlint with husky or lefthook | Most used by a wide margin; shares rules with the GitHub Action |
| Python | commitizen, or conventional-pre-commit when pre-commit is already in use | commitizen also bumps versions and writes changelogs |
| Elixir | git_ops, wired with `mix git_ops.message_hook` or elixir_git_hooks | Runs through `mix`; also manages releases and changelogs |
| Several languages, no Node | cocogitto or convco | Single binaries |
| No Conventional Commits | committed with `style = "none"` | Checks imperative mood, length, capitalization, WIP and fixup commits without a type prefix |
| Squash merges | action-semantic-pull-request | The PR title becomes the commit subject |

## Usage

| Package | Registry | Downloads | GitHub stars |
|---|---|---|---|
| `@commitlint/cli` | npm | 44.5M in the month to 2026-10-29 | 18.8k |
| `commitizen` (Python) | PyPI | 3.0M last month | 3.5k |
| `commitizen` (cz-cli) | npm | 7.1M in the month to 2026-10-29 | 17.5k |
| `conventional-pre-commit` | PyPI | 190k last month | 560 |
| `git_ops` | Hex | 82k recent, 919k all time | 156 |
| `committed` | crates.io | 11.9k in 90 days | 186 |
| `cocogitto` | crates.io | 8.3k in 90 days | 1.2k |
| `convco` | crates.io | 4.8k in 90 days | 330 |

Registry downloads include CI installs and differ in method, so compare within a
registry, not across them. crates.io misses Rust tools installed through Homebrew or
release binaries. gitlint (588k PyPI downloads last month) is left out of the
recommendations: its latest release is v0.19.1 from March 2023.

Queries: `api.npmjs.org/downloads/point/last-month/<package>`,
`pypistats.org/api/packages/<package>/recent`, `crates.io/api/v1/crates/<crate>`
(`recent_downloads` covers 90 days), `hex.pm/api/packages/git_ops`, and
`gh api repos/<owner>/<repo>` for stars.

[commitlint]: https://github.com/conventional-changelog/commitlint
[commitlint-cli]: https://github.com/conventional-changelog/commitlint/blob/master/docs/reference/cli.md
[commitizen]: https://github.com/commitizen-tools/commitizen
[cz-check]: https://github.com/commitizen-tools/commitizen/blob/master/docs/commands/check.md
[cz-cli]: https://github.com/commitizen/cz-cli
[cocogitto]: https://github.com/cocogitto/cocogitto
[cog-verify]: https://github.com/cocogitto/cocogitto/blob/main/website/guide/verify.md
[convco]: https://github.com/convco/convco
[committed]: https://github.com/crate-ci/committed
[committed-ref]: https://github.com/crate-ci/committed/blob/main/docs/reference.md
[git_ops]: https://github.com/zachdaniel/git_ops
[conventional-pre-commit]: https://github.com/compilerla/conventional-pre-commit
[conform]: https://github.com/siderolabs/conform
[action-semantic-pull-request]: https://github.com/amannn/action-semantic-pull-request
[commitlint-github-action]: https://github.com/wagoid/commitlint-github-action
