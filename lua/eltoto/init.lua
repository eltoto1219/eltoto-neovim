-- set leader
vim.g.mapleader = "w"

--require('dap-python').setup('~/ml/bin/python')
-- require("eltoto.packer")
require("eltoto.lazy")
require("eltoto.buffers").setup()
require("eltoto.terminal").setup()
require("eltoto.remap")
require("eltoto.set")
require("eltoto.autocmd")

vim.o.background = "dark"
vim.opt.nu = true
vim.opt.relativenumber = true
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

vim.opt.smartindent = true
vim.opt.wrap = false
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undofile = true

vim.opt.hlsearch = false
vim.opt.incsearch = true

vim.opt.termguicolors = true
vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.isfname:append("@-@")

vim.opt.updatetime = 50

vim.opt.colorcolumn = "80"

vim.g.nvim_tree_show_icons = {
  folders = 1,
  files = 1,
  git = 1,
  folder_arrows = 1,
}


vim.g.netrw_browse_split=  0
vim.g.netrw_banner = 0
vim.g.netrw_winsize = 25
