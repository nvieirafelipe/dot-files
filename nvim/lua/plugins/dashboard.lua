return {
  {
    -- Startup screen
    "mhinz/vim-startify",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      local bookmarks = { { n = "~/Developer/dot-files/nvim" } }
      local work_dir = vim.env.WORK_PROJECT_DIR
      if work_dir and work_dir ~= "" then
        table.insert(bookmarks, { p = work_dir })
      end
      vim.g.startify_bookmarks = bookmarks
      vim.g.startify_change_to_vcs_root = 1

      function _G.webDevIcons(path)
        local filename = vim.fn.fnamemodify(path, ":t")
        local extension = vim.fn.fnamemodify(path, ":e")

        local devicons = require("nvim-web-devicons")
        return devicons.get_icon(filename, extension, { default = true })
      end

      vim.cmd([[
        function! StartifyEntryFormat() abort
          return 'v:lua.webDevIcons(absolute_path) . " " . entry_path'
        endfunction
      ]])

      vim.cmd([[
        autocmd FileType startify setlocal cursorline cursorcolumn
      ]])
    end,
  },
}
