local M = {}

local buffers = require("eltoto.buffers")
local terminal = require("eltoto.terminal")

local SESSION_PREFIX = "eltoto-process-"
local last_session_name = nil
local session_for_buf = {}

local function tmux_path()
    local path = vim.fn.exepath("tmux")
    if path ~= nil and path ~= "" then
        return path
    end

    return "tmux"
end

local function socket_path()
    local dir = vim.fs.joinpath(vim.fn.stdpath("state"), "tmux")
    vim.fn.mkdir(dir, "p")
    return vim.fs.joinpath(dir, "persistent-processes.sock")
end

local function registry_path()
    local dir = vim.fs.joinpath(vim.fn.stdpath("state"), "eltoto")
    vim.fn.mkdir(dir, "p")
    return vim.fs.joinpath(dir, "persistent_processes.json")
end

local function tmux_command_args(args)
    return vim.list_extend({ "-S", socket_path() }, args)
end

local function tmux_available()
    return vim.fn.executable(tmux_path()) == 1
end

local function notify_tmux_missing()
    vim.notify("tmux is required for persistent terminal processes", vim.log.levels.WARN)
end

local function session_name(display_name)
    return SESSION_PREFIX .. display_name
end

local function display_name(session)
    return session:gsub("^" .. vim.pesc(SESSION_PREFIX), "")
end

