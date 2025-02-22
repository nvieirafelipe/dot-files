return {
  -- Auto pairs
  {
    "echasnovski/mini.nvim",
    version = false,
    event = "VeryLazy",
    opts = {},
    config = function(_, opts)
      require("mini.pairs").setup(opts)
    end
  },

  {
    "vim-test/vim-test",
    keys = {
      {
        "<M-t>",
        "<cmd>TestNearest<cr>",
        desc = "In a test file runs the test nearest to the cursor"
      },
      {
        "<M-S-t>",
        "<cmd>TestFile<cr>",
        desc = "In a test file runs all tests in the current file"
      }
    },
    config = function()
      vim.g["test#strategy"] = "neovim"
      vim.keymap.set('t', '<Esc>', [[<C-\><C-n>]], { noremap = true })
    end
  },

  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    -- This will provide type hinting with LuaLS
    ---@module "conform"
    ---@type conform.setupOpts
    opts = {
      lang_to_ft = {
        bash = "sh",
      },
      -- Map of treesitter language to file extension
      -- A temporary file name with this extension will be generated during formatting
      -- because some formatters care about the filename.
      lang_to_ext = {
        bash = "sh",
        c_sharp = "cs",
        elixir = "exs",
        javascript = "js",
        julia = "jl",
        latex = "tex",
        markdown = "md",
        python = "py",
        ruby = "rb",
        rust = "rs",
        teal = "tl",
        typescript = "ts",
      },
      formatters_by_ft = {
        bash = { "shfmt" },
        elixir = { "mix" },
        javascript = { "prettierd", "prettier", stop_after_first = true },
        json = { "jq" },
        lua = { "stylua" },
        python = { "isort", "black" },
        ruby = { "rubyfmt" },
        rust = { "rustfmt", lsp_format = "fallback" },
        sql = { "sleek" },
        terraform = { "terraform_fmt" },
      },
      -- Set default options
      default_format_opts = {
        lsp_format = "fallback",
      },
      -- Set up format-on-save
      format_on_save = { timeout_ms = 1000 }
    }
  },

  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "VeryLazy",
    config = function()
      require("copilot").setup({
        suggestion = { enabled = false },
        panel = { enabled = false }
      })
    end
  },

  {
    "zbirenbaum/copilot-cmp",
    config = function()
      local cmp = require("copilot_cmp")

      local has_words_before = function()
        if vim.api.nvim_buf_get_option(0, "buftype") == "prompt" then return false end
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
          end)
        }
      })
    end
  },

  { 'AndreM222/copilot-lualine' },

  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "main",
    dependencies = {
      { "github/copilot.vim" },                       -- or zbirenbaum/copilot.lua
      { "nvim-lua/plenary.nvim", branch = "master" }, -- for curl, log and async functions
    },
    event = "VeryLazy",
    build = "make tiktoken", -- Only on MacOS or Linux
    opts = {
      -- See Configuration section for options
      model = 'claude-3.5-sonnet'
    },
    keys = {
      { "<leader>cce", "<cmd>CopilotChatExplain<cr>", desc = "CopilotChat - Explain code" },
      { "<leader>cct", "<cmd>CopilotChatTests<cr>",   desc = "CopilotChat - Generate tests" },
      {
        "<leader>ccv",
        ":CopilotChatVisual",
        mode = "x",
        desc = "CopilotChat - Open in vertical split",
      },
      {
        "<leader>ccx",
        ":CopilotChatInPlace<cr>",
        mode = "x",
        desc = "CopilotChat - Run in-place code",
      }
    }
  },

  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    lazy = false,
    opts = {
      provider = 'copilot',
      auto_suggestions_provider = 'copilot',
      copilot = {
        model = 'claude-3.5-sonnet',
      },
    },
    build = "make",
    dependencies = {
      "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      --- The below dependencies are optional,
      "hrsh7th/nvim-cmp",            -- autocompletion for avante commands and mentions
      "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
      "zbirenbaum/copilot.lua",      -- for providers='copilot'
      'MeanderingProgrammer/render-markdown.nvim'
    }
  }
}
