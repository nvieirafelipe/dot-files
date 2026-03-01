return {
  {
    "isakbm/gitgraph.nvim",
    dependencies = { "sindrets/diffview.nvim" },
    opts = {
      format = {
        timestamp = "%H:%M:%S %d-%m-%Y",
        fields = { "hash", "branch_name", "message", "author", "timestamp", "tag" },
      },
      hooks = {
        -- Check diff of a commit
        on_select_commit = function(commit)
          vim.notify("DiffviewOpen " .. commit.hash .. "^!")
          vim.cmd(":DiffviewOpen " .. commit.hash .. "^!")
        end,
        -- Check diff from commit a -> commit b
        on_select_range_commit = function(from, to)
          vim.notify("DiffviewOpen " .. from.hash .. "~1.." .. to.hash)
          vim.cmd(":DiffviewOpen " .. from.hash .. "~1.." .. to.hash)
        end,
      },
      symbols = {
        merge_commit = "",
        commit = "",
        merge_commit_end = "",
        commit_end = "",

        -- Advanced symbols
        GVER = "",
        GHOR = "",
        GCLD = "",
        GCRD = "╭",
        GCLU = "",
        GCRU = "",
        GLRU = "",
        GLRD = "",
        GLUD = "",
        GRUD = "",
        GFORKU = "",
        GFORKD = "",
        GRUDCD = "",
        GRUDCU = "",
        GLUDCD = "",
        GLUDCU = "",
        GLRDCL = "",
        GLRDCR = "",
        GLRUCL = "",
        GLRUCR = "",
      },
    },
    keys = {
      {
        "<leader>gl",
        function()
          require("gitgraph").draw({}, { all = true, max_count = 5000 })
        end,
        desc = "GitGraph",
      },
    },
  },

  {
    "rbong/vim-flog",
    lazy = true,
    cmd = { "Flog", "Flogsplit", "Floggit" },
    dependencies = {
      "tpope/vim-fugitive",
    },
  },

  {
    "lewis6991/gitsigns.nvim",
    event = "VeryLazy",
    opts = {
      current_line_blame = true,
      current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = "eol",
        delay = 1000,
        ignore_whitespace = false,
        virt_text_priority = 100,
        use_focus = true,
      },
      numhl = true,
      signcolumn = false,
      signs_staged_enable = true,
      signs = {
        add = { text = "▊" },
        change = { text = "▊" },
        changedelete = { text = "▊" },
        delete = { text = "▁" },
        topdelete = { text = "▔" },
        untracked = { text = "▊" },
      },
      signs_staged = {
        add = { text = "▊" },
        change = { text = "▊" },
        changedelete = { text = "▊" },
        delete = { text = "▁" },
        topdelete = { text = "▔" },
        untracked = { text = "┆" },
      },
      word_diff = true,
      diff_opts = {
        algorithm = "histogram",
        linematch = 60,
      },
      on_attach = function(bufnr)
        local gs = require("gitsigns")
        local map = function(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
        end

        -- Navigation
        map("n", "]h", function() gs.nav_hunk("next") end, "Next hunk")
        map("n", "[h", function() gs.nav_hunk("prev") end, "Prev hunk")
        map("n", "]H", function() gs.nav_hunk("last") end, "Last hunk")
        map("n", "[H", function() gs.nav_hunk("first") end, "First hunk")

        -- Staging
        map("n", "<leader>gs", gs.stage_hunk, "Stage hunk")
        map("v", "<leader>gs", function()
          gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Stage selection")
        map("n", "<leader>gS", gs.stage_buffer, "Stage buffer")
        map("n", "<leader>gu", gs.undo_stage_hunk, "Undo stage hunk")

        -- Reset
        map("n", "<leader>gr", gs.reset_hunk, "Reset hunk")
        map("v", "<leader>gr", function()
          gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Reset selection")
        map("n", "<leader>gR", gs.reset_buffer, "Reset buffer")

        -- Preview / Diff
        map("n", "<leader>gp", gs.preview_hunk, "Preview hunk")
        map("n", "<leader>gi", gs.preview_hunk_inline, "Preview hunk inline")
        map("n", "<leader>gd", gs.diffthis, "Diff against index")
        map("n", "<leader>gD", function() gs.diffthis("~") end, "Diff against last commit")

        -- Blame
        map("n", "<leader>gb", function() gs.blame_line({ full = true }) end, "Blame line")
        map("n", "<leader>gB", gs.blame, "Blame file")

        -- Quickfix (auto-opens in Trouble if installed)
        map("n", "<leader>gq", gs.setqflist, "Hunks to quickfix")
        map("n", "<leader>gQ", function() gs.setqflist("all") end, "All repo hunks to quickfix")

        -- Toggles
        map("n", "<leader>gtb", gs.toggle_current_line_blame, "Toggle line blame")
        map("n", "<leader>gtw", gs.toggle_word_diff, "Toggle word diff")
        map("n", "<leader>gtd", gs.toggle_deleted, "Toggle deleted lines")

        -- Text object
        map({ "o", "x" }, "ih", gs.select_hunk, "inner hunk")
      end,
    },
    config = function(_, opts)
      local gitsigns = require("gitsigns")
      gitsigns.setup(opts)

      -- Tokyo Night bright palette for git signs
      vim.api.nvim_set_hl(0, "GitSignsAdd", { fg = "#9ece6a" })
      vim.api.nvim_set_hl(0, "GitSignsChange", { fg = "#e0af68" })
      vim.api.nvim_set_hl(0, "GitSignsDelete", { fg = "#f7768e" })
      vim.api.nvim_set_hl(0, "GitSignsTopdelete", { fg = "#f7768e" })
      vim.api.nvim_set_hl(0, "GitSignsChangedelete", { fg = "#ff9e64" })
      vim.api.nvim_set_hl(0, "GitSignsUntracked", { fg = "#bb9af7" })
    end,
  },

  { "sindrets/diffview.nvim" },
}
