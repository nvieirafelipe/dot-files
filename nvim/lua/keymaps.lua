-- Remap leader and local leader to <Space>
vim.api.nvim_set_keymap("", "<Space>", "<Nop>", { noremap = true, silent = true })
-- Make sure to set `mapleader` before lazy so your mappings are correct
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Reload configuration without restart nvim
vim.keymap.set('n', '<leader>r', ':so %<CR>')

-- Toggle light/dark theme
vim.keymap.set('n', '<leader>th', function()
  if vim.o.background == "dark" then
    vim.o.background = "light"
    vim.fn.system("osascript -e 'tell app \"System Events\" to tell appearance preferences to set dark mode to false'")
  else
    vim.o.background = "dark"
    vim.fn.system("osascript -e 'tell app \"System Events\" to tell appearance preferences to set dark mode to true'")
  end
  vim.cmd [[colorscheme tokyonight]]
end, { desc = "Toggle light/dark theme" })
