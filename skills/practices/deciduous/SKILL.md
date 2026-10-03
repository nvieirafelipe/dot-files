---
name: deciduous
description: Records architectural decisions as a queryable graph with Deciduous. Use when logging decision rationale, recovering session context, tracking approach pivots, bootstrapping decision history from git, setting up or upgrading a deciduous project, or when the user mentions deciduous, decision graph, or decision tracking.
---

STARTER_CHARACTER = 🌳

## What Deciduous is

A living decision graph for codebases. It captures *why* code
looks the way it does, not just *what* changed. Nodes connect
Goals → Options → Decisions → Actions → Outcomes, with
Observations and Revisits attached where they apply.

Since 1.0.5 a project's graph lives on a graph server
(PostgreSQL behind an MCP endpoint), one workspace per
repository, and `.deciduous/deciduous.db` is this machine's
cache of it. A project without a server can still keep its
graph in git as `.deciduous/graph.json`, but upstream documents
that path as the one for tests and CI.

Written against deciduous 1.0.12. Check the installed version
with `deciduous --version`; `deciduous check-update` lists what
changed since the project's integration files were written.
Facts below come from the 1.0.12 `--help` output, the upstream
README and CHANGELOG, or were observed on a real migration on
2026-10-03 (marked "observed").

## Prerequisites

Check that `deciduous` is installed:

```bash
which deciduous 2>/dev/null
```

If it is missing, install it:

```bash
brew install notactuallytreyanastasio/tap/deciduous
# or
cargo install deciduous --locked
```

If neither works, point the user at
https://github.com/notactuallytreyanastasio/deciduous and do
not proceed.

A graph server on this machine also needs PostgreSQL on
localhost:5432 (for example `brew install postgresql@17 &&
brew services start postgresql@17`), unless it runs in Docker
(README, "First-time setup").

## Where the graph lives

`deciduous init` and `deciduous update` stop with exit 1 until
the project points at a server that answers. With a terminal
they ask; in an agent's shell they stop and print the flags.
Ask the user which option to use and never pick one silently:
the first four start a service or containers on this machine.

| Choice | Command | What runs |
|--------|---------|-----------|
| This machine, native | `deciduous remote setup --local` | The server as a launchd (macOS) or systemd user service, against the system PostgreSQL on localhost:5432 as `$USER` |
| This machine, a PostgreSQL you name | `deciduous remote setup --database-url postgres://USER:PASSWORD@HOST:5432/deciduous` | The same service, against that database |
| This machine, all in Docker | `deciduous remote setup --docker-postgres` | PostgreSQL 17 and the server in containers |
| Server in Docker, your PostgreSQL | `deciduous remote setup --docker` | The server in a container, PostgreSQL from row 1 or 2 |
| A server someone else runs | `deciduous remote setup --url <url>` | Nothing locally; it asks for the token |

Sources: `deciduous remote setup --help`, README "First-time
setup". Pass `--port <port>` in scripts; otherwise setup asks
and suggests a free port. The port is fixed after the first
setup (`~/.config/deciduous/server/.env`). When a token must be
typed, have the user run `! deciduous remote setup ...`. The
Docker containers use `restart: unless-stopped`, so they come
back with Docker (observed with `docker inspect`).

What `remote setup` writes (observed):

- The token in `~/.config/deciduous/credentials` (mode 0600).
  The file holds the bare token: never `cat` it into a
  transcript; use `$(cat ...)` inside a command instead.
- `[remote]` with `url` and `workspace` in
  `.deciduous/config.toml`. The workspace defaults to the
  repository root directory name (`deciduous remote init
  --help`).
- A Claude Code MCP entry at **user scope**, with the bearer
  token written literally into `~/.claude.json`. Every project
  on the machine then gets the deciduous tools and the server's
  logging instructions.

To limit the MCP server to chosen projects, run this from each
project, then remove the user-scope entry:

```bash
claude mcp add --scope local --transport http deciduous http://127.0.0.1:<port>/mcp \
  --header "Authorization: Bearer $(cat ~/.config/deciduous/credentials)"
claude mcp remove deciduous --scope user
```

