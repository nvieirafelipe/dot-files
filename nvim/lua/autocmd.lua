-- Removes training whitespaces on save
vim.api.nvim_create_autocmd(
  { "BufWritePre" },
  {
    pattern = { "*" },
    command = [[%s/\s\+$//e]],
  }
)

--- Highlight on yank
vim.cmd [[
  augroup YankHighlight
    autocmd!
    autocmd TextYankPost * silent! lua vim.highlight.on_yank()
  augroup end
]]

-- Transparency
vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "*",
  callback = function()
    -- Normal text
    vim.api.nvim_set_hl(0, "Normal", { bg = "NONE", ctermbg = "NONE" })
    vim.api.nvim_set_hl(0, "NormalNC", { bg = "NONE", ctermbg = "NONE" })
    vim.api.nvim_set_hl(0, "NormalFloat", { bg = "NONE", ctermbg = "NONE" })
    -- Line numbers
    vim.api.nvim_set_hl(0, "LineNr", { bg = "NONE", ctermbg = "NONE" })
    vim.api.nvim_set_hl(0, "SignColumn", { bg = "NONE", ctermbg = "NONE" })
    -- Neo-tree
    vim.api.nvim_set_hl(0, "NeoTreeNormal", { bg = "NONE", ctermbg = "NONE" })
    vim.api.nvim_set_hl(0, "NeoTreeNormalNC", { bg = "NONE", ctermbg = "NONE" })
    -- Noice
    vim.api.nvim_set_hl(0, "NoiceCmdline", { bg = "NONE", ctermbg = "NONE" })
    -- Notify
    vim.api.nvim_set_hl(0, "NotifyERRORBody", { bg = "NONE", ctermbg = "NONE" })
    vim.api.nvim_set_hl(0, "NotifyWARNBody", { bg = "NONE", ctermbg = "NONE" })
    vim.api.nvim_set_hl(0, "NotifyINFOBody", { bg = "NONE", ctermbg = "NONE" })
    vim.api.nvim_set_hl(0, "NotifyDEBUGBody", { bg = "NONE", ctermbg = "NONE" })
    vim.api.nvim_set_hl(0, "NotifyTRACEBody", { bg = "NONE", ctermbg = "NONE" })
    vim.api.nvim_set_hl(0, "NotifyERRORBorder", { bg = "NONE", ctermbg = "NONE" })
    vim.api.nvim_set_hl(0, "NotifyWARNBorder", { bg = "NONE", ctermbg = "NONE" })
    vim.api.nvim_set_hl(0, "NotifyINFOBorder", { bg = "NONE", ctermbg = "NONE" })
    vim.api.nvim_set_hl(0, "NotifyDEBUGBorder", { bg = "NONE", ctermbg = "NONE" })
    vim.api.nvim_set_hl(0, "NotifyTRACEBorder", { bg = "NONE", ctermbg = "NONE" })
    -- Status line
    vim.api.nvim_set_hl(0, "StatusLine", { bg = "NONE", ctermbg = "NONE" })
    vim.api.nvim_set_hl(0, "StatusLineNC", { bg = "NONE", ctermbg = "NONE" })
    -- Other UI elements
    vim.api.nvim_set_hl(0, "NonText", { bg = "NONE", ctermbg = "NONE" })
    vim.api.nvim_set_hl(0, "VertSplit", { bg = "NONE", ctermbg = "NONE" })
    vim.api.nvim_set_hl(0, "TabLineFill", { bg = "NONE", ctermbg = "NONE" })
  end,
})
