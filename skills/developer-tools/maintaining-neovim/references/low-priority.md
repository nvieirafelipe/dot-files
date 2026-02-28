# Low Priority Improvements

> Nice-to-haves, modernization, and workflow enhancements.
> Do these after all high-priority items are resolved.

---

## Plugin Modernization

### 1. Replace nvim-spectre with grug-far.nvim

**File**: `lua/plugins/editor.lua:1-19`
**Why**: nvim-spectre works but the ecosystem (including LazyVim) has moved to grug-far.nvim for better UX.

```lua
{
  "MagicDuck/grug-far.nvim",
  keys = {
    {
      "<S-f>",
      function() require("grug-far").open() end,
      desc = "Search and Replace",
    },
  },
  opts = {},
}
```

### 2. Replace vim-startify with snacks.nvim dashboard

**File**: `lua/plugins/startify.lua`
**Why**: vim-startify is Vimscript-only. snacks.nvim (already installed) has a modern dashboard.

This removes a plugin and its global `_G.webDevIcons` function. Configure snacks dashboard with the same bookmarks as in startify.
And use the startify themre:

```
{
  formats = {
    key = function(item)
      return { { "[", hl = "special" }, { item.key, hl = "key" }, { "]", hl = "special" } }
    end,
  },
  sections = {
    { section = "terminal", cmd = "fortune -s | cowsay", hl = "header", padding = 1, indent = 8 },
    { title = "MRU", padding = 1 },
    { section = "recent_files", limit = 8, padding = 1 },
    { title = "MRU ", file = vim.fn.fnamemodify(".", ":~"), padding = 1 },
    { section = "recent_files", cwd = true, limit = 8, padding = 1 },
    { title = "Sessions", padding = 1 },
    { section = "projects", padding = 1 },
    { title = "Bookmarks", padding = 1 },
    { section = "keys" },
  },
}
```

### 3. Replace vim-surround with nvim-surround

**File**: `lua/plugins/editor.lua:264`
**Why**: nvim-surround is a Lua-native drop-in with same keybindings (`ys`, `cs`, `ds`) plus treesitter integration and dot-repeat without vim-repeat.

```lua
{
  "kylechui/nvim-surround",
  version = "*",
  event = "VeryLazy",
  opts = {},
}
```

### 4. Replace nvim-cmp with blink.cmp

**Files**: `lua/plugins/coding.lua`, `lua/plugins/ai.lua`
**Why**: blink.cmp is faster (partly Rust), batteries-included (no separate cmp-nvim-lsp, cmp-buffer, cmp-path), and adopted by kickstart.nvim + LazyVim.

**Migration scope**: This is the biggest single change. Requires:
- Replace nvim-cmp + all cmp-* sources with blink.cmp
- Replace copilot-cmp with fang2hou/blink-copilot
- Remove lspkind.nvim (blink.cmp has built-in kind icons)
- Remove LuaSnip (blink.cmp uses native vim.snippet)
- Rewrite completion keymaps

### 5. Consolidate git graph plugins

**File**: `lua/plugins/git.lua`
**Why**: Both gitgraph.nvim and vim-flog visualize git graphs. Pick one.

**Recommendation**: Keep gitgraph.nvim (Lua-native, standalone). Remove vim-flog (depends on fugitive, Vimscript).
**Follow the recommendation!**

---

## New Features to Consider -- Ignore those for now.

### 6. Add session management

No session persistence currently. Options:
- **folke/persistence.nvim** — auto-save/restore sessions (minimal config)
- **rmagatti/auto-session** — more features, workspace-aware

### 7. Add debugging (nvim-dap)

No debugger configured. For your languages:
- `mfussenegger/nvim-dap` — core DAP protocol
- `rcarriga/nvim-dap-ui` — debug UI
- `theHamsta/nvim-dap-virtual-text` — inline values during debug
- Language adapters for Elixir, JavaScript, Python

### 8. Add terminal management

Currently only vim-test opens terminals. Consider:
- **akinsho/toggleterm.nvim** — toggle-able terminal with `<C-\>` or `<leader>t`
- **snacks.nvim terminal** — if you want to stay within the snacks ecosystem

### 9. Add neotest for test running

vim-test works but neotest provides a modern test framework with:
- `nvim-neotest/neotest` + `jfpedroza/neotest-elixir` for ExUnit
- Better UI: test tree, inline diagnostics, output panel
- Can eventually replace vim-test

### 10. Configure custom snippets

LuaSnip is loaded but no custom snippets are defined. Add commonly-used snippets for:
- Elixir: module, defmodule, test, describe, GenServer callbacks
- JavaScript/TypeScript: React components, hooks, test blocks
- General: TODO comments, copyright headers

---

## Configuration Cleanup

### 11. Fix leader/localleader collision

Both `mapleader` and `maplocalleader` are set to `<Space>`. This means filetype-specific mappings (which conventionally use localleader) will collide with global leader mappings.

**Options**:
- Set `maplocalleader = ","` or `maplocalleader = "\\"` if you use filetype-specific mappings
- Keep as-is if you don't use localleader-based mappings (current state)

### 12. Pin plugin versions with lazy-lock.json

No `lazy-lock.json` found. Run `:Lazy lock` to generate one and commit it. This prevents unexpected breakage from plugin updates.

### 13. Improve telescope descriptions

Several telescope keymaps reuse the same description "Get results live as you type":
- `<C-f>` should be "Buffer picker (MRU)"
- `<C-j>` should be "Jump list"
- `<C-l>` should be "Live grep (hidden files)"

This matters for which-key display.

### 14. Add Elixir-specific tooling

Currently only credo linting. Consider:
- Configure elixirls properly with dialyzer, mix format
- Add `heex` formatter to conform.nvim

### 15. Add `<C-m>` keymap concern

`<C-m>` is mapped to LSP document symbols, but `<C-m>` is equivalent to `<CR>` (Enter) in terminals. This could cause unexpected behavior if terminal mapping leaks. Consider using `<leader>m` or another key.

### 16. Explore mini.nvim modules beyond pairs

You load mini.nvim for auto-pairs only. mini.nvim has many useful modules you could adopt:
- **mini.ai** — enhanced text objects (around/inside)
- **mini.comment** — comment toggle (gc)
- **mini.move** — move lines/selections with Alt+arrows
- **mini.splitjoin** — toggle between single-line and multi-line
- **mini.bufremove** — delete buffer without closing window

### 17. Clean up overlength.nvim disabled filetypes

The list includes `"packer"` which is not used (you use lazy.nvim). Remove it for cleanliness.

### 18. Consider Avante.nvim for AI -- Ignore for now

`render-markdown.nvim` is configured with `file_types = { "markdown", "Avante" }` but Avante.nvim is not installed. Either:
- Install yetone/avante.nvim if you want it
- Remove `"Avante"` from the file_types list