Claude Code files a git worktree under its main repository's
local-scope entry, so one `add` covers every worktree
(observed). Never put a literal token in a tracked `.mcp.json`;
write `${DECIDUOUS_MCP_TOKEN}` there and let Claude Code expand
it from the environment.

### Without a server

```bash
[ -d .deciduous ] || DECIDUOUS_NO_SERVER=1 deciduous init
```

`DECIDUOUS_NO_SERVER=1` skips the server step; upstream
documents it as "for tests and CI" (`src/server.rs`). The graph
then lives in git as `.deciduous/graph.json`. Since 1.0.12 each
write prints a note naming `remote setup`;
`DECIDUOUS_QUIET_LOCAL_ONLY=1` silences it. Initialize only
when `.deciduous/` is missing.

## Worktrees

- A worktree whose config has no `[remote]` sends its writes
  to the main checkout's server (CHANGELOG 1.0.12).
  `deciduous remote status` says so on its `From:` line.
- `deciduous update` in such a worktree updates the files, then
  exits 1 at its final server step (observed). Fix it with
  `deciduous remote init <url> --workspace <workspace>` in the
  worktree and rerun `update`. That edits the tracked
  `config.toml` (URL only, no token).
- One message board serves every worktree of a repository
  (README, "The Message Board").

## Node vocabulary

- **Goal**: what needs accomplishing.
- **Option**: an approach considered.
- **Decision**: the choice made and its rationale.
- **Action**: implementation work performed.
- **Outcome**: observable result.
- **Observation**: an insight that attaches anywhere. Give it
  a title *and* `-d "<description>"`; the CLI warns without
  one.
- **Revisit**: a pivot point where a prior approach was
  superseded. `deciduous archaeology pivot` creates one.

Node types accepted by `deciduous add`: `goal`, `decision`,
`option`, `action`, `outcome`, `observation`, `revisit`. The
help text omits `revisit`; the CLI's own error message lists
it.

Statuses accepted by `deciduous status`: `pending`, `active`,
`completed`, `rejected`, `superseded`, `abandoned`. The help
text lists only the first four; the error for an unknown value
lists all six. `cancelled` is refused, and since 1.0.11 `sync`
skips any record that carries a status the CLI refuses.

Use `completed` for shipped work and chosen options, `rejected`
for options not taken, and `deciduous archaeology supersede
<id>` to mark a replaced approach `superseded`.

Edge types for `deciduous link -t`: `leads_to` (default),
`requires`, `chosen`, `rejected`, `blocks`, `enables`,
`took_from`. `took_from` records a borrow, from the node taken
from to the node that used it, usually across branches. Graphs
made by older versions can hold other types (`depends`,
`supports`, `observation`). The CLI refuses to create them, and
a local cache that follows `graph.json` drops them while the
server keeps them (observed).

A node reference accepts a local id, a `change_id` prefix (the
CHANGE column of `deciduous nodes`), or a server id. Local ids
differ per machine, so use the `change_id` prefix across
machines.

## Commands

`init` and `update` install these slash commands and skills.
[commands.md](references/commands.md) has the details.

| Command | Use it |
|---------|--------|
| `/recover` | At the start of every session: refreshes the cache, lists active goals, reads unanswered board messages |
| `/work` | Before each unit of work: creates the Goal node |
| `/decision` | At choice points: options, decision, rationale, edges, documents |
| `/decision-graph` | Once per repo: builds a backdated graph from git history (layer 4 needs `gh`) |
| `/document` | Before refactoring or onboarding: traces callers, tests and dependencies of a path |
| `/sync` | Remote mode: `remote status` and `remote pull`. Git mode: `deciduous sync` |
| `/serve-ui` | To browse: `deciduous serve` on localhost:3000 ([views.md](references/views.md)) |
| `/build-test` | Template that runs `cargo build --release && cargo test`; replace with the project's own commands |
| `/demo-swarm` | Demonstration: one Opus lead and four Sonnet workers on one graph |

Skills: `pulse` (quick health check of a scope), `narratives`
(maintains `.deciduous/narratives.md`, the prose history of
each subsystem) and `archaeology` (turns narratives into pivot
chains).

