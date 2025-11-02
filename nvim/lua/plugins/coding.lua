return {
  -- Auto pairs
  {
    "echasnovski/mini.nvim",
    version = false,
    event = "VeryLazy",
    opts = {},
    config = function(_, opts)
      require("mini.pairs").setup(opts)
    end,
  },

  {
    "vim-test/vim-test",
    keys = {
      {
        "<M-t>",
        "<cmd>TestNearest<cr>",
        desc = "In a test file runs the test nearest to the cursor",
      },
      {
        "<M-S-t>",
        "<cmd>TestFile<cr>",
        desc = "In a test file runs all tests in the current file",
      },
    },
    config = function()
      vim.g["test#strategy"] = "neovim"
      vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { noremap = true })
    end,
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
        dart = "dart_format",
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
        dart = { "dart_format" },
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
      format_on_save = { timeout_ms = 1000 },
    },
  },

  {
    "hrsh7th/nvim-cmp",
    event = { "InsertEnter", "LspAttach" },
    fix_pairs = true,
    dependencies = {
      { "L3MON4D3/LuaSnip" },
    },
    config = function()
      -- Here is where you configure the autocompletion settings.
      local lsp_zero = require("lsp-zero")
      lsp_zero.extend_cmp()

      -- And you can configure cmp even more, if you want to.
      local cmp = require("cmp")
      local cmp_action = lsp_zero.cmp_action()

      local lspkind = require("lspkind")
      lspkind.init({
        mode = "symbol_text",
        preset = "default",
        symbol_map = {
          --   Class = "󰠱",
          --   Color = "󰏘",
          --   Constant = "󰏿",
          --   Constructor = "",
          Copilot = "",
          --   Enum = "",
          --   EnumMember = "",
          --   Event = "",
          --   Field = "󰜢",
          --   File = "󰈙",
          --   Folder = "󰉋",
          --   Function = "󰊕",
          --   Interface = "",
          --   Keyword = "󰌋",
          --   Method = "󰆧",
          --   Module = "",
          --   Operator = "󰆕",
          --   Property = "󰜢",
          --   Reference = "󰈇",
          --   Snippet = "",
          --   Struct = "󰙅",
          --   Text = "󰉿",
          --   TypeParameter = "",
          --   Unit = "󰑭",
          --   Value = "󰎠",
          --   Variable = "󰀫"
        },
      })
      vim.api.nvim_set_hl(0, "CmpItemKindCopilot", { fg = "#6CC644" })

      cmp.setup({
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        formatting = {
          format = lspkind.cmp_format({
            mode = "symbol", -- show only symbol annotations
            maxwidth = function()
              return math.floor(0.45 * vim.o.columns)
            end,
            -- maxwidth = 50, -- prevent the popup from showing more than provided characters (e.g 50 will not show more than 50 characters)
            ellipsis_char = "...",
            show_labelDetails = true,
          }),
        },
        mapping = cmp.mapping.preset.insert({
          ["<CR>"] = cmp.mapping.confirm({ select = false }),
          ["<Tab>"] = cmp_action.luasnip_supertab(),
          ["<S-Tab>"] = cmp_action.luasnip_shift_supertab(),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-j>"] = cmp.mapping.scroll_docs(-4),
          ["<C-k>"] = cmp.mapping.scroll_docs(4),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "copilot" },
          { name = "path" },
          { name = "render-markdown" },
        }, {
          { name = "buffer" },
        }),
      })
    end,
  },
}
