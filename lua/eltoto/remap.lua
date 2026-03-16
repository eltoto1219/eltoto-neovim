local map = vim.keymap.set
local map_opts = { silent = true }
local buffers = require("eltoto.buffers")
local processes = require("eltoto.processes")
local terminal = require("eltoto.terminal")
local run = require("eltoto.run")
local avante = require("eltoto.avante")

local function termcodes(keys)
    return vim.api.nvim_replace_termcodes(keys, true, false, true)
end

local function feed_normal(keys)
    return function()
        vim.api.nvim_feedkeys(termcodes(keys), "n", false)
    end
end

local function window_move(direction)
    return function()
        vim.cmd.wincmd(direction)
        vim.opt.autoread = true
    end
end

local function split_vertical()
    vim.cmd.vsplit()
end

local function split_horizontal()
    vim.cmd.split()
end

local function only_window()
    vim.cmd.only()
end

local function write_file()
    local ok, err = pcall(vim.cmd, "write!")
    if not ok then
        vim.notify(err, vim.log.levels.ERROR)
        return
    end

    vim.api.nvim_echo({ { "wrote", "ModeMsg" } }, false, {})
end

local function resize_height(delta)
    return function()
        if avante.resize_current_window(delta) then
            return
        end

        local amount = (delta > 0 and "+" or "") .. tostring(delta)
        vim.cmd("resize " .. amount)
    end
end

map("n", "<leader>,", buffers.backward, { silent = true, desc = "Previous file buffer" })
map("n", "<leader>;", buffers.forward, { silent = true, desc = "Next file buffer" })
map("n", "qq", buffers.quit_current_or_window, { silent = true, desc = "Close window, buffer, or quit" })
map("n", "qa", "<cmd>silent! q!<CR>", { silent = true, desc = "Force quit window" })
map("n", "<leader>ba", buffers.alternate, { silent = true, desc = "Alternate file buffer" })
map("n", "<leader>w", write_file, { silent = true, desc = "Write file" })
map("n", "<C-z>", "<nop>", { silent = true, desc = "Disable suspend" })

map("i", "jk", "<Esc>l", { silent = true, desc = "Leave insert mode" })
map("t", "jk", "<C-\\><C-n>", { silent = true, desc = "Leave terminal input mode" })
map("s", "jk", "<Esc>l", { silent = true, desc = "Leave select mode" })

map("v", "<space>", "<Esc>", { silent = true, desc = "Leave visual mode" })
map("v", "J", ":m '>+1<CR>gv=gv", { silent = true })
map("v", "K", ":m '<-2<CR>gv=gv", { silent = true })

map("n", "<leader>h", window_move("h"), { silent = true, desc = "Window left" })
map("n", "<leader>j", window_move("j"), { silent = true, desc = "Window down" })
map("n", "<leader>k", window_move("k"), { silent = true, desc = "Window up" })
map("n", "<leader>l", window_move("l"), { silent = true, desc = "Window right" })
map("n", "<leader>sv", split_vertical, { silent = true, desc = "Vertical split" })
map("n", "<leader>sh", split_horizontal, { silent = true, desc = "Horizontal split" })
map("n", "<leader>o", only_window, { silent = true, desc = "Only current window" })
map("n", [[<leader>"]], feed_normal([[ciw""<Esc>P<Esc>]]), { silent = true, desc = "Quote current word with double quotes" })
map("n", "<leader>'", feed_normal([[ciw''<Esc>P<Esc>]]), { silent = true, desc = "Quote current word with single quotes" })
map("n", "<leader>c", "za", { silent = true, desc = "Toggle fold" })
map("n", "dw", "dw", { silent = true, desc = "Delete one word" })
map("n", "d2w", "d2w", { silent = true, desc = "Delete two words" })
map("n", "d3w", "d3w", { silent = true, desc = "Delete three words" })
map("n", "d4w", "d4w", { silent = true, desc = "Delete four words" })
map("n", "yw", "yw", { silent = true, desc = "Yank one word" })
map("n", "cw", "cw", { silent = true, desc = "Change one word" })
map("n", "gu", "g~wi<Esc>", { silent = true, desc = "Swap case of current word" })
map("n", "gU", "g~Wi<Esc>", { silent = true, desc = "Swap case of current WORD" })
map("n", [[W"]], feed_normal([[ciW""<Esc>P]]), { silent = true, desc = "Quote current WORD with double quotes" })
map("n", "W'", feed_normal([[ciW''<Esc>P]]), { silent = true, desc = "Quote current WORD with single quotes" })
map("n", "<space>", function()
    vim.opt.hlsearch = not vim.opt.hlsearch:get()
end, { silent = true, desc = "Toggle search highlight" })
map("n", "<leader>t", terminal.toggle, { silent = true, desc = "Toggle terminal" })
map("n", "<leader>T", terminal.open_new, { silent = true, desc = "Open new terminal" })
map("n", "<leader>pp", processes.list, { silent = true, desc = "Persistent terminal picker" })
map("n", "<leader>pn", processes.new, { silent = true, desc = "New persistent terminal" })
map("n", "<leader>pa", processes.attach_last, { silent = true, desc = "Attach last persistent terminal" })
map("n", "<leader>pk", processes.kill_current_or_select, { silent = true, desc = "Kill persistent terminal" })
map("n", "<leader>pK", processes.kill_all, { silent = true, desc = "Kill all persistent terminals" })
map("n", "<leader>e", run.exec_current_file, { silent = true, desc = "Run current file" })
map("n", "<leader>=", resize_height(5), { silent = true, desc = "Increase window height" })
map("n", "<leader>-", resize_height(-5), { silent = true, desc = "Decrease window height" })
map("n", "W=", "<C-W>:vert resize +5<CR>", { silent = true, desc = "Increase window width" })
map("n", "W-", "<C-W>:vert resize -5<CR>", { silent = true, desc = "Decrease window width" })

map("t", "<leader>t", function()
    vim.api.nvim_feedkeys(termcodes("<C-\\><C-n>"), "n", false)
    vim.schedule(terminal.toggle)
end, { silent = true, desc = "Toggle terminal" })
map("t", "<leader>T", function()
    vim.api.nvim_feedkeys(termcodes("<C-\\><C-n>"), "n", false)
    vim.schedule(terminal.open_new)
end, { silent = true, desc = "Open new terminal" })
map("t", "<leader>;", function()
    vim.api.nvim_feedkeys(termcodes("<C-\\><C-n>"), "n", false)
    vim.schedule(terminal.forward)
end, { silent = true, desc = "Next terminal buffer" })
map("t", "<leader>,", function()
    vim.api.nvim_feedkeys(termcodes("<C-\\><C-n>"), "n", false)
    vim.schedule(terminal.backward)
end, { silent = true, desc = "Previous terminal buffer" })
map("t", "<leader>1", "<C-\\><C-n>:b1 #<CR>", { silent = true, desc = "Go to buffer 1" })
map("t", "qq", function()
    vim.api.nvim_feedkeys(termcodes("<C-\\><C-n>"), "n", false)
    vim.schedule(buffers.quit_current_or_window)
end, { silent = true, desc = "Close window, buffer, or quit" })