`/sync-graph` and the GitHub Pages export were removed in 1.0.5.

## Writing to the graph

With a server, agents write through the MCP tools, and the
server sends its logging instructions on every connection, so
restart Claude Code after setup. `deciduous add` and the other
CLI writes go to the local cache and queue in
`.deciduous/remote-log.jsonl`, which is sent before the command
exits, or on the next write or `deciduous remote push` if the
server is down (README, "First-time setup").

Server tools added in 1.0.10: `ask_graph` (retrieval over the
whole graph), parent suggestions when `add_node` has no
`parent_id`, file and commit links, and `consolidation_report`
(likely duplicates, stale pending actions, parentless nodes).
Multi-agent tools such as `check_activity` and `took_from` live
on the server too.

Without a server, `deciduous mcp` serves the local database
over stdio: `claude mcp add deciduous -- deciduous mcp`.

## Remote mode, day to day

```bash
deciduous remote status        # field-by-field drift; exit 1 when anything differs
deciduous remote pull          # send waiting writes, then refresh the cache
deciduous remote push          # resend writes waiting in .deciduous/remote-log.jsonl
deciduous remote push --seed   # rows only this copy has; never changes a row the server has
deciduous remote watch         # stream the project's writes live
```

**Never run `deciduous remote push --repair`, `--overwrite` or
`--overwrite-server` from a cache that may be incomplete.** On
2026-10-03, `remote pull` wrote a `graph.json` in two checkouts,
their caches followed it, and they dropped 12 edges the server
kept: legacy edge types and one half of a two-node cycle. An
overwrite sends this copy's whole graph over the server's.
UNVERIFIED: whether `--repair` would send those gaps as
deletes; its help says it sends "deletes made here that never
became ops". Run `remote status` first, and repair only from a
checkout it reports as "In sync".

### Legacy edge types and two-node cycles

To bring every cache back in sync, fix those edges on the
server from a checkout whose cache still holds them (observed
on 2026-10-03):

1. Back up the server first. For the Docker install:
   `docker exec deciduous-db-1 sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --format=custom' > pre-fix.dump`.
2. Retype each edge: `deciduous unlink <from> <to>`, then
   `deciduous link <from> <to> -t <type> -r "<rationale> (retyped from legacy edge type <old>)"`.
   Pick the type from what the edge connects, for example
   `depends` to `requires`, and a goal-to-decision `supports`
   to `leads_to`.
3. For a two-node cycle, `unlink` the edge that points the
   wrong way (an action to its goal, say) and keep the other.
4. Run `deciduous remote pull` in every other checkout, twice
   if `remote status` still lists an edge only on the server,
   then confirm each reports "In sync".

### Rotating the server token

For the Docker install (verified on 2026-10-03), the token
lives in two places: `DECIDUOUS_MCP_TOKEN` in
`~/.config/deciduous/server/.env`, which compose reads into the
container's environment, and `~/.config/deciduous/credentials`,
which the CLI reads. The database stores no copy. The Claude
Code MCP entry holds a third copy in its header.

1. Generate a token with `openssl rand -hex 32` into a shell
   variable. Never echo it.
2. Rewrite only the `DECIDUOUS_MCP_TOKEN=` line of the `.env`,
   keeping its single quotes.
3. Recreate the server:
   `docker compose --env-file ~/.config/deciduous/server/.env -f <bundle>/compose.yaml -f <bundle>/compose.local.yaml up -d`,
   where `<bundle>` is
   `~/.config/deciduous/server/bundle-<version>/deciduous-mcp-docker`.
4. Write the token to `~/.config/deciduous/credentials` with
   mode 0600, then re-add the MCP entry with the new header
   (see "Where the graph lives").
5. Check that `curl -H "Authorization: Bearer <old>" http://127.0.0.1:<port>/messages`
   returns 401, the new token returns 200, and `deciduous
   remote status` still answers.

## Message board

Since 1.0.9, agents working at the same time coordinate on a
board instead of a scratch file:

```bash
deciduous board post --as lead -s "port for the api?" -m "@w1 which port?"
deciduous board post --as w1 -s "re port" -m "4000. @lead" --reply-to 1
deciduous board read --unanswered w1
deciduous board show 1
```

