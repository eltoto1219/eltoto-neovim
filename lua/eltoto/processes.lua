local M = {}

local buffers = require("eltoto.buffers")
local process_backend = require("eltoto.process_backend")
local terminal = require("eltoto.terminal")
local ui_input = require("eltoto.ui.input")

local last_session_name = nil
local session_for_buf = {}

local function managed_sessions()
    return process_backend.managed_sessions()
end

local function session_exists(name)
    return process_backend.session_exists(name)
end

local function attach(item)
    if not process_backend.available() then
        process_backend.notify_missing()
        return
    end

    local bufnr = terminal.open_command(process_backend.command({
        "attach-session",
        "-t",
        item.session,
    }), item.name)
    if not bufnr then
        return
    end
    session_for_buf[bufnr] = item.name
    last_session_name = item.name
end

local function select_session(prompt, on_choice)
    local items = managed_sessions()

    if #items == 0 then
        vim.notify("No managed terminal processes found", vim.log.levels.INFO)
        return
    end

    local width = math.max(40, math.min(60, vim.o.columns - 8))
    local height = math.min(#items + 2, math.max(4, vim.o.lines - 8))
    local row = math.floor((vim.o.lines - height) / 2) - 1
    local col = math.floor((vim.o.columns - width) / 2)
    local bufnr = vim.api.nvim_create_buf(false, true)
    local winid = vim.api.nvim_open_win(bufnr, true, {
        relative = "editor",
        width = width,
        height = height,
        row = math.max(row, 0),
        col = math.max(col, 0),
        style = "minimal",
        border = "rounded",
        title = " " .. prompt .. " ",
        title_pos = "center",
    })

    local lines = {}
    for index, item in ipairs(items) do
        lines[#lines + 1] = string.format("%2d. %s", index, item.name)
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    vim.bo[bufnr].bufhidden = "wipe"
    vim.bo[bufnr].modifiable = false
    vim.bo[bufnr].filetype = "eltoto_process_picker"

    local function close_picker()
        if vim.api.nvim_win_is_valid(winid) then
            vim.api.nvim_win_close(winid, true)
        end
    end

    local function choose_current()
        local line = vim.api.nvim_win_get_cursor(winid)[1]
        local item = items[line]
        close_picker()
        if item then
            on_choice(item)
        end
    end

    local function move(delta)
        return function()
            local line = vim.api.nvim_win_get_cursor(winid)[1]
            local target = line + delta
            if target < 1 then
                target = #items
            elseif target > #items then
                target = 1
            end
            vim.api.nvim_win_set_cursor(winid, { target, 0 })
        end
    end

    local opts = { buffer = bufnr, silent = true, nowait = true }
    vim.keymap.set("n", "j", move(1), opts)
    vim.keymap.set("n", "k", move(-1), opts)
    vim.keymap.set("n", "<Down>", move(1), opts)
    vim.keymap.set("n", "<Up>", move(-1), opts)
    vim.keymap.set("n", "<CR>", choose_current, opts)
    vim.keymap.set("n", "q", close_picker, opts)
    vim.keymap.set("n", "<Esc>", close_picker, opts)

    vim.api.nvim_win_set_cursor(winid, { 1, 0 })
end

function M.current_process_name(bufnr)
    return session_for_buf[bufnr or vim.api.nvim_get_current_buf()]
end

function M.attach_last()
    if not process_backend.available() then
        process_backend.notify_missing()
        return
    end

    if last_session_name and session_exists(last_session_name) then
        attach({ session = process_backend.session_name(last_session_name), name = last_session_name })
        return
    end

    select_session("Attach persistent terminal:", function(item)
        if item then
            attach(item)
        end
    end)
end

function M.list()
    if not process_backend.available() then
        process_backend.notify_missing()
        return
    end

    select_session("Persistent terminal processes:", function(item)
        if item then
            attach(item)
        end
    end)
end

function M.new()
    if not process_backend.available() then
        process_backend.notify_missing()
        return
    end

    ui_input.centered({
        title = " Persistent Process ",
        prompt = "Name: ",
    }, function(name_input)
        if not name_input then
            return
        end

        local name = vim.trim(name_input)
        if name == "" then
            return
        end

        if session_exists(name) then
            vim.notify("Persistent process '" .. name .. "' already exists", vim.log.levels.WARN)
            attach({ session = process_backend.session_name(name), name = name })
            return
        end

        vim.schedule(function()
            ui_input.centered({
                title = " Startup Command ",
                prompt = "Command: ",
            }, function(command_input)
            local startup_command = command_input and vim.trim(command_input) or ""

            local _, err = process_backend.create_session(name)
            if err then
                return
            end

            attach({ session = process_backend.session_name(name), name = name })

            if startup_command ~= "" then
                vim.defer_fn(function()
                    process_backend.send_startup_command(name, startup_command)
                end, 50)
            end
            end)
        end)
    end)
end

function M.kill_current_or_select()
    if not process_backend.available() then
        process_backend.notify_missing()
        return
    end

    local current_buf = vim.api.nvim_get_current_buf()
    local current_name = M.current_process_name(current_buf)

    local function kill(name)
        local _, err = process_backend.kill_session(name)
        if err then
            vim.notify(err, vim.log.levels.ERROR)
            return
        end

        if current_name == name and vim.api.nvim_buf_is_valid(current_buf) then
            local target = buffers.get_last_edit_buf()
            if target then
                vim.cmd.buffer(target)
            end
            if vim.api.nvim_buf_is_valid(current_buf) then
                vim.cmd.bwipeout({ args = { tostring(current_buf) }, bang = true })
            end
        end

        if last_session_name == name then
            last_session_name = nil
        end

        vim.notify("Killed persistent terminal '" .. name .. "'")
    end

    if current_name and session_exists(current_name) then
        kill(current_name)
        return
    end

    select_session("Kill persistent terminal:", function(item)
        if item then
            kill(item.name)
        end
    end)
end

function M.kill_all()
    if not process_backend.available() then
        process_backend.notify_missing()
        return
    end

    local items = managed_sessions()
    if #items == 0 then
        vim.notify("No managed terminal processes found", vim.log.levels.INFO)
        return
    end

    local names = {}
    for _, item in ipairs(items) do
        local _, err = process_backend.system({ "kill-session", "-t", item.session })
        if err then
            vim.notify(err, vim.log.levels.ERROR)
            return
        end
        names[#names + 1] = item.name
    end

    process_backend.clear_registry()
    last_session_name = nil

    local current = vim.api.nvim_get_current_buf()
    local target = buffers.get_last_edit_buf()
    if target and vim.api.nvim_buf_is_valid(target) and vim.fn.buflisted(target) == 1 then
        pcall(vim.cmd.buffer, target)
    end

    for bufnr, _ in pairs(session_for_buf) do
        session_for_buf[bufnr] = nil
        if vim.api.nvim_buf_is_valid(bufnr) then
            pcall(vim.cmd.bwipeout, { args = { tostring(bufnr) }, bang = true })
        end
    end

    if vim.api.nvim_buf_is_valid(current) and terminal.is_terminal(current) and vim.fn.buflisted(current) == 1 then
        pcall(vim.cmd.bwipeout, { args = { tostring(current) }, bang = true })
    end

    vim.notify("Killed persistent terminals: " .. table.concat(names, ", "))
end

function M.setup()
    local group = vim.api.nvim_create_augroup("EltotoPersistentProcesses", { clear = true })

    vim.api.nvim_create_user_command("TerminalProcesses", M.list, {
        desc = "List and attach managed persistent terminal processes",
    })
    vim.api.nvim_create_user_command("TerminalProcessNew", M.new, {
        desc = "Create a new managed persistent terminal process",
    })
    vim.api.nvim_create_user_command("TerminalProcessKill", M.kill_current_or_select, {
        desc = "Kill a managed persistent terminal process",
    })
    vim.api.nvim_create_user_command("TerminalProcessKillAll", M.kill_all, {
        desc = "Kill all managed persistent terminal processes",
    })
    vim.api.nvim_create_user_command("TerminalProcessAttachLast", M.attach_last, {
        desc = "Attach the last managed persistent terminal process",
    })

    vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
        group = group,
        callback = function(event)
            session_for_buf[event.buf] = nil
        end,
    })
end

return M
