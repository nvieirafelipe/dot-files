# Deciduous Command Reference

Checked against the `--help` output of deciduous 1.0.12. Only
flags that exist in 1.0.12 appear here. `deciduous diff` no
longer exists.

## Slash commands

`init` and `update` write these into `.claude/commands/`. A
project with a `[remote]` gets the remote-aware versions.

### /recover

Restores context at session start. It refreshes the cache with
`deciduous remote pull` and checks `deciduous remote status`
(remote mode), lists nodes and pending statuses, audits for
nodes with no incoming edge, reads the board for messages
addressed to the session's label, and checks git state. Run it
at the start of every session and after compaction.

### /work

Starts a work transaction. It creates a Goal node with the
user's request captured verbatim *before* any implementation,
announces the goal id, and asks for an Action before each major
edit and an Outcome after each commit.

Pattern: `/work` → code → commit → outcome recorded.

### /decision

Full graph management: add nodes, link edges, attach
documents, export DOT and PR writeups, and the graph-server and
message-board rules for the project.

### /decision-graph

Builds a graph from commit history, with nodes backdated to
commit timestamps and grounded in real SHAs. Its PR layer uses
`gh pr list`, so that layer only helps on GitHub-hosted
repositories. Run it once per repo, or when onboarding.

### /document

Documents a file or directory by tracing its callers, tests and
dependencies, and writes the result under `docs/<path>.md`. It
also creates a Goal node for the documentation work.

### /sync

Remote mode: `deciduous remote status`, then `deciduous remote
pull`, then `deciduous remote push` (with `--seed` or
`--retry-rejected` when needed). Git mode: `deciduous sync`.

### /serve-ui

Runs `deciduous serve` (localhost:3000). See
[views.md](views.md).

### /build-test

A template that runs `cargo build --release && cargo test`.
Replace its commands with the project's own build and test
commands; `update` keeps an edited copy.

### /demo-swarm

Runs `deciduous demo-swarm`: one Opus lead and four Sonnet
workers build one game on one graph, in iTerm2 or Ghostty
panes. `--preview` plays the walkthrough without starting
anything; `--dry-run` builds the arena and starts no sessions;
`--ask` keeps permission prompts in every pane.

## Writing nodes and edges

### deciduous add

```bash
deciduous add <type> "<title>" -c <0-100> [flags]
```

Types: `goal`, `decision`, `option`, `action`, `outcome`,
`observation`, `revisit`. Flags:

- `-d, --description <text>`: required in practice for
  observations; the CLI warns without it.
- `-c, --confidence <0-100>`: always pass it.
- `--commit <rev>`: `HEAD`, a branch, a tag, a hash or a
  prefix. Stored as the full hash; a rev git cannot resolve is
  refused.
- `-p, --prompt <text>` or `--prompt-stdin`: the user prompt
  that triggered the node, verbatim.
- `-f, --files <a,b>`: files associated with the node.
- `-b, --branch <branch>` or `--no-branch`: override branch
  detection.
- `--date <date>`: backdate (RFC3339, `YYYY-MM-DD` or
  `YYYY-MM-DD HH:MM:SS`).

### deciduous link

```bash
deciduous link <from> <to> -r "<rationale>" [-t <type>]
```

Edge types: `leads_to` (default), `requires`, `chosen`,
`rejected`, `blocks`, `enables`, `took_from`. Any other type is
refused with an error that lists these.

### deciduous unlink and delete

```bash
deciduous unlink <from> <to> [-t <type>]   # -t needed when two nodes share several edges
deciduous delete <id> --dry-run            # preview; drop --dry-run to delete node and edges
```

### deciduous status

```bash
deciduous status <id> completed    # shipped, chosen, verified
deciduous status <id> rejected     # option not taken, or work abandoned
deciduous status <id> active       # current truth, still in use
deciduous status <id> pending      # rare: only to reopen
```

The CLI also accepts `superseded` and `abandoned` (its error
message lists all six values; the help lists four). Prefer
`deciduous archaeology supersede <id>` for `superseded`.
`cancelled` is refused.

### deciduous prompt

```bash
deciduous prompt <id> "<verbatim prompt>"   # omit the text to read stdin
```

## Reading the graph

```bash
deciduous nodes [-b <branch>] [-t <type>] [--theme <name>]   # columns: ID CHANGE TYPE STATUS TITLE
deciduous edges
deciduous show <id> [--json]
deciduous graph                                              # full graph as JSON
deciduous commands [-l <n>]                                  # recent command log
deciduous pulse [-b <branch>] [-r <n>] [--summary] [--json]
```

`pulse` shows active goals, coverage gaps and health. Filter
`nodes` by field position, for example
`awk '$4=="pending" && ($3=="action"||$3=="outcome")'`.

## Exports

