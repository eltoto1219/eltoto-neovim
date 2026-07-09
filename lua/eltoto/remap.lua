local map = vim.keymap.set

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
		local amount = (delta > 0 and "+" or "") .. tostring(delta)
		vim.cmd("resize " .. amount)
	end
end

map("n", "qa", "<cmd>silent! q!<CR>", { silent = true, desc = "Force quit window" })
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
map(
	"n",
	[[<leader>"]],
	feed_normal([[ciw""<Esc>P<Esc>]]),
	{ silent = true, desc = "Quote current word with double quotes" }
)
map(
	"n",
	"<leader>'",
	feed_normal([[ciw''<Esc>P<Esc>]]),
	{ silent = true, desc = "Quote current word with single quotes" }
)
map("n", "<leader>c", "za", { silent = true, desc = "Toggle fold" })
map("n", "gu", "g~wi<Esc>", { silent = true, desc = "Swap case of current word" })
map("n", "gU", "g~Wi<Esc>", { silent = true, desc = "Swap case of current WORD" })
map("n", [[W"]], feed_normal([[ciW""<Esc>P]]), { silent = true, desc = "Quote current WORD with double quotes" })
map("n", "W'", feed_normal([[ciW''<Esc>P]]), { silent = true, desc = "Quote current WORD with single quotes" })
map("n", "<space>", function()
	vim.opt.hlsearch = not vim.opt.hlsearch:get()
end, { silent = true, desc = "Toggle search highlight" })
map("n", "<leader>=", resize_height(5), { silent = true, desc = "Increase window height" })
map("n", "<leader>-", resize_height(-5), { silent = true, desc = "Decrease window height" })
map("n", "W=", "<C-W>:vert resize +5<CR>", { silent = true, desc = "Increase window width" })
map("n", "W-", "<C-W>:vert resize -5<CR>", { silent = true, desc = "Decrease window width" })

map("t", "<leader>1", "<C-\\><C-n>:b1 #<CR>", { silent = true, desc = "Go to buffer 1" })
map("t", "qa", "<C-\\><C-n><cmd>silent! q!<CR>", { silent = true, desc = "Force quit window" })
