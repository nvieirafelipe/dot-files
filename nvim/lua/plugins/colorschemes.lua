return {
  {
    "dracula/vim",
    lazy = true,
    priority = 1000
  },

  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "moon",
      light_style = "day",
    },
    config = function(_, opts)
      require("tokyonight").setup(opts)
      vim.cmd [[colorscheme tokyonight]]
    end
  }
}
