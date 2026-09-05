# Neovim Configuration Findings

> Complete analysis of `~/Developer/dot-files/nvim`
> Generated: 2026-02-28

## Config Structure

```
nvim/
├── init.lua                    # Entry point: bootstraps lazy.nvim, loads options → keymaps → autocmd → plugins
└── lua/
    ├── options.lua             # Editor options and settings
    ├── keymaps.lua             # Core keybindings (leader = Space)
    ├── autocmd.lua             # Autocommands (whitespace, yank highlight, transparency)
    └── plugins/
        ├── ai.lua              # Copilot + Sidekick (Claude)
        ├── coding.lua          # Formatting, testing, completion (conform, vim-test, nvim-cmp)
        ├── colorschemes.lua    # Tokyo Night (moon) + Dracula (lazy)
        ├── editor.lua          # Search, navigation, diagnostics (telescope, flash, trouble, spectre, lint)
        ├── git.lua             # Git tools (gitgraph, vim-flog, gitgutter, diffview)
        ├── lspzero.lua         # LSP setup via lsp-zero v3 + Mason
        ├── neotree.lua         # File explorer (neo-tree v3)
        ├── startify.lua        # Startup screen (vim-startify)
        ├── treesitter.lua      # Syntax parsing + text objects + context
        └── ui.lua              # Status line, notifications, indent guides, icons
```

## Core Settings (options.lua)

| Setting | Value | Notes |
|---------|-------|-------|
| Shell | `/bin/zsh` | |
| Font | FiraMono Nerd Font Propo | GUI only |
| Indentation | 2 spaces, expandtab, smartindent | |
| Line numbers | relative + absolute | |
| Wrap | disabled | |
| Cursor | cursorline + cursorcolumn | |
| Splits | right + below | |
| Search | hlsearch, ignorecase + smartcase | |
| Clipboard | unnamedplus (system) | |
| Mouse | enabled (all modes) | |
| Undo | persistent (undofile) | |
| Backup/swap | disabled | |
| Update time | 250ms | |
| Sign column | "number" (signs replace line numbers) | |
| Fold | treesitter expr, foldlevelstart=666 (all open) | |
| Netrw | disabled (replaced by neo-tree) | |
| Completion | menuone,noinsert,noselect | |
| Status line | laststatus=3 (global) | |
| Colors | termguicolors enabled | |

## Leader Key

- Leader: `<Space>`
- Local leader: `<Space>` (same — potential issue if using filetype-specific mappings)

## Autocommands (autocmd.lua)

1. **BufWritePre `*`**: Strip trailing whitespace via `%s/\s\+$//e`
2. **TextYankPost**: Highlight yanked text via `vim.hi.on_yank()` (uses old VimL augroup)
3. **ColorScheme `*`**: Clears background from 20+ highlight groups for terminal transparency
   - Normal, NormalNC, NormalFloat
   - LineNr, SignColumn
   - NeoTreeNormal, NeoTreeNormalNC
   - NoiceCmdline
   - Notify*Body, Notify*Border (ERROR, WARN, INFO, DEBUG, TRACE)
   - StatusLine, StatusLineNC
   - NonText, VertSplit, TabLineFill

## All Plugins (50+)

### AI (ai.lua)

| Plugin | Purpose | Load |
|--------|---------|------|
| zbirenbaum/copilot.lua | GitHub Copilot | VeryLazy, suggestion+panel disabled (for cmp) |
| zbirenbaum/copilot-cmp | Copilot → nvim-cmp bridge | Tab cycles suggestions |
| folke/sidekick.nvim | Claude AI integration | VeryLazy, NES disabled |

**Sidekick keymaps**: `<leader>aa` toggle CLI, `<leader>as` select, `<leader>at` send file, `<leader>av` send visual, `<leader>ap` prompt, `<c-.>` focus switch, `<leader>ac` toggle Claude

### Coding (coding.lua)

