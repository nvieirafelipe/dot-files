return {
  { "nvim-tree/nvim-web-devicons" },

  {
    "s1n7ax/nvim-window-picker",
    event = "VeryLazy",
    version = "2.*",
    config = function()
      require("window-picker").setup()
    end
  },

  {
    "nvim-lualine/lualine.nvim",
    event = "VimEnter",
    dependencies = {
      "folke/noice.nvim",
      "nvim-tree/nvim-web-devicons",
      "nvim-lua/lsp-status.nvim"
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
          { "filename", path = 1 }
        },
        lualine_x = {
          {
            require("noice").api.status.message.get_hl,
            cond = require("noice").api.status.message.has,
            color = { fg = "#ff9e64" },
          },
          {
            require("noice").api.status.command.get_hl,
            cond = require("noice").api.status.command.has,
            color = { fg = "#ff9e64" },
          },
          {
            require("noice").api.status.mode.get_hl,
            cond = require("noice").api.status.mode.has,
            color = { fg = "#ff9e64" },
          },
          {
            require("noice").api.status.search.get_hl,
            cond = require("noice").api.status.search.has,
            color = { fg = "#ff9e64" },
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
                  unknown = " "
                },
                hl = {
                  enabled = "#50FA7B",
                  sleep = "#AEB7D0",
                  disabled = "#6272A4",
                  warning = "#FFB86C",
                  unknown = "#FF5555"

                }
              },
              spinners = require("copilot-lualine.spinners").dots,
              spinner_color = "#6272A4"
            },
            show_colors = true,
            show_loading = true
          },
        },
        lualine_y = {
          { "fileformat", separator = " ", padding = { left = 1, right = 0 } },
          { "filetype",   separator = " ", padding = { left = 1, right = 1 } }
        },
        lualine_z = {
          { "progress", separator = "", padding = { left = 1, right = 0 } },
          { "location", separator = "", padding = { left = 0, right = 0 } }
        }
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
        enabled = true
      },
      exclude = {
        filetypes = {
          "help",
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

  {
    "echasnovski/mini.indentscope",
    version = false,
    event = "VeryLazy",
    opts = {
      symbol = "▏",
      -- symbol = "│",
      options = { try_as_border = true },
    },
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = {
          "help",
          "lazy",
          "lazyterm",
          "mason",
          "neo-tree",
          "neo-tree-popup",
          "startify"
        },
        callback = function()
          vim.b.miniindentscope_disable = true
        end,
      })
    end,
  },

  {
    "airblade/vim-gitgutter"
  },

  {
    "myusuf3/numbers.vim",
    config = function()
      vim.g.numbers_exclude = {
        "help",
        "neo-tree",
        "neo-tree-popup",
        "startify"
      }
    end
  },
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify"
    },
    keys = {
      { "q",     "<cmd>NoiceDismiss<CR>", desc = "Dismiss noice message" },
      { "<esc>", "<cmd>NoiceDismiss<CR>", desc = "Dismiss noice message" },
      {
        "<c-j>",
        function() if not require("noice.lsp").scroll(4) then return "<c-j>" end end,
        mode = { "n", "i", "s" },
        silent = true,
        expr = true,
        desc = "Scroll down"
      },
      {
        "<c-k>",
        function() if not require("noice.lsp").scroll(-4) then return "<c-k>" end end,
        mode = { "n", "i", "s" },
        silent = true,
        expr = true,
        desc = "Scroll up"
      }
    },
    config = function()
      require("notify").setup({
        background_colour = "#000000",
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
          bottom_search = true,         -- use a classic bottom cmdline for search
          command_palette = false,      -- position the cmdline and popupmenu together
          long_message_to_split = true, -- long messages will be sent to a split
          inc_rename = false,           -- enables an input dialog for inc-rename.nvim
          lsp_doc_border = true,        -- add a border to hover docs and signature help
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
                { find = "/" }
              },
            },
            opts = { skip = true },
          }
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
              winhighlight = { Normal = "Normal", FloatBorder = "DiagnosticInfo" },
            },
          },
        }
      })
    end
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
          "startify"
        }
      }

      require("overlength").setup(configs)
    end
  },

  { "HiPhish/rainbow-delimiters.nvim" }
}
