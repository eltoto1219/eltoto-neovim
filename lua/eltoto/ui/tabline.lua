local M = {}
local terminal = require("eltoto.terminal")
local colors = require("eltoto.ui.colors")
local augroup = nil

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

local function is_ai_buffer(bufnr)
	return vim.b[bufnr].eltoto_ai_kind ~= nil
end

-- AI harness buffers are terminals too, but they get their own tabline
-- group: plain terminals and AI sessions never mix in one strip.
local function terminal_buffers()
	local buffers = {}

	for _, bufinfo in ipairs(terminal.buffer_info()) do
		if not is_ai_buffer(bufinfo.bufnr) then
			buffers[#buffers + 1] = bufinfo
		end
	end

	return buffers
end

local function ai_buffers()
	local buffers = {}

	for _, bufinfo in ipairs(terminal.buffer_info()) do
		if is_ai_buffer(bufinfo.bufnr) then
			buffers[#buffers + 1] = bufinfo
		end
	end

	return buffers
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
	local normal = colors.get_hl("Normal")
	local tabline = colors.get_hl("TabLine")
	local tabline_sel = colors.get_hl("TabLineSel")
	local tabline_fill = colors.get_hl("TabLineFill")
	local inactive_bg = colors.lighten(tabline.bg or normal.bg, 0.08, tabline.fg or normal.fg)
	local active_bg = colors.lighten(tabline_sel.bg or inactive_bg, 0.18, tabline_sel.fg or normal.fg)
	local separator_bg = colors.lighten(tabline_fill.bg or tabline.bg or normal.bg, 0.05, tabline.fg or normal.fg)
	local inactive_fg = tabline.fg or normal.fg
	local active_fg = tabline_sel.fg or normal.fg

	set_hl("EltotoTablineFileActive", {
		fg = active_fg,
		bg = active_bg,
		bold = true,
		italic = tabline_sel.italic,
	})
	set_hl("EltotoTablineFileInactive", {
		fg = inactive_fg,
		bg = inactive_bg,
		bold = tabline.bold,
		italic = tabline.italic,
	})
	set_hl("EltotoTablineTermActive", {
		fg = active_fg,
		bg = active_bg,
		bold = true,
		italic = tabline_sel.italic,
	})
	set_hl("EltotoTablineTermInactive", {
		fg = inactive_fg,
		bg = inactive_bg,
		bold = tabline.bold,
		italic = tabline.italic,
	})
	set_hl("EltotoTablineSeparator", {
		fg = tabline_fill.fg or inactive_fg,
		bg = separator_bg,
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
	local current_is_term = vim.bo[current].buftype == "terminal"
	local current_is_ai = current_is_term and is_ai_buffer(current)
	local buffers
	if current_is_ai then
		buffers = ai_buffers()
	elseif current_is_term then
		buffers = terminal_buffers()
	else
		buffers = regular_buffers()
	end

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
