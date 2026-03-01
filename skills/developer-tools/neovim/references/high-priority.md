# High Priority Improvements

> Changes that fix bugs, remove dead/deprecated code, or resolve conflicts.
> These should be done before any new features.

---

## ~~1. Fix neo-tree `Util.lsp.on_rename` bug~~ DONE

Replaced `Util.lsp.on_rename` with `Snacks.rename.on_rename_file` in neotree.lua.

---

## 2. Remove lsp-zero.nvim — use native Neovim LSP

**Files**: `lua/plugins/lspzero.lua`, `lua/plugins/coding.lua`
**Impact**: lsp-zero is officially dead. Neovim 0.11 provides everything natively.

**Migration plan**:
1. Remove `VonHeikemen/lsp-zero.nvim` plugin spec
2. Remove `lsp_zero.extend_cmp()` and `lsp_zero.cmp_action()` from coding.lua
3. Replace `lsp_zero.extend_lspconfig()` and `lsp_zero.on_attach()` with direct `vim.lsp.config()` / `vim.lsp.enable()`
4. Replace `lsp_zero.default_keymaps()` — snacks already provides better LSP keymaps with picker integration
5. Replace `lsp_zero.nvim_lua_ls()` with direct lua_ls config using `vim.lsp.config('lua_ls', { settings = { ... } })`
6. Move mason-lspconfig `ensure_installed` to native format
7. Replace `lsp_zero.default_setup` handler with a simple `function(name) vim.lsp.enable(name) end`
8. Replace LuaSnip supertab actions with native `vim.snippet` API mappings

**Key Neovim 0.11 APIs**:
- `vim.lsp.config('server_name', { ... })` — configure a server
- `vim.lsp.enable('server_name')` — enable a server
- `lsp/` directory convention — place files in `lua/lsp/server_name.lua` for auto-discovery

---

## ~~3. Remove numbers.vim — replace with native autocommand~~ DONE

Removed plugin from ui.lua, added native NumberToggle augroup to autocmd.lua.

---

## 4. Resolve Telescope vs Snacks.picker conflict

**Files**: `lua/plugins/editor.lua`, `lua/plugins/ui.lua`
**Impact**: Two picker systems loaded simultaneously waste memory and may have keymap conflicts.

**Recommendation**: Migrate to snacks.picker (already partially used) and disable telescope.

**Migration steps**:
1. Move telescope keymaps to snacks.picker equivalents:
   - `<C-f>` → `Snacks.picker.buffers()`
   - `<C-j>` → `Snacks.picker.jumps()`
   - `<C-l>` → `Snacks.picker.grep({ hidden = true })`
   - `<C-m>` → `Snacks.picker.lsp_symbols()`
   - `<C-p>` → `Snacks.picker.files({ hidden = true })`
2. Remove telescope plugin spec and telescope-symbols dependency
3. Remove flash-telescope integration (snacks.picker has built-in label-jump)
4. Remove plenary.nvim dependency if no other plugin needs it (check: neo-tree also uses it)

---

## ~~5. Resolve nvim-notify vs snacks.notifier conflict~~ DONE

Disabled snacks.notifier and snacks.notify. Kept noice + nvim-notify as the notification stack. Updated `<leader>n` to use `:Notifications` command.

---

## ~~6. Replace vim-gitgutter with gitsigns.nvim~~ DONE

Replaced vim-gitgutter with gitsigns.nvim (Lua-native, lazy-loaded) in git.lua.

---

## ~~7. Remove duplicate vim-table-mode entry~~ DONE

Removed the second duplicate entry at editor.lua:270.

---

## 8. Resolve lsp-zero + snacks LSP keymap conflict

**Dependency**: Items #2 and #4 above.

If lsp-zero is removed (item #2), this resolves itself. Snacks keymaps become the single source of truth for `gd`, `gr`, `gI`, `gy`, `gD`.

---

## ~~9. Modernize YankHighlight autocommand~~ DONE

Replaced VimL augroup with native Lua API and updated `vim.hi.on_yank()` to `vim.hl.on_yank()`.