`@label` in a subject or body addresses a message. Set
`DECIDUOUS_AGENT_LABEL` in a session's environment and `board
post` uses it for `--as`, and the `board-mentions.sh` hook
shows that label's unanswered messages at session start and as
they arrive. Without the variable the hook prints nothing.
Messages live in the main worktree's SQLite database, or on the
server when the project has a `[remote]`. They are never in
`graph.json` or any export (README, "The Message Board").

## Git mode

Only for projects without a server:

- `deciduous sync` reconciles `.deciduous/graph.json` with the
  local database in both directions. Run it after `git pull`
  and before `git push`. `deciduous sync --check` exits 1 when
  anything is pending, so it works as a pre-push check.
- Since 1.0.11 the local database follows `graph.json` across
  checkout, reset, pull and stash, so a node added on one
  branch stays on that branch.
- Concurrent edits to `graph.json` conflict in git; the
  `deciduous merge-record` merge driver, registered by `init`,
  `update` and `sync`, merges them record by record.
- `sync` skips, and names, records the CLI refuses: unknown
  node types, statuses and edge types, self-loops and two-node
  cycles (CHANGELOG 1.0.11).

## Upgrading the binary

1. `brew upgrade deciduous` (or the same `cargo install`
   line).
2. Back up `.deciduous/`, copying each database with `sqlite3
   .deciduous/deciduous.db ".backup '<file>'"`.
3. `deciduous check-update`.
4. If the project has no server, make the choice in "Where the
   graph lives" with the user.
5. `deciduous update`, or `deciduous update --all <dir>` for
   every project under a directory.
6. Read its output. Since 1.0.12 `update` keeps any command
   file or `CLAUDE.md` section someone edited ("Kept yours")
   and writes the template it would have used to
   `.deciduous/update-templates/<path>` for a diff. A project
   with a `[remote]` gets remote-aware templates and nothing
   appended. Copies of changed files go to
   `.deciduous/update-backups/<time>/`. A second `update` is a
   no-op.
7. Port still-valid customizations onto the new templates by
   hand when the kept files describe an older workflow.
8. Remove old logging hooks (next section).
9. Git mode: `deciduous sync`. Remote mode:
   `deciduous remote status`.
10. Stage by path, never `git add -A`: `update` also writes
    backups and may touch `.gitignore`, `.gitattributes` and
    `CLAUDE.md`.

### Old logging hooks

1.0.3 removed the logging hooks because they denied tool calls
until the agent wrote to the graph and could leave a session
unable to act (CHANGELOG 1.0.3). `update` deletes the hook
scripts it wrote, but keeps edited copies of
`require-action-node.sh` and `post-commit-reminder.sh`, with
their `settings.json` entries, as "yours; left in place"
(observed). Delete both scripts and their `PreToolUse` and
`PostToolUse` entries by hand, and delete an edited
`/sync-graph` command. Avoid `deciduous hooks uninstall`: per
its help it removes all of `.claude/hooks/` and clears
`settings.json`, which takes `board-mentions.sh` and
`version-check.sh` with it.

## Migrating from 0.16 or older

Pre-0.17 projects keep the graph in
`.deciduous/sync/events/*.jsonl` plus `checkpoint.json`. The
first `deciduous sync` imports them into `graph.json` and
deletes them. In 1.0.12 that import ignores `delete_node` and
`delete_edge` ops, so nodes and edges deleted on purpose come
back (observed). Use this order instead:

1. Back up `.deciduous/` in every checkout and worktree.
2. Compare the `change_id`s of the `add_node` events and of
   `checkpoint.json` with the database. The database must hold
   every live node; the only ids missing from it should be the
   ones a `delete_node` event removed.
3. Map statuses the CLI refuses (such as `cancelled`) to
   `rejected`, or `sync` skips those nodes.
4. If a worktree's `deciduous.db` is a symlink to another
   checkout's database, replace it with a real copy.
5. Move `sync/` out of the project, then run `deciduous sync`
   (git mode) or `deciduous remote push --seed` (remote mode).
6. Compare node and edge counts with the database you started
   from.

Afterwards, in git: `git rm -r --cached .deciduous/sync`, drop
the `.gitattributes` lines for `.deciduous/sync/`, and retire
`deciduous events ...` in Makefiles and docs. `events` is a
deprecated alias for `sync`, and `events checkpoint` has no
replacement.

### Merging databases that diverged

Two checkouts can hold different databases, for example when a
worktree ran an earlier `update` on its own. Merge them by
`change_id` before seeding a server:

- A non-pending status beats `pending`. Re-imported records
  carry import-time `updated_at` stamps, so "latest wins"
  picks the wrong side (observed: 527 nodes).
- The earliest `created_at` wins.
- Take metadata from the copy that has more keys.
- Union the edges by (`from_change_id`, `to_change_id`,
  `edge_type`).

Then check the node and edge counts and that no status went
back to `pending`.

## Graph health maintenance

Status drift is the main health problem: commits land but
nodes stay `pending`, pulse fills with stale entries, and
rationale becomes hard to query. No hook prompts for these
steps, so make them part of the commit step.

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

In git mode, then commit `.deciduous/graph.json` by path. In
remote mode there is nothing to commit; `deciduous remote
status` confirms the writes arrived.

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
# 1. List pending action/outcome nodes (columns: ID CHANGE TYPE STATUS TITLE)
deciduous nodes | awk '$4=="pending" && ($3=="action"||$3=="outcome")'

# 2. Flip shipped -> completed, unshipped -> rejected
deciduous status <id> completed
deciduous status <id> rejected

# 3. Associate commits with recent action/outcome nodes
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

## Integration with plan files

When generating plan files (e.g. `plan.md` for story
workflows or any structured implementation plan), bridge
decisions to the Deciduous graph:

1. After finalizing the `## Decisions` table in the plan,
   run `/decision` for each row to create Decision nodes
   linked to the current Goal.
2. Include the Options you considered, not just the choice
   made, so the graph captures the full decision space.
3. When deviating from a plan during implementation, create
   a Revisit (`deciduous archaeology pivot`) linking the
   original Decision to the new approach.

The plan stays the readable artifact; the graph is the
queryable one.

## Typical workflows

**New repo, no history:**
`/work` → implement → `/decision` at inflection points →
commit → outcome and status flips → repeat

**Existing repo, onboarding:**
`/decision-graph` → `/serve-ui` → explore the timeline →
`pulse` on the subsystem you will touch

**Resuming work (new session):**
`/recover` → review active goals and board messages →
continue

**Pivot happened:**
`archaeology` → creates the Revisit chain → `narratives`
updates the evolution doc

**After upgrading the binary:**
follow "Upgrading the binary" above

## Versioning strategy

| Path | Git mode | Remote mode |
|------|----------|-------------|
| `.deciduous/graph.json` | Tracked: the shared graph | Not used. `remote pull` can write a local copy (observed); ignore it |
| `.deciduous/config.toml`, `.deciduous/.version` | Tracked | Tracked; `[remote]` holds the URL, never the token |
| `.deciduous/narratives.md` | Tracked | Tracked |
| `.deciduous/deciduous.db` | Ignored: local, rebuilt by `sync` | Ignored: cache of the server |
| `.deciduous/remote-log.jsonl` | Not used | Ignored: writes queued for the server |
| `.deciduous/update-backups/`, `.deciduous/update-templates/` | Ignored | Ignored |

While `graph.json` cannot be read, edits are refused instead
of being reverted by the next sync, and `sync --check` fails
(CHANGELOG 1.0.8).

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
  lands. Flip status at the same time as the commit link.
- Leaving unchosen options `pending`. Use `rejected`.
- Running `init`, `update` or `remote setup` with a server
  choice the user did not make.
- Printing `~/.config/deciduous/credentials`.
- Running `remote push --repair` or `--overwrite` from a cache
  `remote status` does not report as in sync.
- Letting the legacy event-log import run before checking that
  the database already holds every live node.
- `git add -A` after `update`. Stage by path.

## References

- [commands.md](references/commands.md): command reference
  with flags and examples, checked against 1.0.12 `--help`
- [views.md](references/views.md): the viewer's views and when
  to use each
