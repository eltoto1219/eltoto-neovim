local term_group = vim.api.nvim_create_augroup("EltotoTerminal", { clear = true })
local whitespace_group = vim.api.nvim_create_augroup("EltotoWhitespace", { clear = true })
local filetype_group = vim.api.nvim_create_augroup("EltotoFiletypes", { clear = true })

local function set_terminal_highlights()
    local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
    local normal_nc = vim.api.nvim_get_hl(0, { name = "NormalNC", link = false })
    local end_of_buffer = vim.api.nvim_get_hl(0, { name = "EndOfBuffer", link = false })

    vim.api.nvim_set_hl(0, "EltotoTerminalNormal", {
        fg = normal.fg,
        bg = 0x000000,
    })
    vim.api.nvim_set_hl(0, "EltotoTerminalNormalNC", {
        fg = normal_nc.fg or normal.fg,
        bg = 0x000000,
    })
    vim.api.nvim_set_hl(0, "EltotoTerminalEndOfBuffer", {
        fg = end_of_buffer.fg or 0x000000,
        bg = 0x000000,
    })
end

local function apply_terminal_window_style(winid)
    if not vim.api.nvim_win_is_valid(winid) then
        return
    end

    vim.wo[winid].winhighlight = table.concat({
        "Normal:EltotoTerminalNormal",
        "NormalNC:EltotoTerminalNormalNC",
        "EndOfBuffer:EltotoTerminalEndOfBuffer",
    }, ",")
end

local function clear_terminal_window_style(winid)
    if not vim.api.nvim_win_is_valid(winid) then
        return
    end

    local current = vim.wo[winid].winhighlight or ""
    if current:find("EltotoTerminal", 1, true) then
        vim.wo[winid].winhighlight = ""
    end
end

local function strip_trailing_whitespace()
    local view = vim.fn.winsaveview()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

    for index, line in ipairs(lines) do
        lines[index] = line:gsub("%s+$", "")
    end

    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.fn.winrestview(view)
end

vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
    group = filetype_group,
    pattern = { "*.cmake", "CMakeLists.txt" },
    callback = function()
        vim.opt_local.spell = false
        vim.opt_local.wrap = false
    end,
})

vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
    group = filetype_group,
    pattern = "*.jsx",
    callback = function()
        vim.bo.filetype = "javascript.jsx"
    end,
})

vim.api.nvim_create_autocmd("FileType", {
    group = filetype_group,
    pattern = "AvanteInput",
    callback = function()
        vim.opt_local.number = true
        vim.opt_local.relativenumber = true
    end,
})

vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
    group = term_group,
    callback = set_terminal_highlights,
})

vim.api.nvim_create_autocmd({ "TermOpen", "TermEnter", "BufEnter" }, {
    group = term_group,
    pattern = "term://*",
    callback = function()
        local ok, eltoto_avante = pcall(require, "eltoto.avante")
        if ok then
            local sidebar = eltoto_avante.get_sidebar(false)
            if sidebar and sidebar:is_open() then
                sidebar:close({ goto_code_win = false })
            end
        end

        vim.wo.relativenumber = false
        vim.wo.number = false
        vim.opt_local.signcolumn = "no"
        apply_terminal_window_style(vim.api.nvim_get_current_win())
    end,
})

vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    group = filetype_group,
    pattern = "*",
    callback = function(event)
        if vim.bo[event.buf].buftype == "" then
            clear_terminal_window_style(vim.api.nvim_get_current_win())
            vim.wo.number = true
            vim.wo.relativenumber = true
        end
    end,
})

vim.api.nvim_create_autocmd("BufLeave", {
    group = term_group,
    pattern = "term://*",
    callback = function()
        vim.cmd.stopinsert()
    end,
})

vim.api.nvim_create_autocmd("BufEnter", {
    group = term_group,
    pattern = "term://*",
    callback = function()
        vim.cmd.startinsert()
    end,
})

vim.api.nvim_create_autocmd("BufWritePre", {
    group = whitespace_group,
    pattern = "*",
    callback = strip_trailing_whitespace,
})

local function map_codecompanion_quit(bufnr)
    if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == "codecompanion" then
        local function close_codecompanion()
            local win = vim.api.nvim_get_current_win()
            local ok, config = pcall(vim.api.nvim_win_get_config, win)

            if ok and config.relative == "" then
                local close_ok = pcall(vim.api.nvim_win_close, win, true)
                if close_ok then
                    return
                end
            end

            if vim.api.nvim_buf_is_valid(bufnr) then
                vim.cmd.bwipeout({ args = { tostring(bufnr) }, bang = true })
            end
        end

        for _, lhs in ipairs({ "q", "qq" }) do
            vim.keymap.set("n", lhs, close_codecompanion, {
                buffer = bufnr,
                nowait = true,
                silent = true,
                desc = "Close CodeCompanion window",
            })
        end
    end
end

vim.api.nvim_create_autocmd({ "FileType", "BufEnter", "BufWinEnter" }, {
    group = filetype_group,
    pattern = "*",
    callback = function(event)
        map_codecompanion_quit(event.buf)
    end,
})
