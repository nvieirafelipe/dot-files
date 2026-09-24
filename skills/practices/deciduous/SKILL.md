---
name: deciduous
description: Records architectural decisions as a queryable graph with Deciduous. Use when logging decision rationale, recovering session context, tracking approach pivots, bootstrapping decision history from git, or when the user mentions deciduous, decision graph, or decision tracking.
---

STARTER_CHARACTER = 🌳

## What Deciduous is

A living decision graph for codebases. It captures *why* code
looks the way it does, not just *what* changed. The graph
connects Goals → Options → Decisions → Actions → Outcomes →
Observations → Revisits into a queryable DAG. The local
database is SQLite; the shared copy is either
`.deciduous/graph.json` in git or a graph server.

Written against deciduous 1.0.8. Check the installed version
with `deciduous --version`; `deciduous check-update` lists what
changed since the project's integration files were written.

## Prerequisites

Check if `deciduous` is available:

```bash
which deciduous 2>/dev/null
```

If not found, install it:

```bash
brew install notactuallytreyanastasio/tap/deciduous
# or
cargo install deciduous --locked
```

If neither works, point the user at
https://github.com/notactuallytreyanastasio/deciduous and do
not proceed.

### Graph server: required by `init` and `update` since 1.0.5

`deciduous init` and `deciduous update` stop with exit 1 until
the project points at a shared graph server (PostgreSQL behind
an MCP endpoint), or they are told to skip that step. With a
terminal they ask; without one (an agent's shell) they stop and
name the flags. Ask the user which of these to use. Never pick
one silently, because two of them start or register services:

| Choice | Command |
|--------|---------|
| No server: graph lives in git as `.deciduous/graph.json` | `DECIDUOUS_NO_SERVER=1 deciduous update` |
| Server on this machine (PostgreSQL 17 + server in Docker) | `deciduous remote setup --local` |
| Server someone else runs | `deciduous remote setup --url <url>` |

`remote setup` is interactive (the token is typed hidden), so
have the user run it with `! deciduous remote setup ...`. It
stores the token in `~/.config/deciduous/credentials` (mode
0600), writes `[remote]` to `.deciduous/config.toml`, and
registers the server with Claude Code. Never put a literal
token in `.mcp.json`; use `${DECIDUOUS_MCP_TOKEN}`.

Initialize a project only when `.deciduous/` is missing, with
the same server choice:

```bash
[ -d .deciduous ] || DECIDUOUS_NO_SERVER=1 deciduous init
```

## Node vocabulary

- **Goal**: what needs accomplishing
- **Option**: an approach considered
- **Decision**: the choice made and its rationale
- **Action**: implementation work performed
- **Outcome**: observable result
- **Observation**: insight that attaches anywhere. Needs a
  title *and* `-d "<description>"`; the CLI warns without one
- **Revisit**: pivot point where a prior approach was
  superseded

Statuses accepted by `deciduous status`: `pending`, `active`,
`completed`, `rejected`. There is no `cancelled`, `superseded`
or `abandoned` status; mark a replaced approach with
`deciduous archaeology supersede <id>`.

Edge types for `deciduous link -t`: `leads_to` (default),
`requires`, `chosen`, `rejected`, `blocks`, `enables`,
`took_from`. `took_from` records a borrow: from the node taken
from to the node that used it, usually across branches.

Node references accept a local id, a `change_id` prefix (the
CHANGE column in `deciduous nodes`), or a server id.

## Commands

### `/decision-graph`: bootstrap from git history

Analyzes commit history and builds a retroactive decision
graph. Nodes are backdated to commit timestamps and grounded
in real SHAs. Layer 4 mines PR descriptions and review threads
with `gh`, so it only helps on GitHub-hosted repositories.

Use **once per repo** to bootstrap, or when onboarding to an
unfamiliar codebase.

### `/work`: start a work transaction

Creates a Goal node before implementation begins. Subsequent
Actions and Outcomes are linked through to commit.

Use **every time you start a unit of work**.

### `/decision`: log a choice

Records Options considered, the Decision made, and the
rationale. Also manages edges, attachments, and exports.

Use **at architectural inflection points**: choosing between
approaches, making trade-offs, picking libraries or patterns.

### `/recover`: restore session context

Rebuilds active goals, attached documents, branch state, and
recent commits. Audits for disconnected nodes.

Use **at the start of every new session**, especially after
context compaction.

### `/document`: generate docs from the graph

Traces callers, tests, and dependencies for a file or
directory and generates documentation.

Use **before refactoring or onboarding**.

### `/sync`: team synchronization

Runs `deciduous sync`, which reconciles `.deciduous/graph.json`
with the local database in both directions. Run it after
`git pull` and before `git push`. `deciduous sync --check`
exits 1 when anything is pending, so it works as a pre-push
check. With a `[remote]` configured, use `deciduous remote
pull`, `push` and `status` instead.

### `/serve-ui`: local graph viewer

Runs `deciduous serve` (localhost:3000) with DAG, timeline,
chains, archaeology, and Q&A views.

Use **when you need to visually navigate** the decision
history.

`/sync-graph` and the `docs/` GitHub Pages export were removed
in 1.0.5; `deciduous update` deletes what it wrote there.

## Skills (contextual guides)

### `pulse`

Reads code within a scope and maps it to decisions. Shows
active goals and completion status. Use for **quick health
checks**.

### `narratives`

Maintains `.deciduous/narratives.md`, a living doc of how
subsystems evolved, with pivot tracking. It is the prose
companion to the graph.

### `archaeology`

Turns narratives into graph structure. `deciduous archaeology
pivot` builds a pivot chain in one call; `archaeology
supersede` marks an old approach superseded. Use **when
approaches change**.

## MCP server

`deciduous mcp` serves this project's local database over
stdio. Register it with:

```bash
claude mcp add deciduous -- deciduous mcp
```

Prefer the MCP tools over shelling out when the server is
registered. With a graph server configured, `remote setup`
registers that endpoint instead, and its tools
(`check_activity`, `took_from` on `log_observation`) are the
ones several agents share.

## Integration with plan files

When generating plan files (e.g. `plan.md` for story
workflows or any structured implementation plan), bridge
decisions to the Deciduous graph:

1. After finalizing the `## Decisions` table in the plan,
   run `/decision` for each row to create Decision nodes
   linked to the current Goal
2. Include the Options you considered, not just the choice
   made, so the graph captures the full decision space
3. When deviating from a plan during implementation, create
   a Revisit node linking the original Decision to the new
   approach

The plan stays the readable artifact; the graph is the
queryable one.

## Typical workflows

**New repo, no history:**
`/work` → implement → `/decision` at inflection points →
commit → repeat

**Existing repo, onboarding:**
`/decision-graph` → `/serve-ui` → explore the timeline →
`pulse` on the subsystem you will touch

**Resuming work (new session):**
`/recover` → review active goals → continue

**Pivot happened:**
`archaeology` → creates Revisit chain → `narratives`
updates the evolution doc

**After upgrading the binary:**
`deciduous check-update` → ask the server question above →
`deciduous update` → `deciduous sync` → stage the changes by
path and commit

## Versioning strategy

| Path | Versioned | Why |
|------|-----------|-----|
| `.deciduous/graph.json` | Yes | The shared graph: every node, edge, theme and tag |
| `.deciduous/config.toml`, `.deciduous/.version` | Yes | Project config and integration version |
| `.deciduous/narratives.md` | Yes | Prose companion |
| `.deciduous/deciduous.db` | No | Local cache, rebuilt by `sync` |
| `.deciduous/update-backups/` | No | Copies `update` makes before changing files |
| `.deciduous/remote-log.jsonl` | No | Writes queued for a graph server |

Concurrent edits to `graph.json` always conflict in git; the
`deciduous merge-record` merge driver, registered by `init`,
`update` and `sync`, merges them record by record. A
`graph.json` that does not parse stops a sync instead of being
read as an empty graph.

### Migrating from 0.16 or older

Pre-0.17 projects keep the graph in
`.deciduous/sync/events/*.jsonl` plus `checkpoint.json`. The
first `deciduous sync` imports them into `graph.json` and
deletes them. After it:

```bash
git rm -r --cached .deciduous/sync
git add .deciduous/graph.json .gitignore .gitattributes
```

Drop any `.gitattributes` lines for `.deciduous/sync/`, and
retire `deciduous events ...` commands in Makefiles and docs:
`events` is a deprecated alias for `sync`, and `events
checkpoint` has no replacement because there is no log to
compact.

## Hooks

Upstream removed its logging hooks in 1.0.3: they denied tool
calls until the agent wrote to the graph and could leave a
session unable to do anything. `deciduous update` deletes the
hook scripts it wrote and takes `deciduous log-loop` out of
`.claude/settings.json`; the only hook left is a once-a-day
version check that never blocks. Logging is driven by the
`CLAUDE.md` section and, for MCP clients, the server's
`instructions`.

Do not install pre-edit or post-commit logging hooks. If a
project still has them (`require-action-node.sh`,
`post-commit-reminder.sh` wired in `.claude/settings.json`),
offer to remove both the scripts and their settings entries.

## Graph health maintenance

Status drift is the main health problem: commits land but
nodes stay `pending`, pulse fills with stale entries, and
rationale becomes hard to query. With no hook to prompt it,
link commits as part of the commit step itself.

### After every commit that implements an action

Propose these and run them once the user confirms:

```bash
# 1. New outcome node, linked to the commit
deciduous add outcome "Brief result description" -c 90 --commit HEAD

# 2. Link action -> outcome
deciduous link <action_id> <outcome_id> -r "Result of <action>"

# 3. Flip both nodes to completed once verified
deciduous status <action_id> completed
deciduous status <outcome_id> completed
```

Then commit `.deciduous/graph.json` by path.

### When a decision lands

```bash
deciduous status <chosen_option_id>   completed
deciduous status <rejected_option_id> rejected   # NOT pending
deciduous status <decision_id>        completed
```

`rejected` is the terminal state for unchosen options and for
abandoned work: it keeps the alternatives signal while
clearing the pending bucket.

### Periodic sweeps (weekly, or when pulse looks noisy)

```bash
# 1. List pending action/outcome nodes
deciduous nodes | awk '$3=="pending" && ($2=="action"||$2=="outcome")'

# 2. Flip shipped -> completed, unshipped -> rejected
deciduous status <id> completed
deciduous status <id> rejected

# 3. Auto-associate commits to recent action/outcome nodes
deciduous audit --associate-commits --dry-run
deciduous audit --associate-commits --yes

# 4. Re-run pulse to confirm
deciduous pulse
```

### Health targets

| Metric | Target |
|--------|--------|
| Coverage gaps | 0 (every action has ≥1 outcome) |
| Pending action/outcome | <10 |
| Options ÷ decisions | ≥1.5 (alternatives logged) |
| Confidence unset | 0 (always pass `-c <0-100>`) |
| Observations without `-d` | 0 |

## Anti-patterns

- Logging every small implementation detail as a Decision
  node. Reserve Decision nodes for choices with alternatives.
- Logging the assistant's own process (reading files, running
  a tool) as nodes. The graph records project decisions.
- Skipping Options. The graph is most valuable when it shows
  what you *didn't* pick and why.
- Forgetting `/recover` on session start. Context compaction
  drops decision rationale; the graph keeps it.
- Leaving action/outcome nodes `pending` after the commit
  lands. Flip status at the same time as the commit-link.
- Leaving unchosen options `pending`. Use `rejected`.
- Running `init` or `update` with a server choice the user did
  not make.
- `git add -A` after `update`: it writes backups and may touch
  `.gitignore`, `.gitattributes` and `CLAUDE.md`. Stage by path.

## References

- [commands.md](references/commands.md): detailed command
  reference with flags and examples
- [views.md](references/views.md): description of each
  graph view and when to use it
