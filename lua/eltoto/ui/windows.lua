local M = {}
local colors = require("aiterm.ui.colors")
local augroup = nil

local function separator_color()
    local normal = colors.get_hl("Normal")
    local float_border = colors.get_hl("FloatBorder")
    local statusline = colors.get_hl("StatusLine")

    local bg = normal.bg or statusline.bg or 0x000000
    local fg = normal.fg or float_border.fg or statusline.fg or 0xffffff

    if float_border.fg and math.abs(colors.luminance(float_border.fg) - colors.luminance(bg)) > 0.18 then
        return float_border.fg, bg
    end

    local amount = colors.luminance(bg) < 0.5 and 0.35 or 0.45
    return colors.blend(bg, fg, amount), bg
end

function M.setup_highlights()
    local fg, bg = separator_color()

    vim.api.nvim_set_hl(0, "WinSeparator", {
        fg = fg,
        bg = bg,
        bold = true,
    })
    vim.api.nvim_set_hl(0, "VertSplit", {
        fg = fg,
        bg = bg,
        bold = true,
    })
end

function M.register_autocmds()
    if augroup then
        return
    end

    augroup = vim.api.nvim_create_augroup("EltotoWindowSeparators", { clear = true })

    vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
        group = augroup,
        callback = function()
            M.setup_highlights()
        end,
    })
end

function M.setup()
    M.register_autocmds()
    M.setup_highlights()
end

return M
