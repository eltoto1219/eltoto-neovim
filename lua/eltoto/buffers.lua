local M = {}

local last_edit_bufnr = nil

local function close_tree_if_visible()
    local ok, api = pcall(require, "nvim-tree.api")
    if ok and api.tree.is_visible() then
        pcall(api.tree.close)
    end
end

local function is_terminal_buf(bufnr)
    return vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "terminal"
end

local function is_avante_buf(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return false
    end

    local filetype = vim.bo[bufnr].filetype or ""
    if filetype:match("^Avante") then
        return true
    end

    return vim.api.nvim_buf_get_name(bufnr) == "AVANTE_RESULT"
end

local function is_named_edit_buf(bufnr)
    return vim.api.nvim_buf_is_valid(bufnr)
        and vim.fn.buflisted(bufnr) == 1
        and not is_terminal_buf(bufnr)
        and vim.api.nvim_buf_get_name(bufnr) ~= ""
end

local function listed_buffers()
    return vim.fn.getbufinfo({ buflisted = 1 })
end

local function is_normal_window(winid)
    local ok, config = pcall(vim.api.nvim_win_get_config, winid)
    return ok and config.relative == ""
end

local function normal_windows_in_tab()
    local wins = {}

    for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if is_normal_window(winid) then
            wins[#wins + 1] = winid
        end
    end

    return wins
end

local function avante_windows_in_tab()
    local wins = {}

    for _, winid in ipairs(normal_windows_in_tab()) do
        if is_avante_buf(vim.api.nvim_win_get_buf(winid)) then
            wins[#wins + 1] = winid
        end
    end

    return wins
end

local function safe_close_window(winid)
    if not vim.api.nvim_win_is_valid(winid) then
        return true
    end

    local ok = pcall(vim.api.nvim_win_close, winid, true)
    return ok or not vim.api.nvim_win_is_valid(winid)
end

local function safe_switch_current_window_buffer(bufnr)
    local current_win = vim.api.nvim_get_current_win()
    if not vim.api.nvim_win_is_valid(current_win) or not vim.api.nvim_buf_is_valid(bufnr) then
        return false
    end

    local had_winfixbuf = vim.wo[current_win].winfixbuf
    if had_winfixbuf then
        vim.wo[current_win].winfixbuf = false
    end

    local ok = pcall(vim.cmd.buffer, bufnr)

    if vim.api.nvim_win_is_valid(current_win) then
        vim.wo[current_win].winfixbuf = had_winfixbuf
    end

    return ok
end

local function close_avante_sidebar()
    local ok, avante = pcall(require, "avante")
    if ok and type(avante.close_sidebar) == "function" then
        pcall(avante.close_sidebar)
        return
    end

    for _, winid in ipairs(avante_windows_in_tab()) do
        safe_close_window(winid)
    end
end

function M.is_named_edit_buf(bufnr)
    return is_named_edit_buf(bufnr)
end

function M.real_edit_buffers()
    local real = {}

    for _, bufinfo in ipairs(listed_buffers()) do
        if bufinfo.name ~= "" and not is_terminal_buf(bufinfo.bufnr) then
            real[#real + 1] = bufinfo
        end
    end

    table.sort(real, function(a, b)
        return a.bufnr < b.bufnr
    end)

    return real
end

function M.terminal_buffers()
    local terms = {}

    for _, bufinfo in ipairs(listed_buffers()) do
        if is_terminal_buf(bufinfo.bufnr) then
            terms[#terms + 1] = bufinfo.bufnr
        end
    end

    table.sort(terms)

    return terms
end

function M.get_last_edit_buf()
    if is_named_edit_buf(last_edit_bufnr or -1) then
        return last_edit_bufnr
    end

    return nil
end

function M.jump_to(index)
    local target = M.real_edit_buffers()[index]
    if target then
        safe_switch_current_window_buffer(target.bufnr)
    end
end

function M.alternate()
    local alternate = vim.fn.bufnr("#")
    if is_named_edit_buf(alternate) then
        safe_switch_current_window_buffer(alternate)
        return
    end

    local last_edit = M.get_last_edit_buf()
    if last_edit and last_edit ~= vim.api.nvim_get_current_buf() then
        safe_switch_current_window_buffer(last_edit)
    end
end

function M.forward()
    local current = vim.api.nvim_get_current_buf()
    local buffers = M.real_edit_buffers()

    if #buffers == 0 then
        return
    end

    for index, item in ipairs(buffers) do
        if item.bufnr == current then
            local next_item = buffers[index + 1] or buffers[1]
            safe_switch_current_window_buffer(next_item.bufnr)
            return
        end
    end

    safe_switch_current_window_buffer(buffers[1].bufnr)
end

function M.backward()
    local current = vim.api.nvim_get_current_buf()
    local buffers = M.real_edit_buffers()

    if #buffers == 0 then
        return
    end

    for index, item in ipairs(buffers) do
        if item.bufnr == current then
            local prev_item = buffers[index - 1] or buffers[#buffers]
            safe_switch_current_window_buffer(prev_item.bufnr)
            return
        end
    end

    local last_item = buffers[#buffers]
    safe_switch_current_window_buffer(last_item.bufnr)
end

function M.quit_current_or_window()
    local current_win = vim.api.nvim_get_current_win()
    local normal_wins = normal_windows_in_tab()
    local current = vim.api.nvim_get_current_buf()
    local current_is_term = is_terminal_buf(current)
    local current_is_avante = is_avante_buf(current)
    local avante_wins = avante_windows_in_tab()
    local avante_is_open = #avante_wins > 0

    if not is_normal_window(current_win) then
        safe_close_window(current_win)
        return
    end

    if current_is_avante then
        local real = M.real_edit_buffers()
        local terms = M.terminal_buffers()
        close_avante_sidebar()
        if #real == 0 and #terms == 0 then
            vim.schedule(function()
                local current_buf = vim.api.nvim_get_current_buf()
                if vim.api.nvim_buf_is_valid(current_buf) and vim.api.nvim_buf_get_name(current_buf) == "" then
                    vim.cmd.quit({ bang = true })
                end
            end)
        end
        return
    end

    if #normal_wins > 1 and (not avante_is_open or current_is_term) then
        safe_close_window(current_win)
        return
    end

    local real = M.real_edit_buffers()
    local terms = M.terminal_buffers()
    local current_is_last_real = false
    local target = nil

    local function previous_real_buffer()
        for index, bufinfo in ipairs(real) do
            if bufinfo.bufnr == current then
                local previous = real[index - 1]
                local following = real[index + 1]
                return previous and previous.bufnr or (following and following.bufnr or nil)
            end
        end

        return nil
    end

    local function previous_terminal_buffer()
        for index, bufnr in ipairs(terms) do
            if bufnr == current then
                local previous = terms[index - 1]
                local following = terms[index + 1]
                return previous or following
            end
        end

        return nil
    end

    for _, bufinfo in ipairs(real) do
        if bufinfo.bufnr == current then
            current_is_last_real = #real == 1
            break
        end
    end

    if current_is_last_real and avante_is_open then
        close_avante_sidebar()
    end

    if (current_is_term and #real == 0) or (current_is_last_real and #terms > 0) then
        vim.cmd.qa({ bang = true })
        return
    end

    if current_is_term then
        target = previous_terminal_buffer() or M.get_last_edit_buf() or real[#real] and real[#real].bufnr or nil
    else
        target = previous_real_buffer()
    end

    if target and vim.api.nvim_buf_is_valid(target) and vim.fn.buflisted(target) == 1 then
        if not safe_switch_current_window_buffer(target) then
            return
        end
        vim.cmd.bwipeout({ args = { tostring(current) }, bang = true })
        if is_terminal_buf(target) then
            vim.cmd.startinsert()
        end
        return
    end

    if not current_is_term and current_is_last_real then
        close_tree_if_visible()
    end

    vim.cmd.bwipeout({ args = { tostring(current) }, bang = true })
    if vim.fn.bufname("%") == "" then
        vim.cmd.quit({ bang = true })
    end
end

function M.setup()
    local group = vim.api.nvim_create_augroup("EltotoBufferState", { clear = true })

    vim.api.nvim_create_autocmd("BufEnter", {
        group = group,
        callback = function(event)
            if is_named_edit_buf(event.buf) then
                last_edit_bufnr = event.buf
            end
        end,
    })
end

return M
