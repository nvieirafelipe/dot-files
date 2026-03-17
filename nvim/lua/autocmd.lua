-- Removes training whitespaces on save
vim.api.nvim_create_autocmd({ "BufWritePre" }, {
  pattern = { "*" },
  command = [[%s/\s\+$//e]],
})

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("YankHighlight", { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- Toggle relative numbers based on focus/mode
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

-- Transparency (only in dark mode, light mode needs its backgrounds)
vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "*",
  callback = function()
    if vim.o.background == "light" then
      return
    end

    local function clear_bg(name)
      local hl = vim.api.nvim_get_hl(0, { name = name })
      hl.bg = "NONE"
      hl.ctermbg = "NONE"

      vim.api.nvim_set_hl(0, name, hl)
    end
    -- Normal text
    clear_bg("Normal")
    clear_bg("NormalNC")
    clear_bg("NormalFloat")
    -- Line numbers
    clear_bg("LineNr")
    clear_bg("SignColumn")
    -- Neo-tree
    clear_bg("NeoTreeNormal")
    clear_bg("NeoTreeNormalNC")
    -- Noice
    clear_bg("NoiceCmdline")
    -- Notify
    clear_bg("NotifyERRORBody")
    clear_bg("NotifyWARNBody")
    clear_bg("NotifyINFOBody")
    clear_bg("NotifyDEBUGBody")
    clear_bg("NotifyTRACEBody")
    clear_bg("NotifyERRORBorder")
    clear_bg("NotifyWARNBorder")
    clear_bg("NotifyINFOBorder")
    clear_bg("NotifyDEBUGBorder")
    clear_bg("NotifyTRACEBorder")
    -- Status line
    clear_bg("StatusLine")
    clear_bg("StatusLineNC")
    -- Other UI elements
    clear_bg("NonText")
    clear_bg("VertSplit")
    clear_bg("TabLineFill")
  end,
})
