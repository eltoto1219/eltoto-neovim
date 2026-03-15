local M = {}

local function window_lines()
    local current_win = vim.api.nvim_get_current_win()
    local current_buf = vim.api.nvim_get_current_buf()
    local lines = {
        "Eltoto Window Debug",
        "tab_window_count: " .. tostring(#vim.api.nvim_tabpage_list_wins(0)),
        "winnr($): " .. tostring(vim.fn.winnr("$")),
        "current_win: " .. tostring(current_win),
        "current_buf: " .. tostring(current_buf),
        "current_filetype: " .. vim.bo[current_buf].filetype,
        "current_buftype: " .. vim.bo[current_buf].buftype,
        "current_buf_name: " .. vim.api.nvim_buf_get_name(current_buf),
    }

    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local buf = vim.api.nvim_win_get_buf(win)
        local config = vim.api.nvim_win_get_config(win)
        local relative = config.relative == "" and "normal" or config.relative

        lines[#lines + 1] = string.format(
            "win %d -> buf %d | ft=%s | bt=%s | relative=%s | current=%s",
            win,
            buf,
            vim.bo[buf].filetype,
            vim.bo[buf].buftype,
            relative,
            tostring(win == current_win)
        )
    end

    return lines
end

function M.windows()
    local lines = window_lines()
    local buf = vim.api.nvim_create_buf(false, true)
    local width = math.max(80, math.floor(vim.o.columns * 0.7))
    local height = math.min(#lines + 2, math.max(10, math.floor(vim.o.lines * 0.7)))
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].filetype = "markdown"

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        style = "minimal",
        border = "rounded",
        width = width,
        height = height,
        row = row,
        col = col,
        title = " DebugWindows ",
        title_pos = "center",
    })

    vim.keymap.set("n", "q", function()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end, {
        buffer = buf,
        nowait = true,
        silent = true,
        desc = "Close DebugWindows popup",
    })
end

function M.register()
    vim.api.nvim_create_user_command("DebugWindows", M.windows, {
        desc = "Show current Neovim window and buffer debug info",
    })
end

return M
