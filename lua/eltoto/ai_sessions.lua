local M = {}

local terminal = require("eltoto.terminal")

-- Registry of AI harness sessions (claude, codex) running in plain terminal
-- buffers. Identity is pinned at spawn time: claude via --session-id, codex by
-- watching its rollout file appear. Entries survive nvim exits and crashes;
-- they are removed only when a session is quit naturally (process exit or
-- buffer close inside nvim), so whatever remains is restorable.

local entries = {}   -- key -> entry { key, kind, id, cwd, title, last_used }
local buffers = {}   -- bufnr -> key
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
        if resume then
            return command({ "env", "CLAUDE_CODE_NO_FLICKER=0", "claude", "--resume", entry.id }, claude_args)
        end
        return command({ "env", "CLAUDE_CODE_NO_FLICKER=0", "claude", "--session-id", entry.id }, claude_args)
    end,
    codex = function(entry, resume)
        if resume then
            if entry.id then
                return command({ "codex", "resume", entry.id }, codex_args)
            end
            return command({ "codex", "resume", "--last" }, codex_args)
        end
        return command({ "codex" }, codex_args)
    end,
}

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

local function save_registry()
    local list = vim.tbl_values(entries)
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

-- Lines where the user typed a prompt: ❯ (claude), › (codex), or a plain >.
-- No semantic markers exist in these transcripts (the TUIs don't emit OSC 133
-- prompt marks), so a pattern over the rendered text is the mechanism.
M.prompt_pattern = [[\v^\s*[❯›>]\s]]

local function prompt_jump(direction)
    return function()
        if vim.fn.search(M.prompt_pattern, direction < 0 and "bW" or "W") ~= 0 then
            vim.cmd("normal! zz")
        end
    end
end

local function set_prompt_jump_keymaps(bufnr)
    vim.keymap.set("n", "[a", prompt_jump(-1), {
        buffer = bufnr,
        silent = true,
        desc = "Jump to previous prompt",
    })
    vim.keymap.set("n", "]a", prompt_jump(1), {
        buffer = bufnr,
        silent = true,
        desc = "Jump to next prompt",
    })
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

local function spawn(entry, resume)
    if entry.kind == "claude" then
        trust_claude_workspace(entry.cwd)
    end

    local command = M.commands[entry.kind](entry, resume)
    local bufnr = terminal.open_command(command, entry_label(entry), { cwd = entry.cwd, ai_kind = entry.kind })
    if not bufnr then
        return nil
    end

    set_prompt_jump_keymaps(bufnr)

    entry.last_used = os.time()
    entries[entry.key] = entry
    buffers[bufnr] = entry.key
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

function M.open(kind)
    if not M.commands[kind] then
        vim.notify("Unknown AI harness: " .. tostring(kind), vim.log.levels.ERROR)
        return
    end

    if vim.fn.executable(kind) ~= 1 then
        vim.notify(kind .. " is not installed or not on PATH", vim.log.levels.ERROR)
        return
    end

    local key = generate_uuid()
    local entry = {
        key = key,
        kind = kind,
        id = kind == "claude" and key or nil,
        cwd = vim.fn.getcwd(),
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

    table.sort(list)
    return list
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

-- <leader>A: like <leader>t but for AI buffers. From a non-AI buffer, jump to
-- the last AI buffer used (or offer to spawn one); from an AI buffer, jump
-- back to wherever the toggle came from.
function M.toggle()
    local current = vim.api.nvim_get_current_buf()

    if M.is_ai_buffer(current) then
        local target = toggle_return_bufnr
        if not (target and vim.api.nvim_buf_is_valid(target) and vim.fn.buflisted(target) == 1 and not M.is_ai_buffer(target)) then
            target = require("eltoto.buffers").get_last_edit_buf()
        end
        if target then
            pcall(vim.api.nvim_set_current_buf, target)
        end
        return
    end

    toggle_return_bufnr = current

    if M.is_ai_buffer(last_ai_bufnr or -1) and focus_ai(last_ai_bufnr) then
        return
    end

    local live = live_ai_buffers()
    if live[1] and focus_ai(live[1]) then
        return
    end

    M.new_session()
end

-- <leader>A: pick a harness and spawn a fresh AI session buffer.
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
        if not entry_is_alive(key) and (not scope or vim.fs.normalize(entry.cwd or "") == scope) then
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

-- <leader>aa: picker over the open AI buffers (named as in the tabline) plus
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
    if not key then
        return
    end

    buffers[bufnr] = nil
    if remove_entry and entries[key] then
        entries[key] = nil
        save_registry()
    end
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

            vim.schedule(function()
                if not vim.api.nvim_buf_is_valid(event.buf) then
                    forget_buffer(event.buf, false)
                    return
                end

                forget_buffer(event.buf, true)
                if vim.api.nvim_get_current_buf() == event.buf then
                    require("eltoto.buffers").quit_current_or_window()
                else
                    pcall(vim.api.nvim_buf_delete, event.buf, { force = true })
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
