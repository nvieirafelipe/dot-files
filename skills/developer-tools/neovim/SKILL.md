---
name: neovim
description: Maintains and improves Neovim configuration. Use when editing plugins, keymaps, options, LSP setup, or diagnosing neovim issues.
---

STARTER_CHARACTER =

## Config Location

`~/Developer/dot-files/nvim` — versioned in git.

```
nvim/
├── init.lua                 # Entry: lazy.nvim bootstrap → options → keymaps → autocmd → plugins
└── lua/
    ├── options.lua          # Editor settings (2-space indent, relative numbers, transparency)
    ├── keymaps.lua          # Leader = Space, localleader = Space
    ├── autocmd.lua          # Trailing whitespace strip, yank highlight, transparency
    └── plugins/
        ├── ai.lua           # copilot.lua + copilot-cmp + sidekick.nvim (Claude)
        ├── coding.lua       # mini.pairs, vim-test, conform.nvim, nvim-cmp
        ├── colorschemes.lua # tokyonight (moon, active) + dracula (lazy)
        ├── editor.lua       # spectre, flash, illuminate, telescope, trouble, lint, fugitive, surround
        ├── git.lua          # gitgraph, vim-flog, gitgutter, diffview
        ├── lspzero.lua      # lsp-zero v3 + mason + 25 LSP servers
        ├── neotree.lua      # neo-tree v3 file explorer
        ├── startify.lua     # vim-startify start screen
        ├── treesitter.lua   # treesitter + textobjects + context + autotag
        └── ui.lua           # lualine, noice, notify, snacks, indent guides, which-key
```

## Before Making Changes

1. **Read the actual config file(s)** you intend to modify — do not rely solely on cached findings
2. Check [references/findings.md](references/findings.md) for the full config snapshot (plugins, keymaps, options, conflicts)
3. Verify changes against the existing keymap table to avoid collisions

## Config Philosophy

- Lua-native preferred over Vimscript plugins
- Lazy loading via lazy.nvim (VeryLazy, keys, cmd, event patterns)
- Format-on-save via conform.nvim with per-language formatters
- Terminal transparency via ColorScheme autocommand (clears backgrounds)
- folke ecosystem: tokyonight, flash, trouble, noice, snacks, which-key, sidekick
- Sign column uses "number" mode (signs replace line numbers)
- Treesitter for folding, highlighting, indentation, text objects

## Key Architecture Decisions

- **Completion**: nvim-cmp with sources: nvim_lsp → copilot → path → render-markdown → buffer
- **LSP**: mason.nvim manages installation, lsp-zero v3 configures (being deprecated — see backlog)
- **Pickers**: telescope.nvim AND snacks.picker both active (conflict — see backlog)
- **Notifications**: nvim-notify AND snacks.notifier both active (conflict — see backlog)
- **AI**: Copilot via copilot-cmp (inline disabled), Claude via sidekick.nvim
- **Git**: fugitive (commands) + gitgutter (signs) + gitgraph (visualization) + diffview + lazygit via snacks

## Improvement Backlog

Active backlog of prioritized changes. Always read the latest version before working on improvements.

- [references/high-priority.md](references/high-priority.md) — Bugs, deprecated plugins, conflicts (do these first)
- [references/low-priority.md](references/low-priority.md) — Modernization, nice-to-haves

When completing a backlog item, update the corresponding reference file to mark it done or remove it.

## Adding a Plugin

1. Identify the correct plugin file by category (ai, coding, editor, git, ui, etc.)
2. Check for overlap with existing plugins — read [references/findings.md](references/findings.md) "Plugin Overlap/Conflicts" section
3. Use lazy.nvim spec format with appropriate lazy-loading (prefer `keys`, `cmd`, `event`, or `ft`)
4. Prefer Lua-native plugins over Vimscript equivalents
5. Add keymaps within the plugin spec (not in keymaps.lua) unless they're leader-key mappings
6. Verify the keymap doesn't collide with existing bindings

## Modifying Keymaps

Current leader keymaps use `<leader>` (Space) for global commands:
- `<leader>a*` — AI/Sidekick
- `<leader>g*` — Git
- `<leader>s*` — Symbols/search
- `<leader>n/N` — Notifications/news
- `<leader><space>` — Smart find
- `<leader>/` — Grep
- `<leader>?` — Which-key

Ctrl keymaps for frequent actions: `<C-n>` tree, `<C-p>` files, `<C-f>` buffers, `<C-l>` grep, `<C-t>` diagnostics

`g*` prefix for LSP navigation: gd, gD, gr, gI, gy, gai, gao

`]`/`[` for next/prev motions: `]f`/`[f` functions, `]c`/`[c` classes, `]]`/`[[` references

## Modifying LSP

25 servers managed via mason-lspconfig. Special cases:
- `lua_ls` — configured for Neovim API via `nvim_lua_ls()`
- `dartls` — enabled natively via `vim.lsp.enable()`, not mason
- `erlangls` — configured natively via `vim.lsp.config()`

Diagnostic signs use nerd font icons: Error " ", Warn " ", Hint " ", Info " "

## Anti-Patterns

- Adding a plugin without checking for overlap with existing 50+ plugins
- Setting keymaps in keymaps.lua when they belong to a plugin spec
- Using VimL (`vim.cmd`) for things that have native Lua API equivalents
- Installing Vimscript plugins when a Lua-native alternative exists
- Modifying config based on cached findings without reading the live file first
- Adding global functions (`_G.*`) — prefer module-scoped locals
- Referencing LazyVim utilities (like `Util.*`) — this is NOT a LazyVim distro config

## Reference

- [references/findings.md](references/findings.md) — Complete config analysis: all plugins, keymaps, options, autocommands, bugs, deprecations, conflicts, gaps
- [references/high-priority.md](references/high-priority.md) — Bugs and critical improvements
- [references/low-priority.md](references/low-priority.md) — Modernization and nice-to-haves
