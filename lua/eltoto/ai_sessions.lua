local M = {}

local terminal = require("eltoto.terminal")

-- Registry of AI harness sessions (claude, codex) running in plain terminal
-- buffers. Identity is pinned at spawn time: claude via --session-id, codex by
-- watching its rollout file appear. Entries survive nvim exits and crashes;
-- they are removed only when a session is quit naturally (process exit or
-- buffer close inside nvim), so whatever remains is restorable.

local entries = {}   -- key -> entry { key, kind, id, cwd, title, last_used }
local buffers = {}   -- bufnr -> key
local pending_resumes = {}
local unnamed_counter = 0
local exiting = false
local last_ai_bufnr = nil
local toggle_return_bufnr = nil

M.codex_sessions_dir = vim.fs.joinpath(vim.env.HOME or "~", ".codex", "sessions")

-- Shell aliases don't apply to termopen commands, so the always-on flags
-- live here instead.
local claude_args = { "--dangerously-skip-permissions" }
local codex_args = {
    "--no-alt-screen",
    "--search",
    "--dangerously-bypass-approvals-and-sandbox",
    "--dangerously-bypass-hook-trust",
}

local function command(argv, extra_args)
    return vim.list_extend(argv, extra_args)
end

M.commands = {
    claude = function(entry, resume)
        -- claude's fullscreen TUI lives on the alternate screen, which has no
        -- scrollback; NO_FLICKER=0 forces inline rendering so the transcript
        -- accumulates in the terminal buffer.
        local argv = { "env", "CLAUDE_CODE_NO_FLICKER=0", "claude" }
        if resume then
            vim.list_extend(argv, { "--resume", entry.id })
        elseif entry and entry.id then
            vim.list_extend(argv, { "--session-id", entry.id })
        end
        return command(argv, claude_args)
    end,
    codex = function(entry, resume)
        if resume then
            if entry and entry.id then
                return command({ "codex", "resume", entry.id }, codex_args)
            end
            return command({ "codex", "resume", "--last" }, codex_args)
        end
        return command({ "codex" }, codex_args)
    end,
}

function M.shell_command(kind)
    local builder = M.commands[kind]
    if not builder then
        return nil
    end

    local escaped = vim.tbl_map(vim.fn.shellescape, builder(nil, false))
    return table.concat(escaped, " ")
end

function M.ensure_available(kind)
    if not M.commands[kind] then
        vim.notify("Unknown AI harness: " .. tostring(kind), vim.log.levels.ERROR)
        return false
    end

    if vim.fn.executable(kind) ~= 1 then
        vim.notify(kind .. " is not installed or not on PATH", vim.log.levels.ERROR)
        return false
    end

    return true
end

local function registry_path()
    local dir = vim.fs.joinpath(vim.fn.stdpath("state"), "eltoto")
    vim.fn.mkdir(dir, "p")
    return vim.fs.joinpath(dir, "ai_sessions.json")
end

local function load_registry()
    local path = registry_path()
    if vim.fn.filereadable(path) ~= 1 then
        return
    end

    local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
    if not ok or type(decoded) ~= "table" then
        return
    end

    for _, entry in ipairs(decoded) do
        if type(entry) == "table" and type(entry.key) == "string" and M.commands[entry.kind] then
            entries[entry.key] = entry
        end
    end
end

local function entry_is_restorable(entry)
    return type(entry.id) == "string" and entry.id ~= ""
end

