# Development Workflow Reference

This file documents the local-development tooling the skill relies on.
Phases (`plan-phase.md`, `implement-phase.md`, `pr-phase.md`) reference
these commands instead of re-inlining them.

## Project make targets

Every project this skill runs in is expected to expose a `Makefile`
with the following targets. If any are missing, fall back to the
underlying CLI invocation shown in the "Fallback" column and flag
the gap to the user at the end of the session.

| Target | Purpose | Fallback |
|--------|---------|----------|
| `make check` | Full verification gate (compile, format, credo, dialyzer, test, security) | `mix compile --warnings-as-errors && mix format --check-formatted && mix dialyzer && mix credo --strict && mix test` |
| `make run` | Start the application (Phoenix server) | `mix phx.server` |
| `make setup` | Install dependencies and prepare the database | `mix do setup, dialyzer --plt` |

## Deciduous targets

The skill logs goals, options, decisions, actions, and outcomes to
Deciduous when `deciduous` is on PATH and the project has a
`.deciduous/` directory. Prefer the `make` targets over raw
`deciduous` CLI invocations when the project defines them: they are
the canonical project interface and surface the tool to the user in
`make help`. Target names vary by project; check `make help` first.

| Target | Purpose | Fallback |
|--------|---------|----------|
| `make deciduous` | Start the graph viewer on http://localhost:3000 | `deciduous serve --port 3000` |
| `make deciduous-pulse` | Print graph health (goals, gaps) | `deciduous pulse` |
| `make deciduous-pull` | Server mode: refresh the local cache from the graph server | `deciduous remote pull` |
| `make deciduous-status` | Server mode: show drift between the local cache and the server | `deciduous remote status` |
| `make deciduous-check` | Check if integration files need updating | `deciduous check-update` |

A project in git mode (no `[remote]` in `.deciduous/config.toml`)
has no server targets. There, run `deciduous sync` after `git pull`
and before `git push`, and commit `.deciduous/graph.json` by path.

For per-node operations (`deciduous add`, `deciduous link`,
`deciduous status`, `deciduous prompt`), call the CLI directly:
those are per-invocation and too varied to wrap in make targets.

## When the skill invokes which target

### Plan phase

- **Before exploring the codebase:** `make deciduous-pulse` — show
  current graph state so the plan can reference existing goals and
  decisions instead of duplicating them.
- **After drafting the plan:** `deciduous add goal …` then
  `deciduous add option …` / `deciduous add decision …` per
  decision row. Goal → Options → Decision sequence is mandatory.

### Implement phase

- **After each commit:** `deciduous add action "<step>" -c 90 --commit HEAD`,
  then `deciduous link <goal_id> <action_id> -r "<why>"`. Record the
  result with `deciduous add outcome "<result>" -c 90 --commit HEAD`
  and `deciduous link <action_id> <outcome_id> -r "<result of step>"`,
  then mark both `completed` with `deciduous status`.
- **After a deviation:** run
  `deciduous archaeology pivot <old_decision_id> "<what was learned>" "<new approach>"`.
  It creates the observation, revisit and new decision, and marks the
  old approach superseded. Capture the Options considered.

### PR phase

- **After PR creation:** in server mode, `make deciduous-status`
  (or `deciduous remote status`) must report nothing waiting. In git
  mode, run `deciduous sync` and commit `.deciduous/graph.json` by
  path if it changed.

## Tidewave (MCP runtime context)

When the Phoenix server is running, Tidewave exposes runtime tools
(`get_source_location`, `get_docs`, `project_eval`,
`execute_sql_query`, `list_liveview_pages`, `get_logs`) to Claude
Code via MCP. The skill prefers Tidewave over grep-and-read for:

- Finding source locations (`get_source_location` > Glob + Read)
- Looking up docs (`get_docs` > Grep over deps)
- Inspecting running LiveView state (`list_liveview_pages`)
- Running ad-hoc SQL or Elixir against the dev app (`execute_sql_query`, `project_eval`)

Start the server with `make run` before invoking the skill so
Tidewave is available. If the server is not running, the skill falls
back to file-based inspection.

## Canonical project doc

See `guides/development_workflow.md` in the project repo for the
human-readable version of this reference (board columns, labels,
milestones, PR conventions, and Codeberg-specific features).
