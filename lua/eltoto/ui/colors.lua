local M = {}

function M.get_hl(name)
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
    return ok and hl or {}
end

function M.to_hex(color)
    if type(color) ~= "number" then
        return nil
    end

    return string.format("#%06x", color)
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

function M.blend(from, to, amount)
    if type(from) ~= "number" then
        return to
    end
    if type(to) ~= "number" then
        return from
    end

    local fr, fg, fb = rgb_to_channels(from)
    local tr, tg, tb = rgb_to_channels(to)

    local function mix(a, b)
        return math.floor(a + ((b - a) * amount) + 0.5)
    end

    return channels_to_rgb(mix(fr, tr), mix(fg, tg), mix(fb, tb))
end

function M.lighten(color, amount, reference)
    local target = reference
    if type(target) ~= "number" then
        target = 0xffffff
    end

    return M.blend(color, target, amount)
end

return M
