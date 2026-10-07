# tmux plugins: architecture

This repository carries two tmux plugins of its own, both bash:

- **tmux-review** opens a review window for a git range: the diff in one pane,
  read in copy-mode, a commit list that follows the reader, a header, and a
  comments pane whose queue is pasted into an agent's pane. See
  [tmux-review/ARCHITECTURE.md](../tmux-review/ARCHITECTURE.md).
- **tmux-agent-status** shows what each Claude Code or Codex session is doing
  in its window's tab, animates it while the agent works, and raises a macOS
  banner when it stops. See
  [tmux-agent-status/ARCHITECTURE.md](../tmux-agent-status/ARCHITECTURE.md).

`tmux/` holds what they share: the check script and the which-key menu. This
page covers what spans both: how they load, where they meet, and how they are
checked.

## In context

```mermaid
flowchart TB
    reader(["Reader"])
    subgraph server["tmux server"]
        direction LR
        whichKey["tmux-which-key<br/>prefix Space menu"]
        review["tmux-review<br/>the review window"]
        status["tmux-agent-status<br/>window options"]
        nova["tmux-nova<br/>the status bar"]
    end
    git["git and delta"]
    agents["Claude Code, Codex<br/>in their own panes"]
    notifier["terminal-notifier<br/>macOS banners"]

    reader -->|"prefix Space"| whichKey
    reader -->|"prefix g, copy-mode keys"| review
    whichKey -->|"review.sh open, key, nav"| review
    review -->|"git log through delta"| git
    review -->|"comments, pasted"| agents
    agents -->|"hooks"| status
    status -->|"@agent_status"| nova
    status -->|"done, waiting"| notifier
    notifier -->|"click focuses the pane"| agents
```

## How the plugins load

```mermaid
flowchart LR
    install["install.sh<br/>ln -sfn into HOME"]
    conf["~/.tmux.conf"]
    tpm["TPM from Homebrew<br/>nova, yank, open,<br/>resurrect, which-key"]
    review["review.tmux<br/>in ~/.tmux/plugins/tmux-review"]
    agent["agent-status.tmux<br/>in ~/.tmux/plugins/tmux-agent-status"]
    wk["tmux/which-key.yaml<br/>as the which-key config"]
    hooks["claude/settings.json<br/>codex/hooks.json"]
    bin["git-review, agent-status<br/>in ~/.local/bin"]

    install --> conf
    install --> wk
    install --> hooks
    install --> bin
    conf -->|"① once per server"| tpm
    conf -->|"② after TPM"| review
    conf -->|"③"| agent
    tpm -->|"which-key builds its menu"| wk
    hooks -->|"agent events run agent-status"| bin
```

- `install.sh` links `.tmux.conf`, both plugin directories under
  `~/.tmux/plugins/`, `bin/git-review` and `bin/agent-status` into
  `~/.local/bin`, the Claude Code and Codex hook files, and, once TPM has
  installed tmux-which-key, the which-key menu. It also copies
  tmux-agent-status's sounds into `~/Library/Sounds`.
- `.tmux.conf` runs TPM once per server, guarded by `@tpm_loaded`. It runs
  `review.tmux` after TPM so tmux-yank cannot overwrite the copy-mode-vi Enter
  binding, then `agent-status.tmux`.
- Neither plugin is a TPM entry; both are symlinks into this repository, next
  to TPM's own checkouts.
- `tmux/rebuild-which-key.sh` rebuilds the which-key menu by hand, because
  `.tmux.conf` turns the plugin's build on load off.

## Where the two plugins meet

```mermaid
flowchart LR
    hooks["Claude Code or Codex hooks"]
    status["agent-status.sh"]
    opts[("window options<br/>@agent_state, @agent_status")]
    nova["status line<br/>@nova-pane format"]
    sessions["load_agent_sessions<br/>list-panes -a"]
    picker["agent picker<br/>second column only"]
    send["send_comments<br/>paste, then select-pane"]
    hook["after-select-pane slot 50<br/>clear-transient"]

    hooks --> status --> opts --> nova
    opts -->|"read for display"| sessions --> picker
    send -->|"fires"| hook --> status
```

- tmux-review reads one tmux-agent-status option, `@agent_state`, to show
  beside each agent in its picker (`load_agent_sessions`). Whether a pane is an
  agent is decided by `pane_current_command` in both plugins, because
  `@agent_state` outlives the agent.
- Sending comments ends with `select-pane` on the agent's pane
  (`send_comments`), which fires tmux-agent-status's `after-select-pane[50]`
  hook and clears a `done` or `waiting` label. The two meet only through tmux
  hooks and options; neither sources or calls the other.
- Both recognise Claude Code by a version number as well as `claude`, because
  that is the process name Claude Code runs under. `.tmux.conf`'s
  `automatic-rename-format` maps it back to `claude` for window names.

## Checks and tests

`tmux/check.sh` is the gate for both plugins:

| Step | What runs |
|---|---|
| shellcheck | `shellcheck -f gcc -x` over both plugins' scripts, `tmux/` and `install.sh` |
| syntax | `bash -n` on each script |
| tests | `tmux-review/run_tests`, then `tmux-agent-status/run_tests` |
| coverage | `tmux-agent-status/run_coverage --min 100`; tmux-review's coverage is reported by its own `run_coverage`, not gated |

Both suites source their scripts, stub `tmux` for their unit sections, and
start throwaway servers with `tmux -L <name> -f /dev/null` for their live ones,
so a run never touches the server it is started from.