local function save_registry()
    local list = {}
    for _, entry in pairs(entries) do
        if entry_is_restorable(entry) then
            list[#list + 1] = entry
        end
    end
    table.sort(list, function(a, b)
        return (a.last_used or 0) > (b.last_used or 0)
    end)

    while #list > 20 do
        local dropped = table.remove(list)
        entries[dropped.key] = nil
    end

    vim.fn.writefile({ vim.json.encode(list) }, registry_path())
end

local function generate_uuid()
    local handle = io.open("/proc/sys/kernel/random/uuid", "r")
    if handle then
        local uuid = vim.trim(handle:read("*l") or "")
        handle:close()
        if #uuid == 36 then
            return uuid
        end
    end

    local out = vim.trim(vim.fn.system("uuidgen"))
    if vim.v.shell_error == 0 and #out == 36 then
        return out
    end

    math.randomseed(vim.uv.hrtime())
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return (template:gsub("[xy]", function(c)
        local v = c == "x" and math.random(0, 15) or math.random(8, 11)
        return string.format("%x", v)
    end))
end

local function clean_title(title)
    if type(title) ~= "string" or title:find("^term:") then
        return nil
    end

    title = title:gsub("%s+", " ")
    title = title:gsub("[%z\1-\31]", "")

    -- Keep the first four words; a token counts as a word only if it has an
    -- alphanumeric character (numbers count, bare punctuation does not).
    local words = {}
    for token in title:gmatch("%S+") do
        token = token:gsub("^%p+", ""):gsub("%p+$", "")
        if token:find("%w") then
            words[#words + 1] = token
            if #words == 4 then
                break
            end
        end
    end

    title = table.concat(words, " "):gsub("[%%#]", "")
    if title == "" then
        return nil
    end

    if #title > 48 then
        title = vim.trim(title:sub(1, 48))
    end

    return title
end

local function entry_label(entry)
    if entry.title and entry.title ~= "" then
        return entry.title
    end

    local label = "Unnamed:" .. unnamed_counter
    unnamed_counter = unnamed_counter + 1
    return label
end

local function buffer_alive(bufnr)
    return vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "terminal"
end

local function entry_is_alive(key)
    for bufnr, buf_key in pairs(buffers) do
        if buf_key == key and buffer_alive(bufnr) then
            return true
        end
    end

    return false
end

local function watch_title(bufnr, key)
    local initial = vim.b[bufnr].term_title

    local function poll()
        if exiting or not buffer_alive(bufnr) or buffers[bufnr] ~= key then
            return
        end

        local entry = entries[key]
        local title = vim.b[bufnr].term_title
        if entry and title ~= initial then
            local cleaned = clean_title(title)
            if cleaned and cleaned ~= entry.title then
                entry.title = cleaned
                terminal.set_label(bufnr, cleaned)
                save_registry()
            end
        end

        vim.defer_fn(poll, 2000)
    end

    vim.defer_fn(poll, 2000)
end

-- Codex never puts the conversation name in the terminal title (it shows the
-- bare thread UUID until a thread is explicitly renamed), but its state
-- database records each thread's title as the first user message. Read it
-- from there once the thread id is known.
local function find_codex_state_db()
    local newest, newest_time = nil, 0
    local pattern = vim.fs.joinpath(vim.env.HOME or "~", ".codex", "state_*.sqlite")
    for _, path in ipairs(vim.fn.glob(pattern, true, true)) do
        local mtime = vim.fn.getftime(path)
        if mtime > newest_time then
            newest, newest_time = path, mtime
        end
    end

    return newest
end

local codex_title_query = table.concat({
    "import sqlite3, sys",
    "try:",
    "    con = sqlite3.connect('file:' + sys.argv[1] + '?mode=ro', uri=True)",
    "    row = con.execute('select title from threads where id = ?', (sys.argv[2],)).fetchone()",
    "    print(row[0] if row and row[0] else '')",
    "except Exception:",
    "    print('')",
}, "\n")

local function watch_codex_title(bufnr, key)
    local attempts = 0

    local function poll()
        local entry = entries[key]
        if exiting or not entry or not entry.id or entry.title or not buffer_alive(bufnr) then
            return
        end

        local db = M.codex_state_db or find_codex_state_db()
        if not db then
            return
        end

        vim.system({ "python3", "-c", codex_title_query, db, entry.id }, { text = true }, vim.schedule_wrap(function(result)
            local title = clean_title(vim.trim(result.stdout or ""))
            entry = entries[key]
            if title and entry and not entry.title then
                entry.title = title
                if buffer_alive(bufnr) then
                    terminal.set_label(bufnr, title)
                end
                save_registry()
                return
            end

            attempts = attempts + 1
            if attempts < 200 and not exiting then
                vim.defer_fn(poll, 3000)
            end
        end))
    end

    vim.defer_fn(poll, 3000)
end

local function newest_codex_rollout(min_mtime)
    local newest_path, newest_time = nil, min_mtime or 0

    for _, path in ipairs(vim.fn.globpath(M.codex_sessions_dir, "**/rollout-*.jsonl", true, true)) do
        local mtime = vim.fn.getftime(path)
        if mtime > newest_time then
            newest_path, newest_time = path, mtime
        end
    end

    return newest_path
end

local uuid_pattern = "(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)%.jsonl$"

local function watch_codex_id(bufnr, key, spawn_time)
    local attempts = 0

    local function poll()
        local entry = entries[key]
        if exiting or not entry or entry.id or not buffer_alive(bufnr) then
            return
        end

        local path = newest_codex_rollout(spawn_time - 1)
        local id = path and path:match(uuid_pattern) or nil
        if id then
            entry.id = id
            save_registry()
            watch_codex_title(bufnr, key)
            return
        end

        attempts = attempts + 1
        if attempts < 40 then
            vim.defer_fn(poll, 1000)
        end
    end

    vim.defer_fn(poll, 1000)
end

-- claude has no setting to skip its "do you trust this workspace?" dialog
-- (verified against docs); pre-marking the cwd as trusted in its state file
-- before launch is the only way. Small race if another claude instance
-- rewrites ~/.claude.json concurrently; worst case the dialog shows once.
local function trust_claude_workspace(cwd)
    local path = vim.fs.joinpath(vim.env.HOME or "~", ".claude.json")
    if vim.fn.filereadable(path) ~= 1 then
        return
    end

    local ok, state = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
    if not ok or type(state) ~= "table" then
        return
    end

    local project = type(state.projects) == "table" and state.projects[cwd] or nil
    if type(project) == "table" and project.hasTrustDialogAccepted == true then
        return
    end

    state.projects = type(state.projects) == "table" and state.projects or {}
    state.projects[cwd] = type(project) == "table" and project or vim.empty_dict()
    state.projects[cwd].hasTrustDialogAccepted = true
    vim.fn.writefile({ vim.json.encode(state) }, path)
end

function M.prepare_workspace(kind, cwd)
    if kind == "claude" then
        trust_claude_workspace(cwd)
    end
end

local function spawn(entry, resume)
    M.prepare_workspace(entry.kind, entry.cwd)

    local command = M.commands[entry.kind](entry, resume)
    local bufnr = terminal.open_command(command, entry_label(entry), { cwd = entry.cwd, ai_kind = entry.kind })
    if not bufnr then
        return nil
    end

    terminal.set_prompt_jump_keymaps(bufnr)

    entry.last_used = os.time()
    entries[entry.key] = entry
    buffers[bufnr] = entry.key
    if resume then
        pending_resumes[bufnr] = vim.uv.hrtime()
    end
    save_registry()

    if entry.kind == "codex" then
        if not entry.id then
            watch_codex_id(bufnr, entry.key, os.time())
        elseif not entry.title then
            watch_codex_title(bufnr, entry.key)
        end
    else
        watch_title(bufnr, entry.key)
    end

    return bufnr
end

function M.open(kind, cwd)
    if not M.ensure_available(kind) then
        return
    end

    local key = generate_uuid()
    local entry = {
        key = key,
        kind = kind,
        id = kind == "claude" and key or nil,
        cwd = cwd or vim.fn.getcwd(),
        title = nil,
        last_used = os.time(),
    }

    return spawn(entry, false)
end

function M.is_ai_buffer(bufnr)
    return buffer_alive(bufnr) and vim.b[bufnr].eltoto_ai_kind ~= nil
end

local function live_ai_buffers()
    local list = {}
    for bufnr in pairs(buffers) do
        if buffer_alive(bufnr) then
            list[#list + 1] = bufnr
        end
    end

    table.sort(list, function(a, b)
        local ka, kb = buffers[a], buffers[b]
        local ea = ka and entries[ka] or nil
        local eb = kb and entries[kb] or nil
        return (ea and ea.last_used or 0) > (eb and eb.last_used or 0)
    end)
    return list
end

function M.get_last_ai_buf()
    if M.is_ai_buffer(last_ai_bufnr or -1) then
        return last_ai_bufnr
    end
    local live = live_ai_buffers()
    return live[1]
end

local function focus_ai(bufnr)
    if not buffer_alive(bufnr) then
        return false
    end

    local ok = pcall(vim.api.nvim_set_current_buf, bufnr)
    if ok then
        vim.cmd.startinsert()
    end
    return ok
end

-- <leader>m: like <leader>t but for AI buffers. From a non-AI buffer, jump to
-- the last AI buffer used (or offer to spawn one); from an AI buffer, jump
-- back to wherever the toggle came from.
function M.toggle()
    local current = vim.api.nvim_get_current_buf()

    if M.is_ai_buffer(current) then
        local target = toggle_return_bufnr
        if not (target and vim.api.nvim_buf_is_valid(target) and vim.fn.buflisted(target) == 1 and not M.is_ai_buffer(target)) then
            target = require("eltoto.buffers").get_edit_return_buf()
        end
        if target then
            pcall(vim.api.nvim_set_current_buf, target)
        end
        return
    end

    toggle_return_bufnr = current

    local target_ai = M.get_last_ai_buf()
    if target_ai and focus_ai(target_ai) then
        return
    end

    M.new_session()
end

-- <leader>M: pick a harness and spawn a fresh AI session buffer.
function M.new_session()
    local current = vim.api.nvim_get_current_buf()
    if not M.is_ai_buffer(current) then
        toggle_return_bufnr = current
    end

    local kinds = { "claude", "codex" }
    require("eltoto.ui.picker").select("New AI session:", kinds, function(index)
        M.open(kinds[index])
    end)
end

local function restorable_entries(scope_cwd)
    local scope = scope_cwd and vim.fs.normalize(scope_cwd) or nil
    local list = {}
    for key, entry in pairs(entries) do
        if not entry_is_alive(key)
            and entry_is_restorable(entry)
            and (not scope or vim.fs.normalize(entry.cwd or "") == scope)
        then
            list[#list + 1] = entry
        end
    end

    table.sort(list, function(a, b)
        return (a.last_used or 0) > (b.last_used or 0)
    end)

    return list
end

-- Restores cached sessions (scoped to a directory when given), oldest first so
-- the most recent one ends up in the current window. Returns the most recent
-- restored buffer and count.
local function restore_cached(scope_cwd)
    local list = restorable_entries(scope_cwd)
    local focus = nil

    for i = #list, 1, -1 do
        local bufnr = spawn(list[i], true)
        if bufnr and i == 1 then
            focus = bufnr
        end
    end

    return focus, #list
end

-- <leader>n: picker over the open AI buffers (named as in the tabline) plus
-- cached sessions, which are resumed on selection.
function M.pick()
    local live = live_ai_buffers()
    local cached = restorable_entries()

    if #live == 0 and #cached == 0 then
        vim.notify("No AI harness sessions open or cached", vim.log.levels.INFO)
        return
    end

    local labels = {}
    local actions = {}

    for _, bufnr in ipairs(live) do
        local label = terminal.label_for_buf(bufnr) or vim.fs.basename(vim.api.nvim_buf_get_name(bufnr))
        labels[#labels + 1] = string.format("%2d. %s", #labels + 1, label)
        actions[#actions + 1] = function()
            focus_ai(bufnr)
        end
    end

    for _, entry in ipairs(cached) do
        local label = entry.title or ("Unnamed " .. entry.kind)
        labels[#labels + 1] = string.format("%2d. %s (cached)", #labels + 1, label)
        actions[#actions + 1] = function()
            spawn(entry, true)
        end
    end

    require("eltoto.ui.picker").select("AI sessions:", labels, function(index)
        local current = vim.api.nvim_get_current_buf()
        if not M.is_ai_buffer(current) then
            toggle_return_bufnr = current
        end
        actions[index]()
    end)
end

function M.restore_here()
    local focus, count = restore_cached(vim.fn.getcwd())
    if count == 0 then
        vim.notify("No cached AI harness sessions to restore for this directory", vim.log.levels.INFO)
        return
    end

    vim.notify(("Restored %d AI harness session(s)"):format(count))
    return focus
end

local function forget_buffer(bufnr, remove_entry)
    local key = buffers[bufnr]
    pending_resumes[bufnr] = nil
    if not key then
        return
    end

    buffers[bufnr] = nil
    if remove_entry and entries[key] then
        entries[key] = nil
        save_registry()
    end
end

-- Kills the AI buffer's process, wipes the buffer, and drops the session from
-- the registry (a kill is permanent, unlike qq which keeps it restorable).
local function kill_buffer(bufnr)
    local label = terminal.label_for_buf(bufnr) or vim.fs.basename(vim.api.nvim_buf_get_name(bufnr))

    if bufnr == vim.api.nvim_get_current_buf() then
        local target = require("eltoto.buffers").get_edit_return_buf()
        if target then
            pcall(vim.api.nvim_set_current_buf, target)
        end
    end

    forget_buffer(bufnr, true)
    if vim.api.nvim_buf_is_valid(bufnr) then
        pcall(vim.cmd.bwipeout, { args = { tostring(bufnr) }, bang = true })
    end

    return label
end

-- <leader>nk: kill the current AI buffer, or pick a live one when the current
-- buffer is not a registered AI session. Mirrors
-- processes.kill_current_or_select. Workspace agents are not registered here;
-- they are shpool sessions and belong to <leader>pk.
function M.kill_current_or_select()
    local current = vim.api.nvim_get_current_buf()
    if buffers[current] then
        vim.notify("Killed AI session '" .. kill_buffer(current) .. "'")
        return
    end

    local live = live_ai_buffers()
    if #live == 0 then
        vim.notify("No AI harness sessions open", vim.log.levels.INFO)
        return
    end

    local labels = {}
    for i, bufnr in ipairs(live) do
        local label = terminal.label_for_buf(bufnr) or vim.fs.basename(vim.api.nvim_buf_get_name(bufnr))
        labels[i] = string.format("%2d. %s", i, label)
    end

    require("eltoto.ui.picker").select("Kill AI session:", labels, function(index)
        local bufnr = live[index]
        if M.is_ai_buffer(bufnr) then
            vim.notify("Killed AI session '" .. kill_buffer(bufnr) .. "'")
        end
    end)
end

-- <leader>nK: kill every live AI buffer. Cached (non-live) sessions are not
-- running anything and stay restorable.
function M.kill_all()
    local live = live_ai_buffers()
    if #live == 0 then
        vim.notify("No AI harness sessions open", vim.log.levels.INFO)
        return
    end

    local names = {}
    for _, bufnr in ipairs(live) do
        names[#names + 1] = kill_buffer(bufnr)
    end

    vim.notify("Killed AI sessions: " .. table.concat(names, ", "))
end

local function should_autostart()
    return vim.fn.argc() == 0
        and #vim.api.nvim_list_uis() > 0
        and not vim.g.eltoto_reading_stdin
        and not vim.g.eltoto_disable_ai_autostart
end

function M.setup()
    load_registry()

    local group = vim.api.nvim_create_augroup("EltotoAISessions", { clear = true })

    vim.api.nvim_create_user_command("Claude", function()
        M.open("claude")
    end, { desc = "Open a new Claude Code session in a terminal buffer" })
    vim.api.nvim_create_user_command("Codex", function()
        M.open("codex")
    end, { desc = "Open a new Codex session in a terminal buffer" })
    vim.api.nvim_create_user_command("AIRestore", M.restore_here, {
        desc = "Restore cached AI harness sessions born in the current directory",
    })

    vim.api.nvim_create_autocmd("StdinReadPre", {
        group = group,
        callback = function()
            vim.g.eltoto_reading_stdin = true
        end,
    })

    vim.api.nvim_create_autocmd("BufEnter", {
        group = group,
        callback = function(event)
            local key = buffers[event.buf]
            local entry = key and entries[key] or nil
            if entry then
                entry.last_used = os.time()
                last_ai_bufnr = event.buf
            end
        end,
    })

    -- Process exit (Ctrl-C / quit at the harness prompt) closes the buffer
    -- and drops the session from the cache. A buffer closed with qq is
    -- already wiped by the time the scheduled check runs, so its session
    -- stays cached and restorable. Ctrl-C mid-turn only interrupts the
    -- harness; no process exit, so nothing fires here.
    vim.api.nvim_create_autocmd("TermClose", {
        group = group,
        callback = function(event)
            if not buffers[event.buf] or exiting or vim.v.exiting ~= vim.NIL then
                return
            end

            local exit_status = vim.v.event.status
            vim.schedule(function()
                if not vim.api.nvim_buf_is_valid(event.buf) then
                    forget_buffer(event.buf, false)
                    return
                end

                local resume_time = pending_resumes[event.buf]
                local was_failed_resume = resume_time ~= nil
                    and exit_status ~= 0
                    and (vim.uv.hrtime() - resume_time) < 5e9
                local key = buffers[event.buf]
                local failed_entry = was_failed_resume and entries[key] or nil

                forget_buffer(event.buf, true)

                if was_failed_resume then
                    pcall(vim.api.nvim_buf_delete, event.buf, { force = true })
                    if failed_entry and vim.fn.executable(failed_entry.kind) == 1 then
                        vim.defer_fn(function()
                            local bufnr = M.open(failed_entry.kind, failed_entry.cwd)
                            if bufnr then
                                vim.defer_fn(function()
                                    if vim.api.nvim_buf_is_valid(bufnr) then
                                        pcall(vim.api.nvim_set_current_buf, bufnr)
                                        vim.cmd.startinsert()
                                    end
                                end, 400)
                            end
                        end, 50)
                    end
                else
                    -- Prefer an adjacent AI buffer; handles both the normal case and
                    -- the case where nvim auto-switched away before this callback ran.
                    local bufmod = require("eltoto.buffers")
                    local ai_target = bufmod.nearest_ai_buf(event.buf)
                    if ai_target then
                        local cur = vim.api.nvim_get_current_buf()
                        if cur == event.buf or vim.b[cur].eltoto_ai_kind == nil then
                            pcall(vim.api.nvim_set_current_buf, ai_target)
                            vim.cmd.startinsert()
                        end
                        pcall(vim.api.nvim_buf_delete, event.buf, { force = true })
                    elseif vim.api.nvim_get_current_buf() == event.buf then
                        bufmod.quit_current_or_window()
                    else
                        pcall(vim.api.nvim_buf_delete, event.buf, { force = true })
                    end
                end
            end)
        end,
    })

    vim.api.nvim_create_autocmd("BufWipeout", {
        group = group,
        callback = function(event)
            forget_buffer(event.buf, false)
        end,
    })

    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = group,
        callback = function()
            exiting = true
            save_registry()
        end,
    })

    -- On a plain `vim` invocation the AI terminal is the primary surface.
    local function focus_ai_buffer(bufnr)
        if not buffer_alive(bufnr) then
            return
        end

        if vim.api.nvim_get_current_buf() ~= bufnr then
            pcall(vim.api.nvim_set_current_buf, bufnr)
        end
        if vim.api.nvim_get_current_buf() == bufnr then
            vim.cmd.startinsert()
        end
    end

    vim.api.nvim_create_autocmd("VimEnter", {
        group = group,
        callback = function()
            vim.defer_fn(function()
                if not should_autostart() then
                    return
                end

                local bufnr, count = restore_cached(vim.fn.getcwd())
                if count > 0 then
                    vim.notify(("Restored %d AI harness session(s)"):format(count))
                elseif vim.fn.executable("claude") == 1 then
                    bufnr = M.open("claude")
                end

                if bufnr then
                    vim.defer_fn(function()
                        focus_ai_buffer(bufnr)
                    end, 400)
                end
            end, 100)
        end,
    })
end

return M