local function tmux_system(args)
    local escaped = { vim.fn.shellescape(tmux_path()) }
    for _, arg in ipairs(tmux_command_args(args)) do
        escaped[#escaped + 1] = vim.fn.shellescape(arg)
    end

    local output = vim.fn.system(table.concat(escaped, " "))
    if vim.v.shell_error ~= 0 then
        return nil, output
    end

    local result = vim.split(output, "\n", { trimempty = true })
    return result, nil
end

local function read_registry()
    local path = registry_path()
    if vim.fn.filereadable(path) ~= 1 then
        return {}
    end

    local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
    if not ok or type(decoded) ~= "table" then
        return {}
    end

    return decoded
end

local function write_registry(items)
    vim.fn.writefile({ vim.json.encode(items) }, registry_path())
end

local function add_to_registry(name)
    local items = read_registry()
    for _, item in ipairs(items) do
        if item == name then
            return
        end
    end

    items[#items + 1] = name
    table.sort(items)
    write_registry(items)
end

local function remove_from_registry(name)
    local items = {}
    for _, item in ipairs(read_registry()) do
        if item ~= name then
            items[#items + 1] = item
        end
    end
    write_registry(items)
end

local function tmux_has_session(name)
    local escaped = { vim.fn.shellescape(tmux_path()) }
    for _, arg in ipairs(tmux_command_args({ "has-session", "-t", session_name(name) })) do
        escaped[#escaped + 1] = vim.fn.shellescape(arg)
    end

    vim.fn.system(table.concat(escaped, " "))
    return vim.v.shell_error == 0
end

local function startup_shell_command(command)
    local shell = vim.o.shell
    local shell_path = vim.fn.shellescape(shell)
    local message = "[startup command finished, interactive shell opened]"
    local shell_command = command .. "; printf '\\n" .. message .. "\\n'; exec " .. shell_path .. " -i"

    return table.concat({
        vim.fn.shellescape(shell),
        vim.o.shellcmdflag,
        vim.fn.shellescape(shell_command),
    }, " ")
end

local function interactive_shell_command()
    return table.concat({
        vim.fn.shellescape(vim.o.shell),
        "-i",
    }, " ")
end

local function configure_tmux_server()
    tmux_system({ "start-server" })
    tmux_system({ "set-option", "-g", "default-terminal", "tmux-256color" })
    tmux_system({ "set-option", "-g", "default-shell", vim.o.shell })
    tmux_system({ "set-option", "-g", "status", "off" })
end

local function managed_sessions()
    if not tmux_available() then
        return {}
    end

    local items = {}
    local stale = {}
    for _, name in ipairs(read_registry()) do
        if tmux_has_session(name) then
            items[#items + 1] = {
                session = session_name(name),
                name = name,
            }
        else
            stale[#stale + 1] = name
        end
    end

    if #stale > 0 then
        for _, name in ipairs(stale) do
            remove_from_registry(name)
        end
    end

    table.sort(items, function(a, b)
        return a.name < b.name
    end)

    return items
end

local function session_exists(name)
    for _, item in ipairs(managed_sessions()) do
        if item.name == name then
            return true
        end
    end

    return false
end

local function attach(item)
    if not tmux_available() then
        notify_tmux_missing()
        return
    end

    local bufnr = terminal.open_command(vim.list_extend({ tmux_path() }, tmux_command_args({
        "attach-session",
        "-t",
        item.session,
    })), item.name)
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

local function attach_when_ready(name)
    local item = { session = session_name(name), name = name }

    if session_exists(name) then
        attach(item)
        return
    end

    vim.defer_fn(function()
        if session_exists(name) then
            attach(item)
        else
            vim.notify("Persistent terminal '" .. name .. "' did not start correctly", vim.log.levels.ERROR)
        end
    end, 100)
end

function M.current_process_name(bufnr)
    return session_for_buf[bufnr or vim.api.nvim_get_current_buf()]
end

function M.attach_last()
    if not tmux_available() then
        notify_tmux_missing()
        return
    end

    if last_session_name and session_exists(last_session_name) then
        attach({ session = session_name(last_session_name), name = last_session_name })
        return
    end

    select_session("Attach persistent terminal:", function(item)
        if item then
            attach(item)
        end
    end)
end

function M.list()
    if not tmux_available() then
        notify_tmux_missing()
        return
    end

    select_session("Persistent terminal processes:", function(item)
        if item then
            attach(item)
        end
    end)
end

function M.new()
    if not tmux_available() then
        notify_tmux_missing()
        return
    end

    vim.ui.input({ prompt = "Persistent process name: " }, function(name_input)
        if not name_input then
            return
        end

        local name = vim.trim(name_input)
        if name == "" then
            return
        end

        if session_exists(name) then
            vim.notify("Persistent process '" .. name .. "' already exists", vim.log.levels.WARN)
            attach({ session = session_name(name), name = name })
            return
        end

        vim.ui.input({ prompt = "Startup command (optional): " }, function(command_input)
            configure_tmux_server()
            local args = { "new-session", "-d", "-s", session_name(name) }
            if command_input and vim.trim(command_input) ~= "" then
                args[#args + 1] = startup_shell_command(vim.trim(command_input))
            else
                args[#args + 1] = interactive_shell_command()
            end

            local _, err = tmux_system(args)
            if err then
                vim.notify(err, vim.log.levels.ERROR)
                return
            end

            tmux_system({ "set-option", "-t", session_name(name), "status", "off" })
            add_to_registry(name)
            attach_when_ready(name)
        end)
    end)
end

function M.kill_current_or_select()
    if not tmux_available() then
        notify_tmux_missing()
        return
    end

    local current_buf = vim.api.nvim_get_current_buf()
    local current_name = M.current_process_name(current_buf)

    local function kill(name)
        local _, err = tmux_system({ "kill-session", "-t", session_name(name) })
        if err then
            vim.notify(err, vim.log.levels.ERROR)
            return
        end

        remove_from_registry(name)

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
    if not tmux_available() then
        notify_tmux_missing()
        return
    end

    local items = managed_sessions()
    if #items == 0 then
        vim.notify("No managed terminal processes found", vim.log.levels.INFO)
        return
    end

    local names = {}
    for _, item in ipairs(items) do
        local _, err = tmux_system({ "kill-session", "-t", item.session })
        if err then
            vim.notify(err, vim.log.levels.ERROR)
            return
        end
        names[#names + 1] = item.name
    end

    write_registry({})
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