| Plugin | Purpose | Load |
|--------|---------|------|
| echasnovski/mini.nvim | Auto-pairs (mini.pairs only) | VeryLazy |
| vim-test/vim-test | Test runner | Keys: `<M-t>` nearest, `<M-S-t>` file |
| stevearc/conform.nvim | Format-on-save (1000ms timeout) | BufWritePre |
| hrsh7th/nvim-cmp | Autocompletion engine | InsertEnter, LspAttach |

**Conform formatters**:
- bash → shfmt
- dart → dart_format
- elixir → mix
- javascript → prettierd/prettier (stop_after_first)
- json → jq
- lua → stylua
- python → isort + black
- ruby → rubyfmt
- rust → rustfmt (LSP fallback)
- sql → sleek
- terraform → terraform_fmt

**nvim-cmp sources** (priority order): nvim_lsp → copilot → path → render-markdown → buffer

**nvim-cmp keymaps**: `<CR>` confirm (no auto-select), `<Tab>/<S-Tab>` supertab (cmp + luasnip), `<C-Space>` manual trigger, `<C-j>/<C-k>` scroll docs

### Colorschemes (colorschemes.lua)

| Plugin | Status |
|--------|--------|
| dracula/vim | Lazy loaded (not active) |
| folke/tokyonight.nvim | Active, style="moon", priority=1000 |

### Editor (editor.lua)

| Plugin | Purpose | Key |
|--------|---------|-----|
| nvim-pack/nvim-spectre | Project search/replace | `<S-f>` |
| folke/flash.nvim | Label-based jumping | `s`/`S`/`r`/`R`/`<c-s>` |
| RRethy/vim-illuminate | Highlight word references | `]]`/`[[` for next/prev |
| nvim-telescope/telescope.nvim | Fuzzy finder | `<C-f>`/`<C-j>`/`<C-l>`/`<C-m>`/`<C-p>` |
| folke/trouble.nvim | Diagnostic viewer | `<C-t>` |
| mfussenegger/nvim-lint | Linting (elixir: credo) | Auto on write/read/insert-leave |
| dhruvasagar/vim-table-mode | Markdown tables | (duplicated in config!) |
| tpope/vim-fugitive | Git wrapper | |
| tpope/vim-rhubarb | GitHub integration | |
| tpope/vim-surround | Surround manipulation | |
| tpope/vim-projectionist | Project navigation | Comment: "Missing neo-tree templates integration" |

**Telescope keymaps**:
- `<C-f>` — buffers (MRU, ignore current)
- `<C-j>` — jump list
- `<C-l>` — live grep (hidden, no .git)
- `<C-m>` — LSP document symbols
- `<C-p>` — find files (rg, hidden, no .git)
- Flash integration: `s` in normal, `<c-s>` in insert within telescope

### Git (git.lua)

| Plugin | Purpose | Key |
|--------|---------|-----|
| isakbm/gitgraph.nvim | Git graph visualization | `<leader>gl` (5000 commits) |
| rbong/vim-flog | Git log viewer | `:Flog`, `:Flogsplit`, `:Floggit` |
| airblade/vim-gitgutter | Git diff in sign column | |
| sindrets/diffview.nvim | Diff viewer | |

**gitgraph hooks**: Opens DiffView on commit selection

### LSP (lspzero.lua)

| Plugin | Purpose |
|--------|---------|
| VonHeikemen/lsp-zero.nvim v3.x | LSP config framework |
| williamboman/mason.nvim | LSP/tool installer |
| onsails/lspkind.nvim | Completion menu icons |
| neovim/nvim-lspconfig | LSP server configs |

**Mason-managed LSP servers (25)**:
autotools_ls, bashls, copilot-language-server, cssls, diagnosticls, docker_compose_language_service, dockerls, elixirls, erlangls, eslint, grammarly, html, jqls, jsonls, lua_ls, marksman, ruby_lsp, spectral, sqlls, tailwindcss, taplo, templ, terraformls, tflint, ts_ls, vimls, yamlls

