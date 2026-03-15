local M = {}
local terminal = require("eltoto.terminal")
local avante = require("eltoto.avante")
local augroup = nil

local function get_hl(name)
	local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
	return ok and hl or {}
end

local function set_hl(name, opts)
	vim.api.nvim_set_hl(0, name, opts)
end

local function listed_buffers()
	return vim.fn.getbufinfo({ buflisted = 1 })
end

local function regular_buffers()
	local buffers = {}

	for _, bufinfo in ipairs(listed_buffers()) do
		if bufinfo.name ~= "" and not terminal.is_terminal(bufinfo.bufnr) then
			buffers[#buffers + 1] = bufinfo
		end
	end

	table.sort(buffers, function(a, b)
		return a.bufnr < b.bufnr
	end)

	return buffers
end

local function terminal_buffers()
	return terminal.buffer_info()
end

local function render_segment(text, hl_group)
	return string.format("%%#%s# %s %%*", hl_group, text)
end

local function regular_label(bufinfo)
	local label = vim.fs.basename(bufinfo.name)

	if bufinfo.changed == 1 then
		label = label .. " +"
	end

	return label
end

local function terminal_label(bufinfo)
	local label = terminal.label_for_buf(bufinfo.bufnr) or vim.fs.basename(vim.api.nvim_buf_get_name(bufinfo.bufnr))

	if bufinfo.changed == 1 then
		label = label .. " +"
	end

	return label
end

function M.setup_highlights()
	local tabline = get_hl("TabLine")
	local tabline_sel = get_hl("TabLineSel")
	local tabline_fill = get_hl("TabLineFill")

	set_hl("EltotoTablineFileActive", {
		fg = tabline_sel.fg,
		bg = tabline_sel.bg,
		bold = tabline_sel.bold,
		italic = tabline_sel.italic,
	})
	set_hl("EltotoTablineFileInactive", {
		fg = tabline.fg,
		bg = tabline.bg,
		bold = tabline.bold,
		italic = tabline.italic,
	})
	set_hl("EltotoTablineTermActive", {
		fg = tabline_sel.fg,
		bg = tabline_sel.bg,
		bold = tabline_sel.bold,
		italic = tabline_sel.italic,
	})
	set_hl("EltotoTablineTermInactive", {
		fg = tabline.fg,
		bg = tabline.bg,
		bold = tabline.bold,
		italic = tabline.italic,
	})
	set_hl("EltotoTablineAvanteActive", {
		fg = tabline_sel.fg,
		bg = tabline_sel.bg,
		bold = tabline_sel.bold,
		italic = tabline_sel.italic,
	})
	set_hl("EltotoTablineAvanteInactive", {
		fg = tabline.fg,
		bg = tabline.bg,
		bold = tabline.bold,
		italic = tabline.italic,
	})
	set_hl("EltotoTablineSeparator", {
		fg = tabline_fill.fg or tabline.fg,
		bg = tabline_fill.bg or tabline.bg,
	})
end

function M.register_autocmds()
	if augroup then
		return
	end

	augroup = vim.api.nvim_create_augroup("EltotoTablineHighlights", { clear = true })

	vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
		group = augroup,
		callback = function()
			M.setup_highlights()
			local ok, lualine = pcall(require, "lualine")
			if ok then
				lualine.refresh({
					place = { "tabline", "statusline" },
				})
			end
		end,
	})
end

function M.component()
	local current = vim.api.nvim_get_current_buf()
	if avante.is_sidebar_buffer(current) then
		local items = avante.tabline_items()
		if #items == 0 then
			return ""
		end

		local segments = {}
		for _, item in ipairs(items) do
			local hl_group = item.active and "EltotoTablineAvanteActive"
				or "EltotoTablineAvanteInactive"
			segments[#segments + 1] = render_segment(item.label, hl_group)
		end

		return table.concat(segments, "%#EltotoTablineSeparator#|%*")
	end

	local current_is_term = vim.bo[current].buftype == "terminal"
	local buffers = current_is_term and terminal_buffers() or regular_buffers()

	if #buffers == 0 then
		return ""
	end

	local items = {}

	for _, bufinfo in ipairs(buffers) do
		local is_active = bufinfo.bufnr == current
		local label = current_is_term and terminal_label(bufinfo) or regular_label(bufinfo)
		local hl_group

		if current_is_term then
			hl_group = is_active and "EltotoTablineTermActive" or "EltotoTablineTermInactive"
		else
			hl_group = is_active and "EltotoTablineFileActive" or "EltotoTablineFileInactive"
		end

		items[#items + 1] = render_segment(label, hl_group)
	end

	return table.concat(items, "%#EltotoTablineSeparator#|%*")
end

return M
