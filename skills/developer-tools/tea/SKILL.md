---
name: tea
description: >
  Manage Codeberg, Gitea, and Forgejo repos, issues, PRs, releases, and CI/CD via the tea CLI.
  Use when the user mentions Codeberg, Gitea, Forgejo, tea CLI, references codeberg.org URLs,
  or works with Gitea-compatible forges.
---

STARTER_CHARACTER = 🍵

## Prerequisites

Before any operation, verify `tea` is installed and authenticated:

```bash
which tea && tea --version
```

- **Not found**: Show installation instructions (see below), then STOP. Do NOT auto-install.
- **Found**: Continue with the operation.

### Installation

```bash
# Homebrew (preferred)
brew install tea

# Login to Codeberg
tea login add --name codeberg --url https://codeberg.org

# Login to a self-hosted instance
tea login add --name myforge --url https://gitea.example.com --token <token>
```

Authentication methods: application token (recommended), OAuth, SSH key, basic auth.

## Context awareness

Tea auto-detects the git remote in `$PWD` and matches it to a configured login. Inside a repo hosted on a configured instance, `--login` and `--repo` flags are optional.

## Tools

**`tea` CLI** — primary tool for all operations:
- Repos, issues, PRs, releases, labels, milestones, branches
- CI/CD (actions, secrets, variables, workflow runs)
- Organizations, notifications, time tracking, webhooks

**`tea api`** — raw authenticated API requests for anything the CLI doesn't cover:
```bash
tea api /repos/{owner}/{repo}/topics --method GET
tea api /repos/{owner}/{repo} --method PATCH --data '{"description":"new desc"}'
```

Do NOT use WebFetch for `codeberg.org` or Gitea instance URLs. Use the CLI instead.

## Parsing input

Accept these formats and extract owner/repo/number:
- `codeberg.org/{owner}/{repo}/issues/{N}` — issue N
- `codeberg.org/{owner}/{repo}/pulls/{N}` — PR N
- `gitea.example.com/{owner}/{repo}` — repo
- `{owner}/{repo}#{N}` — issue/PR N
- Plain `#N` within a repo context — issue/PR N

## Issues

```bash
# List issues
tea issues ls
tea issues ls --state open --labels bug --assignee user

# Create issue
tea issues create --title "Title" --description "Body" --labels bug --assignees user

# Edit issue
tea issues edit 42 --title "New title" --assignees user

# Close / reopen
tea issues close 42
tea issues reopen 42
```

## Pull requests

```bash
# List PRs
tea pulls ls
tea pulls ls --state open

# Create PR
tea pulls create --base main --head feature-branch --title "Title" --description "Body"

# AGit push-to-create (no fork needed)
tea pulls create --agit

# Checkout PR locally
tea pulls checkout 42

# Review
tea pulls approve 42
tea pulls reject 42

# Merge (styles: merge, rebase, squash, rebase-merge)
tea pulls merge 42 --style squash

# Clean up branches after merge
tea pulls clean 42
```

## Repos

```bash
# List repos
tea repos ls
tea repos ls --owner user --type forks

# Search repos
tea repos search --owner org --topic api

# Create repo
tea repos create --name my-repo --description "Description" --init --private

# Create from template
tea repos create-from-template --template owner/template --name new-repo

# Fork
tea repos fork owner/repo

# Clone
tea clone owner/repo

# Edit
tea repos edit --name repo --description "New desc" --default-branch main

# Delete (careful!)
tea repos delete owner/repo --force
```

For detailed command references, see:
- [Pull request workflows](references/pull-requests.md)
- [Release management](references/releases.md)
- [CI/CD and Actions](references/ci-cd.md)
- [Project management](references/project-management.md) (labels, milestones, orgs, time tracking, notifications, webhooks)

## Output and scripting

Six output formats via `--output`: `simple`, `table`, `csv`, `tsv`, `yaml`, `json`.

Filter fields with `--fields`:
```bash
tea issues ls --output json --fields index,title,state
tea pulls ls --output csv --fields index,title,author
```

Pagination: `--limit` and `--page`.

## Presenting results

- **Search/list results** — numbered list: ID, title, state, author/assignee
- **Entity details** (issue, PR, repo) — full fields: ID, title, state, body, URL
- **Collection listings** (labels, milestones, branches) — formatted list

Suggest relevant follow-up actions after presenting any result.

## Error handling

- **CLI not found** (`which tea` empty): Show install instructions, do NOT auto-install
- **Auth failure** ("unauthorized" / "invalid token"): Guide user to `tea login add`
- **Not found** ("404" or "not found"): Confirm owner/repo/number, suggest search
- **No login configured** ("no login"): Guide user to `tea login add`
- **Wrong instance** (operation on wrong forge): Check `tea login ls`, suggest `--login` flag

## Anti-patterns

- Do not create issues or PRs without confirming details with the user first
- Do not guess owner, repo, or assignees — ask or derive from context
- Do not use WebFetch for Codeberg/Gitea URLs
- Do not merge PRs without explicit user approval
- Do not delete repos or branches without confirmation
- Do not auto-install the CLI if missing