**Special configs**:
- lua_ls: configured with nvim_lua_ls() for Neovim API
- dartls: enabled via vim.lsp.enable() (native, not mason)
- erlangls: configured via vim.lsp.config() (native)
- Diagnostic signs: Error " ", Warn " ", Hint " ", Info " "

### File Explorer (neotree.lua)

| Plugin | Purpose |
|--------|---------|
| nvim-neo-tree/neo-tree.nvim v3 | File explorer |
| Dependencies | nui.nvim, plenary.nvim, nvim-web-devicons, nvim-window-picker |

**Config**: `<C-n>` toggle, follow_current_file, libuv watcher, filesystem+buffers+git_status+document_symbols
**Window mappings**: `v` vsplit, `s` split, `<space>` disabled
**Event handlers**: FILE_MOVED and FILE_RENAMED trigger LSP rename via `Util.lsp.on_rename`
**Auto**: lazygit TermClose refreshes neo-tree git_status

### Startup (startify.lua)

| Plugin | Purpose |
|--------|---------|
| mhinz/vim-startify | Start screen |

**Bookmarks**: `n` = nvim config, `p` = work project (from `$WORK_PROJECT_DIR`)
**Features**: VCS root change, web-devicons integration, global `_G.webDevIcons()` function

### Treesitter (treesitter.lua)

| Plugin | Purpose |
|--------|---------|
| nvim-treesitter/nvim-treesitter | Syntax parser |
| nvim-treesitter/nvim-treesitter-textobjects | Text object navigation |
| nvim-treesitter/nvim-treesitter-context | Show function context (3 lines max) |
| windwp/nvim-ts-autotag | Auto-close HTML/JSX tags |

**Ensured languages (28+)**: bash, comment, csv, css, diff, dockerfile, eex, elixir, erlang, git_config, git_rebase, gitattributes, gitcommit, gitignore, gpg, heex, html, http, javascript, jq, jsdoc, json, jsonc, lua, luadoc, luap, make, markdown, markdown_inline, mermaid, python, query, regex, sql, toml, tsx, typescript, vim, vimdoc, xml, yaml

**Text object moves**: `]f`/`[f` function, `]c`/`[c` class (with diff mode fallback to vim defaults)
**Dedup logic**: Ensures no duplicate entries in ensure_installed

### UI (ui.lua)

