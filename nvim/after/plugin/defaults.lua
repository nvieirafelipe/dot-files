vim.opt.shell = "/bin/zsh"

-- Colorscheme
vim.cmd [[colorscheme tokyonight]]

vim.opt.guifont = "Source Code Pro for Powerline"

-- Set syntax highlighting on according to the current value of the filetype.
vim.opt.syntax = "on"

-- Enable plugin and indent files for specific file types.
vim.cmd("filetype plugin indent on")

-- Transparency
vim.api.nvim_set_hl(0, 'ErrorMsg', { ctermbg = "none" })
vim.api.nvim_set_hl(0, 'LineNr', { ctermbg = "none" })
vim.api.nvim_set_hl(0, 'NonText', { ctermbg = "none" })
vim.api.nvim_set_hl(0, 'Normal', { ctermbg = "none" })
vim.api.nvim_set_hl(0, 'NormalNC', { ctermbg = "none" })
vim.api.nvim_set_hl(0, 'Statement', { ctermbg = "none" })
vim.api.nvim_set_hl(0, 'TabLineFill', { ctermbg = "none" })
vim.api.nvim_set_hl(0, 'Title', { ctermbg = "none" })
vim.api.nvim_set_hl(0, 'Todo', { ctermbg = "none" })
vim.api.nvim_set_hl(0, 'Underlined', { ctermbg = "none" })

vim.opt.expandtab = true
vim.opt.tabstop = 3
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 2
vim.opt.list = true
vim.api.nvim_create_autocmd(
  { "BufWritePre" },
  {
    pattern = { "*" },
    command = [[%s/\s\+$//e]],
  }
)

vim.opt.wrap = false
vim.opt.cursorline = true
vim.opt.cursorcolumn = true

vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.laststatus = 2
vim.opt.number = true
vim.opt.relativenumber = true -- Make relative number default

vim.opt.backup = false
vim.opt.swapfile = false
vim.opt.clipboard = "unnamedplus" -- Access system clipboard

-- Netrw
vim.g.netrw_liststyle = 3
vim.g.netrw_list_hide = ".pyc,.DS_Store"

vim.opt.termguicolors = true  -- Enable colors in terminal
vim.opt.hlsearch = true       -- Set highlight on search
vim.opt.mouse = "a"           -- Enable mouse mode
vim.opt.breakindent = true    -- Enable break indent
vim.opt.undofile = true       -- Save undo history
vim.opt.ignorecase = true     -- Case insensitive searching unless /C or capital in search
vim.opt.smartcase = true      -- Smart case
vim.opt.updatetime = 250      -- Decrease update time
vim.opt.signcolumn = "number" -- Display signs in the 'number' column. If the number
-- column is not present, then behaves like "auto".

-- Highlight on yank
vim.cmd [[
  augroup YankHighlight
    autocmd!
    autocmd TextYankPost * silent! lua vim.highlight.on_yank()
  augroup end
]]


-- Fold method
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
vim.opt.foldlevel = 1
vim.opt.foldlevelstart = 666
