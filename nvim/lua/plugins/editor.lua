return {
  -- search/replace in multiple files
  {
    "nvim-pack/nvim-spectre",
    build = false,
    cmd = "Spectre",
    opts = { open_cmd = "noswapfile vnew" },
    -- stylua: ignore
    keys = {
      {
        "<S-f>",
        function()
          require("spectre").toggle()
        end,
        desc = "Toggle Spectre"
      }
    }
  },

  -- Flash enhances the built-in search functionality by showing labels
  -- at the end of each match, letting you quickly jump to a specific
  -- location.
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
    },
  },

  -- Automatically highlights other instances of the word under your cursor.
  -- This works with LSP, Treesitter, and regexp matching to find the other
  -- instances.
  {
    "RRethy/vim-illuminate",
    event = "VeryLazy",
    opts = {
      delay = 200,
      large_file_cutoff = 2000,
      large_file_overrides = {
        -- providers: provider used to get references in the buffer, ordered by priority
        providers = {
          "lsp",
          "treesitter",
          "regex"
        },
      },
    },
    config = function(_, opts)
      require("illuminate").configure(opts)

      local function map(key, dir, buffer)
        vim.keymap.set("n", key, function()
          require("illuminate")["goto_" .. dir .. "_reference"](false)
        end, { desc = dir:sub(1, 1):upper() .. dir:sub(2) .. " Reference", buffer = buffer })
      end

      map("]]", "next")
      map("[[", "prev")

      -- also set it after loading ftplugins, since a lot overwrite [[ and ]]
      vim.api.nvim_create_autocmd("FileType", {
        callback = function()
          local buffer = vim.api.nvim_get_current_buf()
          map("]]", "next", buffer)
          map("[[", "prev", buffer)
        end,
      })
    end,
    keys = {
      { "]]", desc = "Next Reference" },
      { "[[", desc = "Prev Reference" },
    },
  },

  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope-symbols.nvim",
    },
    keys = {
      {
        "<C-l>",
        function()
          require("telescope.builtin").live_grep({
            additional_args = { "--hidden", "--glob", "!**/.git/*" }
          })
        end,
        desc = "Get results live as you type"
      },
      {
        "<C-p>",
        function()
          require("telescope.builtin").find_files({
            find_command = { "rg", "--files", "--hidden", "--follow", "--glob", "!**/.git/*" }
          })
        end,
        desc = "Find Files (root dir)"
      }
    },
    opts = function(_, opts)
      local function flash(prompt_bufnr)
        require("flash").jump({
          pattern = "^",
          label = { after = { 0, 0 } },
          search = {
            mode = "search",
            exclude = {
              function(win)
                return vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= "TelescopeResults"
              end,
            },
          },
          action = function(match)
            local picker = require("telescope.actions.state").get_current_picker(prompt_bufnr)
            picker:set_selection(match.pos[1] - 1)
          end,
        })
      end

      return {
        defaults = vim.tbl_deep_extend("force", opts.defaults or {}, {
          mappings = { n = { s = flash }, i = { ["<c-s>"] = flash } }
        })
      }
    end
  },

  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      {
        "<C-t>",
        function()
          require("trouble").toggle({ mode = "diagnostics" })
        end,
        desc = "Toggles diagnostics with Trouble"
      }
    },
    opts = {
      auto_close = true,
      auto_fold = true,
      auto_open = false,
      icons = {
        indent = {
          middle = " ",
          last = " ",
          top = " ",
          ws = "│  ",
        },
      },
      modes = {
        diagnostics = {
          groups = {
            { "filename", format = "{file_icon} {basename:Title} {count}" },
          },
        },
      },
      padding = false,
      signs = {
        -- icons / text used for a diagnostic
        error = '',
        warning = '',
        hint = '󰌶',
        information = '',
        other = '',
      }
    }
  },

  {
    "mfussenegger/nvim-lint",
    opts = {
      events = { "BufWritePost", "BufReadPost", "InsertLeave" },
      linters_by_ft = {
        elixir = { "credo" }
      }
    },
    config = function(_, opts)
      local lint         = require("lint")
      lint.linters_by_ft = opts.linters_by_ft

      vim.api.nvim_create_autocmd(opts.events, {
        group = vim.api.nvim_create_augroup("nvim-lint", { clear = true }),
        callback = function()
          lint.try_lint()
        end
      })
    end
  }
}
