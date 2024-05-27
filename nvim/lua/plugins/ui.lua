return {
  {
    "nvim-tree/nvim-web-devicons"
  },

  {
    "s1n7ax/nvim-window-picker",
    name = "window-picker",
    event = "VeryLazy",
    version = "2.*",
    opts = {
      hint = 'floating-big-letter'
    }
  },

  {
    "nvim-lualine/lualine.nvim",
    event = "VimEnter",
    dependencies = {
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
          }
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

  -- Highlight the part of a line that doesn't fit into textwidth
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
  }
}
