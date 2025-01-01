return {
  {
    'VonHeikemen/lsp-zero.nvim',
    branch = 'v3.x',
    lazy = true,
    config = false,
    init = function()
      -- Disable automatic setup, we are doing it manually
      vim.g.lsp_zero_extend_cmp = 0
      vim.g.lsp_zero_extend_lspconfig = 0
    end,
  },

  {
    'williamboman/mason.nvim',
    lazy = false,
    config = true,
  },

  -- Autocompletion 💅
  { "onsails/lspkind.nvim" },

  {
    'hrsh7th/nvim-cmp',
    event = 'InsertEnter',
    dependencies = {
      { 'L3MON4D3/LuaSnip' },
    },
    config = function()
      -- Here is where you configure the autocompletion settings.
      local lsp_zero = require('lsp-zero')
      lsp_zero.extend_cmp()

      -- And you can configure cmp even more, if you want to.
      local cmp = require('cmp')
      local cmp_action = lsp_zero.cmp_action()

      local lspkind = require('lspkind')
      lspkind.init {
        mode = 'symbol_text',
        preset = 'default',
        symbol_map = {
          --   Class = "󰠱",
          --   Color = "󰏘",
          --   Constant = "󰏿",
          --   Constructor = "",
          Copilot = ""
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
      }
      vim.api.nvim_set_hl(0, "CmpItemKindCopilot", { fg = "#6CC644" })

      cmp.setup({
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        -- formatting = lsp_zero.cmp_format(),
        formatting = {
          format = lspkind.cmp_format({
            mode = 'symbol', -- show only symbol annotations
            maxwidth = function() return math.floor(0.45 * vim.o.columns) end,
            -- maxwidth = 50, -- prevent the popup from showing more than provided characters (e.g 50 will not show more than 50 characters)
            ellipsis_char = '...',
            show_labelDetails = true
          })
        },
        mapping = cmp.mapping.preset.insert({
          ['<CR>'] = cmp.mapping.confirm({ select = false }),
          ['<Tab>'] = cmp_action.luasnip_supertab(),
          ['<S-Tab>'] = cmp_action.luasnip_shift_supertab(),
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<C-s>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "copilot" },
          { name = "path" }
        }, {
          { name = "buffer" }
        })
      })
    end
  },

  -- LSP
  {
    'neovim/nvim-lspconfig',
    cmd = { 'LspInfo', 'LspInstall', 'LspStart' },
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = {
      { 'hrsh7th/cmp-nvim-lsp' },
      { 'williamboman/mason-lspconfig.nvim' },
    },
    config = function()
      -- This is where all the LSP shenanigans will live
      local lsp_zero = require('lsp-zero')
      lsp_zero.extend_lspconfig()

      lsp_zero.on_attach(function(client, bufnr)
        -- see :help lsp-zero-keybindings
        -- to learn the available actions
        lsp_zero.default_keymaps({ buffer = bufnr })
        lsp_zero.buffer_autoformat()
      end)

      lsp_zero.format_on_save({
        format_opts = {
          async = false,
          timeout_ms = 10000,
        },
        servers = {
          ["marksman"] = { "markdown" }
        }
      })

      require('mason-lspconfig').setup({
        ensure_installed = {
          "autotools_ls",
          "bashls",
          "cssls",
          "diagnosticls",
          "docker_compose_language_service",
          "dockerls",
          "elixirls",
          -- "erlangls",
          "eslint",
          "grammarly",
          "html",
          "jqls",
          "jsonls",
          "lua_ls",
          "marksman",
          -- "nextls",
          -- "ruby_ls",
          "spectral",
          "sqlls",
          "tailwindcss",
          "taplo",
          "templ",
          "terraformls",
          "tflint",
          -- "tsserver",
          "vimls",
          "yamlls"
        },
        handlers = {
          -- Disable handler to use elixir-tools instead
          -- elixirls = lsp_zero.noop,
          lsp_zero.default_setup,
          lua_ls = function()
            -- (Optional) Configure lua language server for neovim
            local lua_opts = lsp_zero.nvim_lua_ls()
            require('lspconfig').lua_ls.setup(lua_opts)
          end,
        }
      })
      --
      -- diagnostic signs
      --
      local icons = {
        Error = " ",
        Warn  = " ",
        Hint  = " ",
        Info  = " ",
      }

      for name, icon in pairs(icons) do
        name = "DiagnosticSign" .. name
        vim.fn.sign_define(name, { text = icon, texthl = name, numhl = "" })
      end
    end
  }
}
