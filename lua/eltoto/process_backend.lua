local M = {}

local SESSION_PREFIX = "eltoto-process-"

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

function M.available()
    return vim.fn.executable(tmux_path()) == 1
end

function M.notify_missing()
    vim.notify("tmux is required for persistent terminal processes", vim.log.levels.WARN)
end

function M.session_name(display_name)
    return SESSION_PREFIX .. display_name
end

function M.system(args)
    local escaped = { vim.fn.shellescape(tmux_path()) }
    for _, arg in ipairs(tmux_command_args(args)) do
        escaped[#escaped + 1] = vim.fn.shellescape(arg)
    end

    local output = vim.fn.system(table.concat(escaped, " ") .. " 2>&1")
    if vim.v.shell_error ~= 0 then
        return nil, output
    end

    return vim.split(output, "\n", { trimempty = true }), nil
end

function M.command(args)
    return vim.list_extend({ tmux_path() }, tmux_command_args(vim.deepcopy(args)))
end

function M.configure_server()
    M.system({ "start-server" })
    M.system({ "set-option", "-g", "default-terminal", "tmux-256color" })
    M.system({ "set-option", "-g", "default-shell", vim.o.shell })
    M.system({ "set-option", "-g", "status", "off" })
end

function M.has_session(name)
    local escaped = { vim.fn.shellescape(tmux_path()) }
    for _, arg in ipairs(tmux_command_args({ "has-session", "-t", M.session_name(name) })) do
        escaped[#escaped + 1] = vim.fn.shellescape(arg)
    end

    vim.fn.system(table.concat(escaped, " "))
    return vim.v.shell_error == 0
end

function M.managed_sessions()
    if not M.available() then
        return {}
    end

    local items = {}
    local stale = {}
    for _, name in ipairs(read_registry()) do
        if M.has_session(name) then
            items[#items + 1] = {
                session = M.session_name(name),
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

function M.session_exists(name)
    if M.has_session(name) then
        add_to_registry(name)
        return true
    end

    for _, item in ipairs(M.managed_sessions()) do
        if item.name == name then
            return true
        end
    end

    return false
end

function M.interactive_shell_command()
    return table.concat({
        vim.fn.shellescape(vim.o.shell),
        "-i",
    }, " ")
end

function M.create_session(name)
    M.configure_server()

    local _, err = M.system({
        "new-session",
        "-d",
        "-s",
        M.session_name(name),
        M.interactive_shell_command(),
    })
    if err then
        return nil, err
    end

    local _, status_err = M.system({ "set-option", "-t", M.session_name(name), "status", "off" })
    if status_err then
        return nil, status_err
    end

    add_to_registry(name)
    return true, nil
end

function M.send_startup_command(name, command)
    local trimmed = command and vim.trim(command) or ""
    if trimmed == "" then
        return true, nil
    end

    local _, send_err = M.system({ "send-keys", "-l", "-t", M.session_name(name), trimmed })
    if send_err then
        return nil, send_err
    end

    local _, enter_err = M.system({ "send-keys", "-t", M.session_name(name), "Enter" })
    if enter_err then
        return nil, enter_err
    end

    return true, nil
end

function M.kill_session(name)
    local _, err = M.system({ "kill-session", "-t", M.session_name(name) })
    if err then
        return nil, err
    end

    remove_from_registry(name)
    return true, nil
end

function M.clear_registry()
    write_registry({})
end

return M
