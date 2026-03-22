-- Ghostty filetype detection (must be before lazy.nvim)
vim.filetype.add({
  pattern = { [".*ghostty/config"] = "ghostty" },
})

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
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    dependencies = { "HiPhish/rainbow-delimiters.nvim", "nvim-treesitter/nvim-treesitter" },
    config = function()
      local dim = { "RbDimRed", "RbDimYellow", "RbDimBlue", "RbDimOrange", "RbDimGreen", "RbDimViolet", "RbDimCyan" }
      local bright = { "RbRed", "RbYellow", "RbBlue", "RbOrange", "RbGreen", "RbViolet", "RbCyan" }
      local hooks = require("ibl.hooks")
      hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
        vim.api.nvim_set_hl(0, "RbDimRed", { fg = "#513636" })
        vim.api.nvim_set_hl(0, "RbDimYellow", { fg = "#514D36" })
        vim.api.nvim_set_hl(0, "RbDimBlue", { fg = "#364051" })
        vim.api.nvim_set_hl(0, "RbDimOrange", { fg = "#514136" })
        vim.api.nvim_set_hl(0, "RbDimGreen", { fg = "#3B5136" })
        vim.api.nvim_set_hl(0, "RbDimViolet", { fg = "#453651" })
        vim.api.nvim_set_hl(0, "RbDimCyan", { fg = "#365151" })
        vim.api.nvim_set_hl(0, "RbRed", { fg = "#B4585F" })
        vim.api.nvim_set_hl(0, "RbYellow", { fg = "#B49C64" })
        vim.api.nvim_set_hl(0, "RbBlue", { fg = "#4F8EC2" })
        vim.api.nvim_set_hl(0, "RbOrange", { fg = "#AB7D53" })
        vim.api.nvim_set_hl(0, "RbGreen", { fg = "#7C9E62" })
        vim.api.nvim_set_hl(0, "RbViolet", { fg = "#A163B4" })
        vim.api.nvim_set_hl(0, "RbCyan", { fg = "#47939A" })
      end)
      vim.g.rainbow_delimiters = { highlight = bright }
      require("ibl").setup({
        indent = { char = "▏", highlight = dim },
        scope = {
          enabled = true, show_start = false, show_end = false, highlight = bright,
          include = { node_type = { ["*"] = { "*" } } },
        },
      })
      hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          local lang = vim.treesitter.language.get_lang(args.match) or args.match
          if not pcall(vim.treesitter.language.inspect, lang) then
            pcall(require("nvim-treesitter").install, { lang })
          end
          pcall(vim.treesitter.start, args.buf, lang)
        end,
      })
    end,
  },
  {
    "saghen/blink.cmp",
    version = "1.*",
    lazy = false,
    opts = {
      keymap = { preset = "super-tab" },
      sources = { default = { "lsp", "path", "snippets", "buffer" } },
    },
  },
})

-- Ghostty vim runtime for syntax highlighting (after lazy.setup which rebuilds rtp)
local ghostty_res = vim.env.GHOSTTY_RESOURCES_DIR
if ghostty_res then
  local ghostty_vim = vim.fn.fnamemodify(ghostty_res, ":h") .. "/vim/vimfiles"
  if vim.fn.isdirectory(ghostty_vim) == 1 then
    vim.opt.rtp:prepend(ghostty_vim)
  end
end

-- Ghostty LSP
vim.lsp.config.ghostty = {
  cmd = { "ghostty-ls" },
  filetypes = { "ghostty" },
  capabilities = require("blink.cmp").get_lsp_capabilities(),
}
vim.lsp.enable("ghostty")

-- Options
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.undofile = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.number = true
vim.opt.scrolloff = 8
vim.opt.termguicolors = true
vim.opt.clipboard = "unnamedplus"
vim.opt.mousescroll = "ver:1,hor:1"

-- Emacs-style nav in command line
vim.keymap.set("c", "<C-a>", "<Home>")
vim.keymap.set("c", "<C-e>", "<End>")

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
