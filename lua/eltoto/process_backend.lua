local M = {}

local SESSION_PREFIX = "eltoto-process-"

-- shpool is a pass-through session holder: it keeps the shell alive in a
-- daemon and forwards raw bytes, so nvim's own terminal emulator owns the
-- scrollback. On reattach the daemon replays the last N lines
-- (session_restore_mode in ~/.config/shpool/config.toml) into the buffer.
local function shpool_path()
    local path = vim.fn.exepath("shpool")
    if path ~= "" then
        return path
    end

    -- setup.sh installs here; nvim may run before the rc PATH update applies.
    for _, candidate in ipairs({ "/.local/bin/shpool", "/.cargo/bin/shpool" }) do
        local full = vim.env.HOME .. candidate
        if vim.fn.executable(full) == 1 then
            return full
        end
    end

    return "shpool"
end

function M.available()
    return vim.fn.executable(shpool_path()) == 1
end

function M.notify_missing()
    vim.notify("shpool is required for persistent terminal processes (run scripts/setup.sh)", vim.log.levels.WARN)
end

function M.session_name(display_name)
    return SESSION_PREFIX .. display_name
end

function M.command(args)
    return vim.list_extend({ shpool_path() }, args)
end

function M.system(args)
    local result = vim.system(M.command(args), { text = true }):wait()
    if result.code ~= 0 then
        return nil, vim.trim((result.stdout or "") .. (result.stderr or ""))
    end

    return vim.split(result.stdout or "", "\n", { trimempty = true }), nil
end

-- "attach -f" both creates missing sessions and reclaims stale attachments
-- left behind when a previous nvim exited without detaching. start_dir sets the
-- working directory only when shpool creates the session.
function M.attach_command(display_name, start_dir)
    local args = { "attach", "-f" }
    if start_dir then
        vim.list_extend(args, { "--dir", start_dir })
    end
    args[#args + 1] = M.session_name(display_name)
    return M.command(args)
end

function M.managed_sessions()
    if not M.available() then
        return {}
    end

    local lines, _ = M.system({ "list" })
    if not lines then
        return {}
    end

    local items = {}
    for _, line in ipairs(lines) do
        local session = vim.trim(vim.split(line, "\t")[1] or "")
        if session and vim.startswith(session, SESSION_PREFIX) then
            items[#items + 1] = {
                session = session,
                name = session:sub(#SESSION_PREFIX + 1),
            }
        end
    end

    table.sort(items, function(a, b)
        return a.name < b.name
    end)

    return items
end

function M.session_exists(name)
    for _, item in ipairs(M.managed_sessions()) do
        if item.name == name then
            return true
        end
    end

    return false
end

function M.kill_session(name)
    local _, err = M.system({ "kill", M.session_name(name) })
    if err then
        return nil, err
    end

    return true, nil
end

return M
