local M = {}

local buffers = require("eltoto.buffers")
local process_backend = require("eltoto.process_backend")
local terminal = require("eltoto.terminal")
local ui_input = require("eltoto.ui.input")
local ui_picker = require("eltoto.ui.picker")

local last_session_name = nil

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

local function cwd_map_path()
    local dir = vim.fs.joinpath(vim.fn.stdpath("state"), "eltoto")
    vim.fn.mkdir(dir, "p")
    return vim.fs.joinpath(dir, "process_cwds.json")
end

local function load_cwd_map()
    local ok, lines = pcall(vim.fn.readfile, cwd_map_path())
    if not ok then
        return {}
    end
    local decoded_ok, map = pcall(vim.json.decode, table.concat(lines, "\n"))
    return (decoded_ok and type(map) == "table") and map or {}
end

local function save_cwd_map(map)
    vim.fn.writefile({ vim.json.encode(map) }, cwd_map_path())
end

local function record_session_cwd(name, cwd, overwrite)
    local map = load_cwd_map()
    if map[name] and not overwrite then
        return
    end
    map[name] = cwd
    save_cwd_map(map)
end

local function forget_session_cwd(name)
    local map = load_cwd_map()
    if map[name] == nil then
        return
    end
    map[name] = nil
    save_cwd_map(map)
end

local function managed_sessions()
    return process_backend.managed_sessions()
end

local function session_exists(name)
    return process_backend.session_exists(name)
end

local function process_name(bufnr)
    return terminal.persistent_process_name(bufnr)
end

local function attach(item, start_dir, created)
    if not process_backend.available() then
        process_backend.notify_missing()
        return
    end

    -- Reuse an existing buffer for this session instead of attaching twice
    -- (a second shpool attach -f would steal the session from the first).
    local existing = terminal.find_persistent_buffer(item.name)
    if existing then
        terminal.focus(existing)
        save_last_session_name(item.name)
        return existing
    end

    local bufnr = terminal.open_command(process_backend.attach_command(item.name, start_dir), "P:" .. item.name)
    if not bufnr then
        return
    end
    terminal.configure_persistent_buffer(bufnr, item.name)
    save_last_session_name(item.name)
    if start_dir then
        record_session_cwd(item.name, start_dir, created)
    end
    return bufnr
end

local function select_session(prompt, on_choice)
    local items = managed_sessions()

    if #items == 0 then
        vim.notify("No managed terminal processes found", vim.log.levels.INFO)
        return
    end

    local map = load_cwd_map()
    local home = vim.env.HOME or ""
    local labels = {}
    for index, item in ipairs(items) do
        local cwd = map[item.name] or ""
        if home ~= "" and cwd:sub(1, #home) == home then
            cwd = "~" .. cwd:sub(#home + 1)
        end
        labels[index] = string.format("%2d. %s  %s", index, cwd, item.name)
    end

    ui_picker.select(prompt, labels, function(index)
        on_choice(items[index])
    end)
end

function M.current_process_name(bufnr)
    return process_name(bufnr or vim.api.nvim_get_current_buf())
end

function M.register_session_cwd(name, cwd)
    if type(name) ~= "string" or name == "" or type(cwd) ~= "string" or cwd == "" then
        return
    end
    record_session_cwd(name, cwd, true)
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

function M.attach_all_cwd()
    if not process_backend.available() then
        process_backend.notify_missing()
        return
    end

    local cwd = vim.fn.getcwd()
    local map = load_cwd_map()

    local matched, opened = 0, 0
    for _, item in ipairs(managed_sessions()) do
        if map[item.name] == cwd then
            matched = matched + 1
            if not terminal.find_persistent_buffer(item.name) and attach(item) then
                opened = opened + 1
            end
        end
    end

    if matched == 0 then
        vim.notify("No persistent terminal processes for " .. cwd, vim.log.levels.INFO)
    elseif opened == 0 then
        vim.notify("All persistent terminal processes for this directory are already open", vim.log.levels.INFO)
    else
        vim.notify(string.format("Attached %d persistent terminal process%s", opened, opened == 1 and "" or "es"))
    end
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

            if session_exists(name) then
                vim.notify("Persistent process '" .. name .. "' already exists", vim.log.levels.WARN)
                attach({ session = process_backend.session_name(name), name = name })
                return
            end

            -- shpool creates missing sessions on attach; the startup command
            -- goes straight to the terminal's pty once the shell is up.
            local bufnr = attach({ session = process_backend.session_name(name), name = name }, vim.fn.getcwd(), true)

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
        forget_session_cwd(name)

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
        forget_session_cwd(item.name)
    end

    save_last_session_name(nil)

    local current = vim.api.nvim_get_current_buf()
    local target = buffers.get_last_edit_buf()
    if target and vim.api.nvim_buf_is_valid(target) and vim.fn.buflisted(target) == 1 then
        pcall(vim.cmd.buffer, target)
    end

    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if process_name(bufnr) then
            pcall(vim.cmd.bwipeout, { args = { tostring(bufnr) }, bang = true })
        end
    end

    if vim.api.nvim_buf_is_valid(current) and terminal.is_terminal(current) and vim.fn.buflisted(current) == 1 then
        pcall(vim.cmd.bwipeout, { args = { tostring(current) }, bang = true })
    end

    vim.notify("Killed persistent terminals: " .. table.concat(names, ", "))
end

function M.setup()
    vim.api.nvim_create_augroup("EltotoPersistentProcesses", { clear = true })

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
    vim.api.nvim_create_user_command("TerminalProcessAttachAll", M.attach_all_cwd, {
        desc = "Attach all managed persistent terminal processes for the current working directory",
    })
end

return M