```bash
deciduous dot [-o <file>] [-r <root_ids>] [-n <ids_or_ranges>] [--png] [--auto] [-t <title>] [--rankdir LR]
deciduous writeup [-t <title>] [-r <root_ids>] [-n <ids>] [-o <file>] [--png <file>] [--auto] [--no-dot] [--no-test-plan]
deciduous backup [-o <file>]
```

`dot --png` needs graphviz. `dot --auto` writes a
branch-specific file under `docs/`, and `writeup --auto` looks
for `docs/decision-graph-<branch>.png` to embed.

## History and pivots

### deciduous narratives

```bash
deciduous narratives init     # seed .deciduous/narratives.md with active goal titles
deciduous narratives show
deciduous narratives pivots   # every revisit node with its full chain
```

### deciduous archaeology

```bash
deciduous archaeology pivot <from_id> "<observation>" "<new approach>" -c 80 -r "<why the old one failed>" [--dry-run]
deciduous archaeology supersede <id> [--cascade] [--dry-run]
deciduous archaeology timeline
```

`pivot` builds the observation, revisit and new-decision chain
in one call. `supersede` marks a node `superseded`; `--cascade`
also marks its descendants.

## Maintenance

### deciduous audit

```bash
deciduous audit --associate-commits --dry-run   # preview
deciduous audit --associate-commits --yes       # apply
deciduous audit --associate-commits --min-score 60
```

Associates commits with nodes by matching titles to commit
messages (default minimum score 50). Run it after a status
sweep.

### Sweep loop

```bash
deciduous pulse                                                         # diagnose
deciduous nodes | awk '$4=="pending" && ($3=="action"||$3=="outcome")'  # list stale
deciduous status <id> completed                                         # sweep
deciduous audit --associate-commits --yes                               # backlink
deciduous pulse                                                         # verify
```

### Documents and themes

```bash
deciduous doc attach <node> <file> [-d "<text>" | --ai-describe]
deciduous doc list | show | describe | detach | open | gc
deciduous themes create | list | delete
deciduous tag add | remove | list | suggest | confirm
```

Documents live in `.deciduous/documents/` with content-hash
names. `doc detach` soft-deletes; `doc gc` removes orphaned
files. Themes and tags are not sent to a graph server, so
`remote status` does not compare them.

## Graph server

```bash
deciduous remote setup [--local | --database-url <url> | --docker-postgres | --docker | --url <url>] [--port <port>]
deciduous remote init <url> [--workspace <name>]   # point this project (or worktree) at a server
deciduous remote login [--url <url>]               # store a token outside every repository (0600)
deciduous remote logout
deciduous remote status                            # drift, field by field; exit 1 when anything differs
deciduous remote pull                              # send waiting writes, then refresh the cache
deciduous remote push                              # resend writes waiting in .deciduous/remote-log.jsonl
deciduous remote push --seed                       # rows the server lacks that no op covers; never changes server rows
deciduous remote push --retry-rejected | --drop-rejected | --drop <op_id>
deciduous remote adopt --url <url> [root] [-n]     # configure many repositories at once
deciduous remote watch [--types outcome,observation] [--branch <b>] [--edges] [--json]
```

`push` also has `--overwrite` (replace the server's copy of
every row with this copy's) and `--repair` (send fields and
deletes this copy changed but never logged). Do not run either
from a cache that `remote status` does not report as in sync;
see the warning in [SKILL.md](../SKILL.md).

The token is read from `DECIDUOUS_MCP_TOKEN` or the stored
credentials, never from `config.toml`.

## Message board

```bash
deciduous board post --as <label> -s "<subject>" [-m "<body>"] [--reply-to <id>] [--branch <b>] [--json]
deciduous board read [--since <id>] [--from <label>] [--to <label>] [--unanswered <label>] [-q <text>] [--limit <n>] [--json]
deciduous board show <id> [--json]
```

`--as` defaults to `$DECIDUOUS_AGENT_LABEL`. The body is read
from stdin when `-m` is omitted. `read` returns at most 200
messages per call (default 50).

## Project setup and upgrades

```bash
deciduous init [--claude | --opencode | --windsurf | --both] [--no-auto-update]
deciduous update [--all <dir>]
deciduous check-update
deciduous sync [--check]          # git mode only
deciduous integration             # which hooks, commands and skills are installed
deciduous hooks status
deciduous mcp                     # local database over stdio
deciduous serve [-p <port>]       # viewer, default port 3000
```

`init` and `update` need a server choice; see "Where the graph
lives" in [SKILL.md](../SKILL.md). `update` keeps edited files
and writes its templates to `.deciduous/update-templates/`.
`deciduous hooks uninstall` removes all of `.claude/hooks/` and
clears `settings.json`; remove old hooks by hand instead.
`deciduous events ...` is a deprecated alias for `sync`, kept
so old scripts run.
