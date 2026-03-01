return {
  {
    "VonHeikemen/lsp-zero.nvim",
    branch = "v3.x",
    lazy = true,
    config = false,
    init = function()
      -- Disable automatic setup, we are doing it manually
      vim.g.lsp_zero_extend_cmp = 0
      vim.g.lsp_zero_extend_lspconfig = 0
    end,
  },

  {
    "williamboman/mason.nvim",
    lazy = false,
    config = true,
  },

  -- Autocompletion 💅
  { "onsails/lspkind.nvim" },

  -- LSP
  {
    "neovim/nvim-lspconfig",
    cmd = { "LspInfo", "LspInstall", "LspStart" },
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      { "hrsh7th/cmp-nvim-lsp" },
      { "williamboman/mason-lspconfig.nvim" },
    },
    config = function()
      -- This is where all the LSP shenanigans will live
      vim.lsp.enable("dartls")

      local lsp_zero = require("lsp-zero")
      lsp_zero.extend_lspconfig()

      lsp_zero.on_attach(function(client, bufnr)
        -- see :help lsp-zero-keybindings
        -- to learn the available actions
        lsp_zero.default_keymaps({ buffer = bufnr })
      end)

      require("mason-lspconfig").setup({
        ensure_installed = {
          "autotools_ls",
          "bashls",
          "cssls",
          "diagnosticls",
          "docker_compose_language_service",
          "dockerls",
          "elixirls",
          "erlangls",
          "eslint",
          "html",
          "jqls",
          "jsonls",
          "lua_ls",
          "marksman",
          "ruby_lsp",
          "spectral",
          "sqlls",
          "tailwindcss",
          "taplo",
          "templ",
          "terraformls",
          "textlsp",
          "tflint",
          "ts_ls",
          "vimls",
          "yamlls",
        },
        handlers = {
          -- Disable handler to use another
          -- elixirls = lsp_zero.noop,
          lsp_zero.default_setup,
          lua_ls = function()
            -- (Optional) Configure lua language server for neovim
            local lua_opts = lsp_zero.nvim_lua_ls()
            require("lspconfig").lua_ls.setup(lua_opts)
          end,
        },
      })
      --
      -- diagnostic signs
      --
      local icons = {
        Error = " ",
        Warn = " ",
        Hint = " ",
        Info = " ",
      }

      for name, icon in pairs(icons) do
        name = "DiagnosticSign" .. name
        vim.fn.sign_define(name, { text = icon, texthl = name, numhl = "" })
      end
    end,
  },
}
