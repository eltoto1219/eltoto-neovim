local M = {}

local buffers = require("eltoto.buffers")
local process_backend = require("eltoto.process_backend")
local terminal = require("eltoto.terminal")
local ui_input = require("eltoto.ui.input")
local ui_picker = require("eltoto.ui.picker")

local last_session_name = nil
local session_for_buf = {}

local function last_session_path()
    local dir = vim.fs.joinpath(vim.fn.stdpath("state"), "eltoto")
    vim.fn.mkdir(dir, "p")
    return vim.fs.joinpath(dir, "last_persistent_process")
end

local function save_last_session_name(name)
    last_session_name = name

    local path = last_session_path()
    if not name or name == "" then
        if vim.fn.filereadable(path) == 1 then
            vim.fn.delete(path)
        end
        return
    end

    vim.fn.writefile({ name }, path)
end

local function load_last_session_name()
    if last_session_name ~= nil then
        return last_session_name
    end

    local path = last_session_path()
    if vim.fn.filereadable(path) ~= 1 then
        return nil
    end

    local lines = vim.fn.readfile(path)
    local name = vim.trim(lines[1] or "")
    last_session_name = name ~= "" and name or nil
    return last_session_name
end

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

    local bufnr = terminal.open_command(process_backend.attach_command(item.name), "P:" .. item.name)
    if not bufnr then
        return
    end
    terminal.configure_persistent_buffer(bufnr)
    session_for_buf[bufnr] = item.name
    save_last_session_name(item.name)
    return bufnr
end

local function select_session(prompt, on_choice)
    local items = managed_sessions()

    if #items == 0 then
        vim.notify("No managed terminal processes found", vim.log.levels.INFO)
        return
    end

    local labels = {}
    for index, item in ipairs(items) do
        labels[index] = string.format("%2d. %s", index, item.name)
    end

    ui_picker.select(prompt, labels, function(index)
        on_choice(items[index])
    end)
end

function M.current_process_name(bufnr)
    return session_for_buf[bufnr or vim.api.nvim_get_current_buf()]
end

function M.attach_last()
    if not process_backend.available() then
        process_backend.notify_missing()
        return
    end

    local name = load_last_session_name()
    if name and session_exists(name) then
        attach({ session = process_backend.session_name(name), name = name })
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

            -- shpool creates missing sessions on attach; the startup command
            -- goes straight to the terminal's pty once the shell is up.
            local bufnr = attach({ session = process_backend.session_name(name), name = name })

            if startup_command ~= "" and bufnr then
                vim.defer_fn(function()
                    if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].channel ~= 0 then
                        vim.api.nvim_chan_send(vim.bo[bufnr].channel, startup_command .. "\r")
                    end
                end, 300)
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

        if load_last_session_name() == name then
            save_last_session_name(nil)
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
        local _, err = process_backend.kill_session(item.name)
        if err then
            vim.notify(err, vim.log.levels.ERROR)
            return
        end
        names[#names + 1] = item.name
    end

    save_last_session_name(nil)

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
