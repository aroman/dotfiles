-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Plugins
require("lazy").setup({
  {
    "projekt0n/github-nvim-theme",
    lazy = false,
    priority = 1000,
    config = function()
      require("github-theme").setup({
        options = {
          transparent = true,
        },
      })
      vim.cmd("colorscheme github_dark_dimmed")
    end,
  },
  { "nvim-tree/nvim-web-devicons" },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        theme = "auto",
        section_separators = { left = "", right = "" },
        component_separators = { left = "", right = "" },
      },
      sections = {
        lualine_a = {
          { "mode", color = { gui = "bold" } },
        },
      },
    },
  },
  {
    "lewis6991/gitsigns.nvim",
    opts = {},
  },
})

-- No swap/backup files
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false

-- Search
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Display
vim.opt.number = true
vim.opt.scrolloff = 8
vim.opt.termguicolors = true

-- System clipboard
vim.opt.clipboard = "unnamedplus"

-- Mouse scroll speed (default is 3 lines per tick)
vim.opt.mousescroll = "ver:1,hor:1"

-- Reopen file at last position
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lines = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lines then
      vim.api.nvim_win_set_cursor(0, mark)
    end
  end,
})
