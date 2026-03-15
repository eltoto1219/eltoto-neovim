vim.g.skip_defaults_vim = 1
vim.g.python_highlight_all = 1

vim.opt.nrformats:append("alpha")
vim.opt.shada = ""
vim.opt.foldmethod = "indent"
vim.opt.foldlevel = 99
vim.opt.backspace = { "indent", "eol", "start" }
vim.opt.errorbells = false
vim.opt.insertmode = false
vim.opt.hidden = true
vim.opt.cursorline = true
vim.opt.splitbelow = true
vim.opt.mouse = ""
vim.opt.selection = "exclusive"
vim.opt.shortmess:append("c")
vim.opt.wildignore:append({ "*/tmp/*", "*.so", "*.swp", "*.zip" })
vim.opt.wildmenu = true
vim.opt.wildmode = { "list", "full" }
vim.opt.winminheight = 0
vim.opt.winminwidth = 15
vim.opt.encoding = "UTF-8"
vim.opt.guifont = "Hack Nerd Font"
vim.opt.clipboard = "unnamedplus"

vim.api.nvim_set_hl(0, "StatusLine", { ctermbg = 819 })
