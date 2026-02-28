return {
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "VeryLazy",
    config = function()
      require("copilot").setup({
        suggestion = { enabled = false },
        panel = { enabled = false },
      })
    end,
  },

  {
    "zbirenbaum/copilot-cmp",
    config = function()
      local cmp = require("copilot_cmp")

      local has_words_before = function()
        if vim.bo[0].buftype == "prompt" then
          return false
        end
        local line, col = unpack(vim.api.nvim_win_get_cursor(0))
        return col ~= 0 and vim.api.nvim_buf_get_text(0, line - 1, 0, line - 1, col, {})[1]:match("^%s*$") == nil
      end

      cmp.setup({
        mapping = {
          ["<Tab>"] = vim.schedule_wrap(function(fallback)
            if cmp.visible() and has_words_before() then
              cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
            else
              fallback()
            end
          end),
        },
      })
    end,
  },

  {
    "folke/sidekick.nvim",
    event = "VeryLazy",
    opts = {
      nes = { enabled = false },
    },
     -- stylua: ignore
     keys = {
       {
         "<tab>",
         function()
           -- if there is a next edit, jump to it, otherwise apply it if any
           if not require("sidekick").nes_jump_or_apply() then
             return "<tab>" -- fallback to normal tab
           end
         end,
         expr = true,
         desc = "Goto/Apply Next Edit Suggestion",
       },
       {
         "<leader>aa",
         function() require("sidekick.cli").toggle() end,
         desc = "Sidekick Toggle CLI",
       },
       {
         "<leader>as",
         function() require("sidekick.cli").select() end,
         -- Or to select only installed tools:
         -- require("sidekick.cli").select({ filter = { installed = true } })
         desc = "Select CLI",
       },
       {
         "<leader>at",
         function() require("sidekick.cli").send({ msg = "{this}" }) end,
         mode = { "x", "n" },
         desc = "Send This",
       },
       {
         "<leader>av",
         function() require("sidekick.cli").send({ msg = "{selection}" }) end,
         mode = { "x" },
         desc = "Send Visual Selection",
       },
       {
         "<leader>ap",
         function() require("sidekick.cli").prompt() end,
         mode = { "n", "x" },
         desc = "Sidekick Select Prompt",
       },
       {
         "<c-.>",
         function() require("sidekick.cli").focus() end,
         mode = { "n", "x", "i", "t" },
         desc = "Sidekick Switch Focus",
       },
       -- Example of a keybinding to open Claude directly
       {
         "<leader>ac",
         function() require("sidekick.cli").toggle({ name = "claude", focus = true }) end,
         desc = "Sidekick Toggle Claude",
       },
     },
  },
}