| Plugin | Purpose |
|--------|---------|
| nvim-tree/nvim-web-devicons | File type icons |
| s1n7ax/nvim-window-picker v2 | Window selection |
| folke/noice.nvim | Command-line UI |
| rcarriga/nvim-notify | Notifications (bg=#000, fps=42, compact, 3s timeout) |
| AndreM222/copilot-lualine | Copilot status in statusline |
| nvim-lualine/lualine.nvim | Status line |
| lukas-reineke/indent-blankline.nvim | Indent guides (scope enabled!) |
| echasnovski/mini.indentscope | Visual indent scope (▏ symbol) |
| myusuf3/numbers.vim | Smart line number toggling |
| lcheylus/overlength.nvim | Highlight lines > 98 chars |
| HiPhish/rainbow-delimiters.nvim | Colored bracket pairs |
| MeanderingProgrammer/render-markdown.nvim | Markdown rendering |
| folke/snacks.nvim | Utility library (notifier+notify+picker enabled) |
| folke/which-key.nvim | Keymap documentation |

**Lualine sections**: mode | branch+diff+diagnostics | filename(path=1) | noice status+copilot | fileformat+filetype | progress+location

**Snacks LSP keymaps**: gd, gD, gr, gI, gy, gai, gao, `<leader>ss`, `<leader>sS`
**Snacks utility keymaps**: `<leader>gg` lazygit, `<leader><space>` smart find, `<leader>/` grep, `<leader>n` notifications, `<leader>N` neovim news
**Which-key**: `<leader>?` show buffer keymaps

**Noice config**: Bottom search, LSP hover+signature, custom cmdline popup (row 5, 120w), suppresses common messages

## Complete Keymap Reference

### Leader Keymaps

| Key | Mode | Action | Source |
|-----|------|--------|--------|
| `<leader>r` | n | Reload config (`:so %`) | keymaps.lua |
| `<leader>aa` | n | Sidekick toggle CLI | ai.lua |
| `<leader>as` | n | Select CLI | ai.lua |
| `<leader>at` | n,x | Send this to CLI | ai.lua |
| `<leader>av` | x | Send visual selection | ai.lua |
| `<leader>ap` | n,x | Sidekick prompt | ai.lua |
| `<leader>ac` | n | Toggle Claude | ai.lua |
| `<leader>gl` | n | Git graph (5000 commits) | git.lua |
| `<leader>gg` | n | Lazygit | ui.lua (snacks) |
| `<leader><space>` | n | Smart find files | ui.lua (snacks) |
| `<leader>/` | n | Grep | ui.lua (snacks) |
| `<leader>n` | n | Notification history | ui.lua (snacks) |
| `<leader>N` | n | Neovim news | ui.lua (snacks) |
| `<leader>ss` | n | LSP symbols | ui.lua (snacks) |
| `<leader>sS` | n | Workspace symbols | ui.lua (snacks) |
| `<leader>?` | n | Which-key buffer keymaps | ui.lua |

### Ctrl Keymaps

| Key | Mode | Action | Source |
|-----|------|--------|--------|
| `<C-f>` | n | Buffer picker (MRU) | editor.lua |
| `<C-j>` | n | Jump list | editor.lua |
| `<C-l>` | n | Live grep | editor.lua |
| `<C-m>` | n | LSP document symbols | editor.lua |
| `<C-p>` | n | Find files | editor.lua |
| `<C-n>` | n | Toggle neo-tree | neotree.lua |
| `<C-t>` | n | Toggle diagnostics | editor.lua |
| `<C-Space>` | i | Trigger completion | coding.lua |
| `<C-j>` | i | Scroll docs down | coding.lua |
| `<C-k>` | i | Scroll docs up | coding.lua |
| `<c-d>` | n,i,s | Scroll LSP docs down | ui.lua (noice) |
| `<c-u>` | n,i,s | Scroll LSP docs up | ui.lua (noice) |
| `<c-.>` | n,x,i,t | Sidekick focus switch | ai.lua |
| `<c-s>` | c | Toggle flash search | editor.lua |

### Motion/Action Keymaps

| Key | Mode | Action | Source |
|-----|------|--------|--------|
| `s` | n,x,o | Flash jump | editor.lua |
| `S` | n,x,o | Flash treesitter | editor.lua |
| `r` | o | Remote flash | editor.lua |
| `R` | o,x | Treesitter search | editor.lua |
| `]]` | n | Next reference | editor.lua |
| `[[` | n | Prev reference | editor.lua |
| `]f`/`[f` | n | Next/prev function start | treesitter.lua |
| `]F`/`[F` | n | Next/prev function end | treesitter.lua |
| `]c`/`[c` | n | Next/prev class start | treesitter.lua |
| `]C`/`[C` | n | Next/prev class end | treesitter.lua |

### LSP Keymaps (via snacks)

| Key | Action |
|-----|--------|
| `gd` | Goto definition |
| `gD` | Goto declaration |
| `gr` | References |
| `gI` | Goto implementation |
| `gy` | Goto type definition |
| `gai` | Incoming calls |
| `gao` | Outgoing calls |

### Other

| Key | Mode | Action | Source |
|-----|------|--------|--------|
| `<S-f>` | n | Toggle Spectre | editor.lua |
| `<M-t>` | n | Test nearest | coding.lua |
| `<M-S-t>` | n | Test file | coding.lua |
| `<CR>` | i | Confirm completion | coding.lua |
| `<Tab>` | i | Next completion/snippet + copilot | coding.lua + ai.lua |
| `<S-Tab>` | i | Prev completion/snippet | coding.lua |

## Critical Bugs Found

### 1. `Util.lsp.on_rename` undefined (neotree.lua:53)

```lua
local function on_move(data)
  Util.lsp.on_rename(data.source, data.destination)
end
```

`Util` is a LazyVim global that does NOT exist in standalone configs. This causes a **runtime error every time you rename/move a file in neo-tree**.

**Fix**: Replace with `Snacks.rename.on_rename_file(data.source, data.destination)` (snacks.nvim is already installed).

### 2. Duplicate plugin: vim-table-mode (editor.lua:256,270)

`dhruvasagar/vim-table-mode` is listed twice in editor.lua. Lazy.nvim may handle this gracefully, but it's a code smell.

### 3. indent-blankline scope conflict (ui.lua)

Both `indent-blankline.nvim` (with `scope.enabled = true`) and `mini.indentscope` are active. The standard pattern (used by LazyVim) is to **disable ibl's scope** and let mini.indentscope handle scope highlighting. Currently both draw scope indicators, causing visual overlap.

## Plugin Deprecation Status

| Plugin | Status | Replacement | Urgency |
|--------|--------|-------------|---------|
| VonHeikemen/lsp-zero.nvim v3 | **Dead** (author confirmed) | Native Neovim 0.11 LSP (`vim.lsp.config`) | **Critical** |
| myusuf3/numbers.vim | **Unmaintained** (since 2020) | Native autocommands or nvim-numbertoggle | **High** |
| nvim-pack/nvim-spectre | Ecosystem moving on | MagicDuck/grug-far.nvim | Medium |
| mhinz/vim-startify | Stale, Vimscript | snacks.nvim dashboard | Medium |
| airblade/vim-gitgutter | Maintained, Vimscript | lewis6991/gitsigns.nvim | Medium |
| hrsh7th/nvim-cmp | Maintained but slow dev | saghen/blink.cmp | Medium |
| tpope/vim-surround | Maintained, Vimscript | kylechui/nvim-surround | Low |
| zbirenbaum/copilot-cmp | Maintained | blink-copilot (if using blink.cmp) | Low |
| tpope/vim-fugitive | **Actively maintained** | No clear replacement | None |
| echasnovski/mini.pairs | Actively maintained | nvim-autopairs (if quirks) | Low |

## Plugin Overlap/Conflicts

### Telescope vs Snacks.picker (HIGH)

Both are active. Snacks.picker can fully replace telescope for most use cases. Having both wastes startup time and can cause keymap races.

### nvim-notify vs snacks.notifier (HIGH)

Both override `vim.notify`. Whichever loads last wins. Dead code for the other. They return different types from `vim.notify()` which can break other plugins.

### lsp-zero + snacks LSP keymaps (HIGH)

lsp-zero's `default_keymaps()` and snacks.nvim both map `gd`, `gr`, `gI`, `gy`, etc. On Neovim 0.11+, the editor ALSO maps some of these natively. Three-way conflict.

### Git plugin redundancy (MEDIUM)

gitgraph.nvim and vim-flog both visualize git graphs. vim-gitgutter (Vimscript) could be replaced by gitsigns.nvim (Lua, faster, more features).

### copilot-cmp Tab mapping (MEDIUM)

The Tab mapping in ai.lua's copilot-cmp config references `cmp` from `copilot_cmp` — verify the `has_words_before` guard is working correctly with the actual nvim-cmp Tab supertab from coding.lua.

## Missing Features / Gaps

1. **No lazy-lock.json** — plugin versions are not pinned
2. **No session management** — no persistence of open buffers/layout
3. **No debugging** (DAP) — no nvim-dap setup
4. **No terminal management** — only vim-test terminal, no toggleterm/FTerm
5. **No snippet library** — LuaSnip loaded but no custom snippets configured
6. **No Elixir-specific features** — only credo lint, no ExUnit integration via neotest
7. **vim-projectionist** has comment "Missing neo-tree templates integration" — incomplete setup
8. **No TypeScript-specific tools** — no typescript-tools.nvim or ts-error-translator
9. **No Rust-specific tools** — rustfmt only, no rustaceanvim
10. **`<leader>r` reloads current file** — fragile, could execute arbitrary code if run on wrong file
