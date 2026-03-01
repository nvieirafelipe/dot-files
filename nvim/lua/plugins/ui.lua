return {
  { "nvim-tree/nvim-web-devicons" },

  {
    "s1n7ax/nvim-window-picker",
    event = "VeryLazy",
    version = "2.*",
    config = function()
      require("window-picker").setup()
    end,
  },

  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify",
    },
    keys = {
      {
        "<c-d>",
        function()
          if not require("noice.lsp").scroll(4) then
            return "<c-d>"
          end
        end,
        mode = { "n", "i", "s" },
        silent = true,
        expr = true,
        desc = "Scroll down",
      },
      {
        "<c-u>",
        function()
          if not require("noice.lsp").scroll(-4) then
            return "<c-u>"
          end
        end,
        mode = { "n", "i", "s" },
        silent = true,
        expr = true,
        desc = "Scroll up",
      },
    },
    config = function()
      require("notify").setup({
        background_colour = "#000000",
        fps = 42,
        max_height = 40,
        max_width = 160,
        render = "compact",
        stages = "fade_in_slide_out",
        timeout = 3000,
        top_down = true,
      })

      require("noice").setup({
        lsp = {
          override = {
            ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
            ["vim.lsp.util.stylize_markdown"] = true,
            ["cmp.entry.get_documentation"] = true,
          },
          hover = { enabled = true },
          signature = { enabled = true },
        },
        presets = {
          bottom_search = true, -- use a classic bottom cmdline for search
          command_palette = false, -- position the cmdline and popupmenu together
          long_message_to_split = true, -- long messages will be sent to a split
          inc_rename = false, -- enables an input dialog for inc-rename.nvim
          lsp_doc_border = true, -- add a border to hover docs and signature help
        },
        routes = {
          {
            filter = {
              event = "msg_show",
              any = {
                { find = "%d+L, %d+B" },
                { find = "; after #%d+" },
                { find = "; before #%d+" },
                { find = "%d fewer lines" },
                { find = "%d more lines" },
                { find = "written" },
                { find = "E486: Pattern not found:" },
                { find = "/" },
              },
            },
            opts = { skip = true },
          },
        },
        views = {
          cmdline_popup = {
            position = {
              row = 5,
              col = "50%",
            },
            size = {
              width = 120,
              height = "auto",
            },
          },
          popupmenu = {
            relative = "editor",
            position = {
              row = 8,
              col = "50%",
            },
            size = {
              width = 120,
              height = "auto",
            },
            border = {
              style = "rounded",
              padding = { 0, 1 },
            },
            win_options = {
              winhighlight = { Normal = "NormalFloat", FloatBorder = "DiagnosticInfo" },
            },
          },
        },
      })
    end,
  },

  { "AndreM222/copilot-lualine" },

  {
    "nvim-lualine/lualine.nvim",
    event = "VimEnter",
    dependencies = {
      "AndreM222/copilot-lualine",
      "folke/noice.nvim",
      "nvim-tree/nvim-web-devicons",
      "nvim-lua/lsp-status.nvim",
    },
    opts = {
      options = {
        theme = "auto",
        globalstatus = true,
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = {
          { "filename", path = 1 },
        },
        lualine_x = {
          {
            require("noice").api.status.message.get_hl,
            cond = require("noice").api.status.message.has,
          },
          {
            require("noice").api.status.command.get_hl,
            cond = require("noice").api.status.command.has,
          },
          {
            require("noice").api.status.mode.get_hl,
            cond = require("noice").api.status.mode.has,
          },
          {
            require("noice").api.status.search.get_hl,
            cond = require("noice").api.status.search.has,
          },
          {
            "copilot",
            symbols = {
              status = {
                icons = {
                  enabled = " ",
                  sleep = " ", -- auto-trigger disabled
                  disabled = " ",
                  warning = " ",
                  unknown = " ",
                },
                hl = {
                  enabled = "#50FA7B",
                  sleep = "#AEB7D0",
                  disabled = "#6272A4",
                  warning = "#FFB86C",
                  unknown = "#FF5555",
                },
              },
              spinners = "dots",
              spinner_color = "#6272A4",
            },
            show_colors = true,
            color = { bg = "NONE" },
            show_loading = true,
          },
        },
        lualine_y = {
          { "fileformat", separator = " ", padding = { left = 1, right = 0 } },
          { "filetype", separator = " ", padding = { left = 1, right = 1 } },
        },
        lualine_z = {
          { "progress", separator = "", padding = { left = 1, right = 0 } },
          { "location", separator = "", padding = { left = 0, right = 0 } },
        },
      },
      extensions = { "neo-tree", "lazy" },
    },
    config = function(_, opts)
      require("lualine").setup(opts)
    end,
  },

  {
    "lukas-reineke/indent-blankline.nvim",
    event = "VeryLazy",
    opts = {
      scope = {
        enabled = true,
      },
      exclude = {
        filetypes = {
          "help",
          "lazy",
          "lazyterm",
          "mason",
          "neo-tree",
          "neo-tree-popup",
          "notify",
          "startify",
          "toggleterm",
        },
      },
    },
    main = "ibl",
  },

  -- Highlight the part of a line that doesn"t fit into textwidth
  {
    "lcheylus/overlength.nvim",
    config = function()
      local configs = {
        enabled = true,
        colors = {
          ctermfg = "darkgrey",
          ctermbg = "black",
          fg = "darkgrey",
          bg = "black",
        },
        textwidth_mode = 1,
        default_overlength = 98,
        grace_length = 1,
        highlight_to_eol = true,
        disable_ft = {
          "",
          "Telescope",
          "WhichKey",
          "checkhealth",
          "help",
          "lazy",
          "man",
          "neo-tree",
          "neo-tree-popup",
          "noice",
          "packer",
          "qf",
          "startify",
        },
      }

      require("overlength").setup(configs)
    end,
  },

  { "HiPhish/rainbow-delimiters.nvim" },

  {
    "MeanderingProgrammer/render-markdown.nvim",
    after = { "nvim-treesitter" },
    opts = {
      file_types = { "markdown", "Avante" },
      latex = { enabled = false },
    },
    ft = { "markdown", "Avante" },
  },

  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
      -- your configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
      notifier = { enabled = true },
      notify = { enabled = true },
      picker = { enabled = true },
      win = {
        backdrop = {
          bg = "#e5e9f0", -- backdrop background color
          blend = 70, -- backdrop transparency (0-100)
        },
      },
      keys = {
        -- LSP
        {
          "gd",
          function()
            Snacks.picker.lsp_definitions()
          end,
          desc = "Goto Definition",
        },
        {
          "gD",
          function()
            Snacks.picker.lsp_declarations()
          end,
          desc = "Goto Declaration",
        },
        {
          "gr",
          function()
            Snacks.picker.lsp_references()
          end,
          nowait = true,
          desc = "References",
        },
        {
          "gI",
          function()
            Snacks.picker.lsp_implementations()
          end,
          desc = "Goto Implementation",
        },
        {
          "gy",
          function()
            Snacks.picker.lsp_type_definitions()
          end,
          desc = "Goto T[y]pe Definition",
        },
        {
          "gai",
          function()
            Snacks.picker.lsp_incoming_calls()
          end,
          desc = "C[a]lls Incoming",
        },
        {
          "gao",
          function()
            Snacks.picker.lsp_outgoing_calls()
          end,
          desc = "C[a]lls Outgoing",
        },
        {
          "<leader>ss",
          function()
            Snacks.picker.lsp_symbols()
          end,
          desc = "LSP Symbols",
        },
        {
          "<leader>sS",
          function()
            Snacks.picker.lsp_workspace_symbols()
          end,
          desc = "LSP Workspace Symbols",
        },
        -- Other
        {
          "<leader>gg",
          function()
            Snacks.lazygit()
          end,
          desc = "Lazygit",
        },
        {
          "<leader><space>",
          function()
            Snacks.picker.smart()
          end,
          desc = "Smart Find Files",
        },
        {
          "<leader>/",
          function()
            Snacks.picker.grep()
          end,
          desc = "Grep",
        },
        {
          "<leader>n",
          function()
            Snacks.notifier.show_history()
          end,
          desc = "Notification History",
        },
        {
          "<leader>N",
          function()
            Snacks.win({
              file = vim.api.nvim_get_runtime_file("doc/news.txt", false)[1],
              width = 0.6,
              height = 0.6,
              wo = {
                spell = false,
                wrap = false,
                signcolumn = "yes",
                statuscolumn = " ",
                conceallevel = 3,
              },
            })
          end,
          desc = "Neovim News",
        },
      },
    },

    {
      "folke/which-key.nvim",
      event = "VeryLazy",
      opts = {
        -- your configuration comes here
        -- or leave it empty to use the default settings
        -- refer to the configuration section below
      },
    },
    keys = {
      {
        "<leader>?",
        function()
          require("which-key").show({ global = false })
        end,
        desc = "Buffer Local Keymaps (which-key)",
      },
    },
  },
}
