# High Priority Improvements

> Changes that fix bugs, remove dead/deprecated code, or resolve conflicts.
> These should be done before any new features.

---

## 1. Fix neo-tree `Util.lsp.on_rename` bug

**File**: `lua/plugins/neotree.lua:52-54`
**Impact**: Runtime error on every file rename/move in neo-tree

The `Util` global comes from LazyVim distribution, which is not installed. Replace with snacks.nvim (already available):

```lua
-- BEFORE (broken)
local function on_move(data)
  Util.lsp.on_rename(data.source, data.destination)
end

-- AFTER (working)
local function on_move(data)
  Snacks.rename.on_rename_file(data.source, data.destination)
end
```

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

## 3. Remove numbers.vim — replace with native autocommand

**File**: `lua/plugins/ui.lua:259-269`
**Impact**: Plugin unmaintained since 2020. Native Neovim can do this.

```lua
-- Remove the plugin spec entirely and add to autocmd.lua:
local numtoggle = vim.api.nvim_create_augroup("NumberToggle", { clear = true })
vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained", "InsertLeave", "WinEnter" }, {
  group = numtoggle,
  callback = function()
    if vim.wo.number and vim.fn.mode() ~= "i" then
      vim.wo.relativenumber = true
    end
  end,
})
vim.api.nvim_create_autocmd({ "BufLeave", "FocusLost", "InsertEnter", "WinLeave" }, {
  group = numtoggle,
  callback = function()
    if vim.wo.number then
      vim.wo.relativenumber = false
    end
  end,
})
```

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

## 5. Resolve nvim-notify vs snacks.notifier conflict

**File**: `lua/plugins/ui.lua`
**Impact**: Both override `vim.notify`. Return type incompatibility can break other plugins.

**Keep nvim-notify (via noice), disable snacks.notifier**
- Set `notifier = { enabled = false }, notify = { enabled = false }` in snacks opts
- Keep noice + nvim-notify as the notification stack

---

## 6. Replace vim-gitgutter with gitsigns.nvim

**File**: `lua/plugins/git.lua:71`
**Impact**: vim-gitgutter is Vimscript. gitsigns.nvim is Lua-native, faster, and adds inline blame + hunk staging.

```lua
-- Replace:
{ "airblade/vim-gitgutter" }

-- With:
{
  "lewis6991/gitsigns.nvim",
  event = "VeryLazy",
  opts = {
    signs = {
      add = { text = "▎" },
      change = { text = "▎" },
      delete = { text = "" },
      topdelete = { text = "" },
      changedelete = { text = "▎" },
    },
  },
}
```

---

## 7. Remove duplicate vim-table-mode entry

**File**: `lua/plugins/editor.lua:256,270`
**Impact**: Code smell. `dhruvasagar/vim-table-mode` is listed twice.

Remove the second entry at line 270.

---

## 8. Resolve lsp-zero + snacks LSP keymap conflict

**Dependency**: Items #2 and #4 above.

If lsp-zero is removed (item #2), this resolves itself. Snacks keymaps become the single source of truth for `gd`, `gr`, `gI`, `gy`, `gD`.

---

## 9. Modernize YankHighlight autocommand

**File**: `lua/autocmd.lua:7-13`
**Impact**: Uses old VimL `vim.cmd` augroup pattern. Should use native Lua API.

```lua
-- BEFORE (VimL in Lua)
vim.cmd([[
  augroup YankHighlight
    autocmd!
    autocmd TextYankPost * silent! lua vim.hi.on_yank()
  augroup end
]])

-- AFTER (native Lua)
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("YankHighlight", { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})
```

Note: `vim.hi.on_yank()` is the old name — it was renamed to `vim.hl.on_yank()` in newer Neovim versions.
