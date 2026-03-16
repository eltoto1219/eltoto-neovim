local M = {}
local augroup = nil

local function get_hl(name)
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
    return ok and hl or {}
end

local function channel(value, shift)
    return math.floor(value / 2 ^ shift) % 256
end

local function rgb_to_channels(color)
    return channel(color, 16), channel(color, 8), channel(color, 0)
end

local function channels_to_rgb(r, g, b)
    return r * 2 ^ 16 + g * 2 ^ 8 + b
end

local function blend(from, to, amount)
    local fr, fg, fb = rgb_to_channels(from)
    local tr, tg, tb = rgb_to_channels(to)

    local function mix(a, b)
        return math.floor(a + ((b - a) * amount) + 0.5)
    end

    return channels_to_rgb(mix(fr, tr), mix(fg, tg), mix(fb, tb))
end

local function luminance(color)
    local r, g, b = rgb_to_channels(color)
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
end

local function separator_color()
    local normal = get_hl("Normal")
    local float_border = get_hl("FloatBorder")
    local statusline = get_hl("StatusLine")

    local bg = normal.bg or statusline.bg or 0x000000
    local fg = normal.fg or float_border.fg or statusline.fg or 0xffffff

    if float_border.fg and math.abs(luminance(float_border.fg) - luminance(bg)) > 0.18 then
        return float_border.fg, bg
    end

    local amount = luminance(bg) < 0.5 and 0.35 or 0.45
    return blend(bg, fg, amount), bg
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
