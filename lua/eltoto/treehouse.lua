local M = {}

local process_backend = require("eltoto.process_backend")
local processes = require("eltoto.processes")
local ai_sessions = require("eltoto.ai_sessions")
local terminal = require("eltoto.terminal")
local ui_input = require("eltoto.ui.input")
local ui_picker = require("eltoto.ui.picker")

local TH_PREFIX = "th:"

-- display_name -> absolute workspace path; lost on restart (use <leader>fs to recover)
local workspace_paths = {}

local reserved_sessions = {}
local disposable_sequence = 0

-- display_name -> { branch, dirty } updated async on BufEnter
local git_cache = {}

local function run_git(path, args, callback, stdin)
    local command = { "git", "-C", path }
    vim.list_extend(command, args)
    vim.system(
        command,
        { text = true, stdin = stdin },
        function(result)
            vim.schedule(function()
                if result.code == 0 then
                    callback(result.stdout or "")
                    return
                end

                local detail = vim.trim(result.stderr or "")
                if detail == "" then detail = "exit code " .. result.code end
                callback(nil, detail)
            end)
        end
    )
end

local function git_status(path, callback)
    run_git(path, { "status", "--short", "--untracked-files=all" }, callback)
end

local function local_default_branch(path, callback)
    run_git(path, { "worktree", "list", "--porcelain" }, function(worktrees, detail)
        if not worktrees then
            callback(nil, detail)
            return
        end
        local main_path = worktrees:match("^worktree ([^\r\n]+)")
        if not main_path then
            callback(nil, "cannot determine the main worktree")
            return
        end
        run_git(main_path, { "symbolic-ref", "--short", "HEAD" }, function(branch, ref_detail)
            branch = branch and vim.trim(branch) or nil
            if not branch or branch == "" then
                callback(nil, ref_detail or "cannot determine the local default branch")
                return
            end
            callback(branch)
        end)
    end)
end

local function default_branch_ref(path, callback)
    run_git(path, { "remote" }, function(remotes, remote_detail)
        if not remotes then
            callback(nil, remote_detail)
            return
        end

        local has_origin = false
        for remote in remotes:gmatch("[^\r\n]+") do
            has_origin = has_origin or vim.trim(remote) == "origin"
        end
        if not has_origin then
            local_default_branch(path, function(branch, detail)
                callback(branch and "refs/heads/" .. branch or nil, detail)
            end)
            return
        end

        run_git(path, { "ls-remote", "--symref", "origin", "HEAD" }, function(remote_head, head_detail)
            if not remote_head then
                callback(nil, head_detail)
                return
            end
            local branch_ref = remote_head:match("ref:%s+(refs/heads/[^%s]+)%s+HEAD")
            if not branch_ref then
                callback(nil, "cannot determine origin's current default branch")
                return
            end
            local branch = branch_ref:sub(#"refs/heads/" + 1)
            local remote_ref = "refs/remotes/origin/" .. branch
            run_git(path, { "fetch", "--no-tags", "origin", "+" .. branch_ref .. ":" .. remote_ref }, function(_, fetch_detail)
                if fetch_detail then
                    callback(nil, fetch_detail)
                    return
                end
                callback(remote_ref)
            end)
        end)
    end)
end

local function hash_untracked(path, files, callback)
    local hashes = {}
    local batch = {}
    local exceptional = {}
    for _, file in ipairs(files) do
        if file:find("\n", 1, true) or vim.startswith(file, '"') then
            exceptional[#exceptional + 1] = file
        else
            batch[#batch + 1] = file
        end
    end

    local function hash_exceptional(index)
        local file = exceptional[index]
        if not file then
            callback(table.concat(hashes, "\0"))
            return
        end
        run_git(path, { "hash-object", "--no-filters", "--", file }, function(hash, detail)
            if not hash then
                callback(nil, detail)
                return
            end
            hashes[#hashes + 1] = file
            hashes[#hashes + 1] = vim.trim(hash)
            hash_exceptional(index + 1)
        end)
    end

    if #batch == 0 then
        hash_exceptional(1)
        return
    end

    run_git(path, { "hash-object", "--no-filters", "--stdin-paths" }, function(output, detail)
        if not output then
            callback(nil, detail)
            return
        end
        local batch_hashes = vim.split(output, "\n", { plain = true, trimempty = true })
        if #batch_hashes ~= #batch then
            callback(nil, "unexpected hash count for untracked files")
            return
        end
        for index, file in ipairs(batch) do
            hashes[#hashes + 1] = file
            hashes[#hashes + 1] = batch_hashes[index]
        end
        hash_exceptional(1)
    end, table.concat(batch, "\n") .. "\n")
end

local function workspace_snapshot(path, callback)
    git_status(path, function(status, detail)
        if not status then
            callback(nil, detail)
            return
        end
        default_branch_ref(path, function(base_ref, base_detail)
            if not base_ref then
                callback(nil, base_detail)
                return
            end
            run_git(path, { "rev-parse", "--verify", "HEAD^{commit}" }, function(head, head_detail)
                if not head then
                    callback(nil, head_detail)
                    return
                end
                run_git(path, { "rev-parse", "--verify", base_ref .. "^{commit}" }, function(base, ref_detail)
                    if not base then
                        callback(nil, ref_detail)
                        return
                    end
                    run_git(path, { "log", "--format=%h %s", base_ref .. "..HEAD" }, function(commits, log_detail)
                        if not commits then
                            callback(nil, log_detail)
                            return
                        end
                        run_git(path, { "diff", "--no-ext-diff", "--no-textconv", "--binary", "--cached", "HEAD" }, function(staged, staged_detail)
                            if not staged then
                                callback(nil, staged_detail)
                                return
                            end
                            run_git(path, { "diff", "--no-ext-diff", "--no-textconv", "--binary" }, function(unstaged, unstaged_detail)
                                if not unstaged then
                                    callback(nil, unstaged_detail)
                                    return
                                end
                                run_git(path, { "ls-files", "--others", "--exclude-standard", "-z" }, function(raw_files, files_detail)
                                    if not raw_files then
                                        callback(nil, files_detail)
                                        return
                                    end
                                    local files = vim.split(raw_files, "\0", { plain = true, trimempty = true })
                                    hash_untracked(path, files, function(untracked, hash_detail)
                                        if not untracked then
                                            callback(nil, hash_detail)
                                            return
                                        end
                                        callback({
                                            status = status,
                                            base_ref = base_ref,
                                            commits = commits,
                                            fingerprint = table.concat({
                                                vim.trim(head),
                                                vim.trim(base),
                                                staged,
                                                unstaged,
                                                untracked,
                                            }, "\0"),
                                        })
                                    end)
                                end)
                            end)
                        end)
                    end)
                end)
            end)
        end)
    end)
end

local function is_th_session(name)
    return vim.startswith(name, TH_PREFIX)
end

local function buffer_session(bufnr)
    local tagged = vim.b[bufnr].eltoto_treehouse_session
    if type(tagged) == "string" and is_th_session(tagged) then
        return tagged
    end

    local buf_name = vim.api.nvim_buf_get_name(bufnr)
    return buf_name:match("/P:(" .. vim.pesc(TH_PREFIX) .. ".+)$")
        or buf_name:match("^P:(" .. vim.pesc(TH_PREFIX) .. ".+)$")
end

local function th_sessions()
    local result = {}
    for _, item in ipairs(process_backend.managed_sessions()) do
        if is_th_session(item.name) then
            result[#result + 1] = item
        end
    end
    return result
end

local function refresh_git_cache(display_name)
    local path = workspace_paths[display_name]
    if not path then return end
    vim.system({ "git", "-C", path, "branch", "--show-current" }, { text = true }, function(br)
        local branch = vim.trim(br.stdout or "")
        git_status(path, function(status)
            if workspace_paths[display_name] ~= path then return end
            if not status then
                git_cache[display_name] = nil
                return
            end
            git_cache[display_name] = {
                branch = branch ~= "" and branch or "?",
                dirty = vim.trim(status) ~= "",
            }
        end)
    end)
end

local function backend_available()
    if process_backend.available() then
        return true
    end

    process_backend.notify_missing()
    return false
end

local function treehouse_available()
    if vim.fn.executable("treehouse") == 1 then
        return true
    end

    vim.notify("treehouse is required (install it from github.com/kunchenguid/treehouse)", vim.log.levels.WARN)
    return false
end

local function session_name_in_use(display_name)
    return reserved_sessions[display_name]
        or workspace_paths[display_name] ~= nil
        or process_backend.session_exists(display_name)
end

local function reserve_session(display_name)
    if session_name_in_use(display_name) then
        vim.notify("treehouse: session already exists: " .. display_name, vim.log.levels.WARN)
        return false
    end

    reserved_sessions[display_name] = true
    return true
end

local function next_disposable_name()
    local display_name
    repeat
        disposable_sequence = disposable_sequence + 1
        display_name = string.format("%stmp-%d-%d", TH_PREFIX, os.time(), disposable_sequence)
    until not session_name_in_use(display_name)
    return display_name
end

local function quiesce_session(display_name, callback)
    if not process_backend.session_exists(display_name) then
        callback(true)
        return
    end

    vim.system(process_backend.command({ "kill", process_backend.session_name(display_name) }), { text = true }, function(result)
        vim.schedule(function()
            if result.code == 0 then
                callback(true)
                return
            end
            local detail = vim.trim((result.stdout or "") .. (result.stderr or ""))
            callback(nil, detail ~= "" and detail or "exit code " .. result.code)
        end)
    end)
end

local function open_session(display_name, path, create)
    local exists = process_backend.session_exists(display_name)
    if create and exists then
        vim.notify("treehouse: session already exists: " .. display_name, vim.log.levels.ERROR)
        return false
    end

    local existing_buf = terminal.find_persistent_buffer(display_name)
    if existing_buf then
        if path then
            workspace_paths[display_name] = path
            processes.register_session_cwd(display_name, path)
        end
        terminal.focus(existing_buf)
        refresh_git_cache(display_name)
        return existing_buf
    end

    if not exists and (not path or vim.fn.isdirectory(path) ~= 1) then
        vim.notify("treehouse: path unknown for new session " .. display_name, vim.log.levels.ERROR)
        return false
    end

    if path then
        workspace_paths[display_name] = path
    end

    local bufnr = terminal.open_command(
        process_backend.attach_command(display_name, exists and nil or path),
        "P:" .. display_name,
        exists and nil or { cwd = path }
    )
    if not bufnr then
        if workspace_paths[display_name] == path then
            workspace_paths[display_name] = nil
        end
        return false
    end
    vim.b[bufnr].eltoto_treehouse_session = display_name
    terminal.configure_persistent_buffer(bufnr, display_name)
    if path then
        processes.register_session_cwd(display_name, path)
    end

    refresh_git_cache(display_name)
    return bufnr
end

-- Offer to start an agent in a freshly acquired workspace. Esc/q keeps the
-- plain shell. Never offered on reattach: the shpool session keeps whatever
-- was running.
local function offer_agent(bufnr, path)
    local kinds = { "claude", "codex" }

    local function focus_terminal()
        if not terminal.is_terminal(bufnr) then
            return
        end

        local winid = vim.fn.bufwinid(bufnr)
        if winid ~= -1 then
            pcall(vim.api.nvim_set_current_win, winid)
        else
            pcall(vim.api.nvim_set_current_buf, bufnr)
        end

        if vim.api.nvim_get_current_buf() == bufnr then
            vim.cmd.startinsert()
        end
    end

    ui_picker.select("Workspace agent (Esc: plain shell):", kinds, function(index)
        if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].channel == 0 then
            return
        end

        local kind = kinds[index]
        if not ai_sessions.ensure_available(kind) then
            focus_terminal()
            return
        end
        ai_sessions.prepare_workspace(kind, path)
        vim.api.nvim_chan_send(vim.bo[bufnr].channel, ai_sessions.shell_command(kind) .. "\r")
        focus_terminal()
    end, focus_terminal)
end

local function finish_acquisition(display_name, path)
    local opened = open_session(display_name, path, true)
    reserved_sessions[display_name] = nil
    if opened then
        offer_agent(opened, path)
        return
    end

    vim.system({ "treehouse", "return", "--force", path }, { text = true }, function(result)
        if result.code == 0 then return end
        vim.schedule(function()
            vim.notify("treehouse: failed to release unused lease: " .. vim.trim(result.stderr or ""), vim.log.levels.ERROR)
        end)
    end)
end

-- <leader>fa — quick disposable lease, auto-named
function M.acquire_disposable()
    if not treehouse_available() or not backend_available() then return end

    local display_name = next_disposable_name()
    if not reserve_session(display_name) then return end
    vim.system({ "treehouse", "get", "--lease" }, { text = true }, function(result)
        vim.schedule(function()
            if result.code ~= 0 then
                reserved_sessions[display_name] = nil
                vim.notify("treehouse: " .. vim.trim(result.stderr or "failed"), vim.log.levels.ERROR)
                return
            end
            local path = vim.trim(result.stdout or "")
            if path == "" then
                reserved_sessions[display_name] = nil
                vim.notify("treehouse: no path returned", vim.log.levels.ERROR)
                return
            end
            finish_acquisition(display_name, path)
        end)
    end)
end

-- <leader>fl — named leased workspace
function M.acquire_leased()
    if not treehouse_available() or not backend_available() then return end

    ui_input.centered({ title = " Treehouse Task ", prompt = "Task name: " }, function(input)
        if not input then return end
        local name = vim.trim(input)
        if name == "" then return end

        local display_name = TH_PREFIX .. name
        if not reserve_session(display_name) then return end
        local args = { "treehouse", "get", "--lease", "--lease-holder", name }
        vim.system(args, { text = true }, function(result)
            vim.schedule(function()
                if result.code ~= 0 then
                    reserved_sessions[display_name] = nil
                    vim.notify("treehouse: " .. vim.trim(result.stderr or "failed"), vim.log.levels.ERROR)
                    return
                end
                local path = vim.trim(result.stdout or "")
                if path == "" then
                    reserved_sessions[display_name] = nil
                    vim.notify("treehouse: no path returned", vim.log.levels.ERROR)
                    return
                end
                finish_acquisition(display_name, path)
            end)
        end)
    end)
end

-- <leader>fs — treehouse status float
function M.status()
    if not treehouse_available() then return end

    vim.system({ "treehouse", "status" }, { text = true }, function(result)
        vim.schedule(function()
            local raw = (result.stdout or "") .. (result.stderr or "")
            local lines = vim.split(vim.trim(raw), "\n")

            local width = math.floor(vim.o.columns * 0.7)
            local height = math.min(#lines + 2, math.floor(vim.o.lines * 0.8))
            local buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
            vim.bo[buf].modifiable = false
            vim.bo[buf].bufhidden = "wipe"

            local win = vim.api.nvim_open_win(buf, true, {
                relative = "editor",
                width = width,
                height = height,
                row = math.max(math.floor((vim.o.lines - height) / 2) - 1, 0),
                col = math.max(math.floor((vim.o.columns - width) / 2), 0),
                style = "minimal",
                border = "rounded",
                title = " Treehouse Status ",
                title_pos = "center",
            })
            vim.wo[win].wrap = false
            vim.keymap.set("n", "q", function()
                if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
            end, { buffer = buf, silent = true })
        end)
    end)
end

-- <leader>fw — pick from active treehouse sessions
function M.pick()
    local sessions = th_sessions()
    if #sessions == 0 then
        vim.notify("No active treehouse workspaces", vim.log.levels.INFO)
        return
    end

    local labels = {}
    for i, item in ipairs(sessions) do
        local task = item.name:sub(#TH_PREFIX + 1)
        local cached = git_cache[item.name]
        local branch = cached and cached.branch or "?"
        local dirty = cached and cached.dirty and " *" or ""
        labels[i] = string.format("%-24s  %s%s", task, branch, dirty)
    end

    ui_picker.select("Treehouse Workspaces", labels, function(index)
        local item = sessions[index]
        if item then
            open_session(item.name, workspace_paths[item.name], false)
        end
    end)
end

-- <leader>fr — return leased workspace; shows git status, requires confirm
function M.return_workspace()
    if not treehouse_available() then return end

    local function do_return(display_name)
        local path = workspace_paths[display_name]
        if not path then
            vim.notify("treehouse: path unknown for " .. display_name .. " (use <leader>fs to check)", vim.log.levels.WARN)
            return
        end

        local task = display_name:sub(#TH_PREFIX + 1)
        local function inspect_and_confirm()
            workspace_snapshot(path, function(snapshot, detail)
                if not snapshot then
                    vim.notify("treehouse: failed to inspect workspace: " .. detail, vim.log.levels.ERROR)
                    return
                end

                local status_lines = vim.split(vim.trim(snapshot.status), "\n", { trimempty = true })
                local commit_lines = vim.split(vim.trim(snapshot.commits), "\n", { trimempty = true })
                local lines = { "Return workspace: " .. task, "", "  path: " .. path, "" }
                if #commit_lines > 0 then
                    lines[#lines + 1] = "  COMMITS NOT IN " .. snapshot.base_ref .. ":"
                    for _, l in ipairs(commit_lines) do
                        lines[#lines + 1] = "  " .. l
                    end
                    lines[#lines + 1] = ""
                end
                if #status_lines > 0 then
                    lines[#lines + 1] = "  UNCOMMITTED CHANGES:"
                    for _, l in ipairs(status_lines) do
                        lines[#lines + 1] = "  " .. l
                    end
                    lines[#lines + 1] = ""
                else
                    lines[#lines + 1] = "  working tree clean"
                    lines[#lines + 1] = ""
                end
                lines[#lines + 1] = "  r  confirm return   (workspace will be reset)"
                lines[#lines + 1] = "  q  cancel"

                local width = math.max(1, math.min(70, vim.o.columns - 8))
                local height = math.max(1, math.min(#lines, math.floor(vim.o.lines * 0.8)))
                local buf = vim.api.nvim_create_buf(false, true)
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
                vim.bo[buf].modifiable = false
                vim.bo[buf].bufhidden = "wipe"

                local win = vim.api.nvim_open_win(buf, true, {
                    relative = "editor",
                    width = width,
                    height = height,
                    row = math.max(math.floor((vim.o.lines - height) / 2) - 1, 0),
                    col = math.max(math.floor((vim.o.columns - width) / 2), 0),
                    style = "minimal",
                    border = "rounded",
                    title = " Return Workspace? ",
                    title_pos = "center",
                })
                vim.wo[win].wrap = false

                local function close()
                    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
                end

                local opts = { buffer = buf, silent = true, nowait = true }
                vim.keymap.set("n", "q", close, opts)
                vim.keymap.set("n", "<Esc>", close, opts)
                local checking = false
                vim.keymap.set("n", "r", function()
                    if checking then return end
                    checking = true
                    workspace_snapshot(path, function(current_snapshot, current_detail)
                        if not current_snapshot then
                            checking = false
                            vim.notify("treehouse: failed to inspect workspace: " .. current_detail, vim.log.levels.ERROR)
                            return
                        end
                        close()
                        if current_snapshot.fingerprint ~= snapshot.fingerprint then
                            vim.notify("treehouse: workspace changed; review the updated state", vim.log.levels.WARN)
                            inspect_and_confirm()
                            return
                        end

                        quiesce_session(display_name, function(quiesced, quiesce_detail)
                            if not quiesced then
                                vim.notify("treehouse: failed to stop workspace session: " .. quiesce_detail, vim.log.levels.ERROR)
                                return
                            end
                            workspace_snapshot(path, function(final_snapshot, final_detail)
                                if not final_snapshot then
                                    vim.notify("treehouse: failed to inspect quiesced workspace: " .. final_detail, vim.log.levels.ERROR)
                                    return
                                end
                                if final_snapshot.fingerprint ~= current_snapshot.fingerprint then
                                    vim.notify("treehouse: workspace changed while stopping its session; review the updated state", vim.log.levels.WARN)
                                    inspect_and_confirm()
                                    return
                                end

                                vim.system({ "treehouse", "return", "--force", path }, { text = true }, function(result)
                                    vim.schedule(function()
                                        if result.code ~= 0 then
                                            vim.notify("treehouse return failed: " .. vim.trim(result.stderr or ""), vim.log.levels.ERROR)
                                            return
                                        end
                                        workspace_paths[display_name] = nil
                                        git_cache[display_name] = nil
                                        vim.notify("Returned workspace: " .. task)
                                    end)
                                end)
                            end)
                        end)
                    end)
                end, opts)
            end)
        end

        inspect_and_confirm()
    end

    -- if current buffer is a treehouse session, use it directly
    local display_name = buffer_session(vim.api.nvim_get_current_buf())
    if display_name then
        do_return(display_name)
        return
    end

    -- otherwise pick
    local sessions = th_sessions()
    local included = {}
    for _, item in ipairs(sessions) do
        included[item.name] = true
    end
    for display_name in pairs(workspace_paths) do
        if is_th_session(display_name) and not included[display_name] then
            sessions[#sessions + 1] = { name = display_name }
        end
    end
    table.sort(sessions, function(a, b)
        return a.name < b.name
    end)
    if #sessions == 0 then
        vim.notify("No active treehouse workspaces", vim.log.levels.INFO)
        return
    end
    local labels = {}
    for i, item in ipairs(sessions) do
        labels[i] = string.format("%2d. %s", i, item.name:sub(#TH_PREFIX + 1))
    end
    ui_picker.select("Return which workspace?", labels, function(index)
        if sessions[index] then do_return(sessions[index].name) end
    end)
end

-- Branch for the current buffer's treehouse workspace, "?" while its cache is
-- loading, or nil when the buffer is not in a workspace.
function M.current_buf_branch()
    local display_name = buffer_session(vim.api.nvim_get_current_buf())
    if not display_name then return nil end
    local cached = git_cache[display_name]
    return cached and cached.branch or "?"
end

-- Filesystem path for a buffer's treehouse workspace, or nil when it is not in
-- one. Defaults to the current buffer.
function M.current_buf_workspace_path(bufnr)
    local display_name = buffer_session(bufnr or vim.api.nvim_get_current_buf())
    return display_name and workspace_paths[display_name] or nil
end

-- statusline component: call from lualine or raw statusline
-- returns "" when not in a treehouse buffer so it takes no space
function M.statusline()
    local display_name = buffer_session(vim.api.nvim_get_current_buf())
    if not display_name then return "" end

    local task = display_name:sub(#TH_PREFIX + 1)
    local cached = git_cache[display_name]
    if not cached then
        return "[TH: " .. task .. "]"
    end
    local dirty = cached.dirty and " *" or ""
    return string.format("[TH: %s | %s%s]", task, cached.branch, dirty)
end

-- Refresh cached Git branch and dirty state for every known workspace.
function M.refresh_all_git_caches()
    for display_name in pairs(workspace_paths) do
        refresh_git_cache(display_name)
    end
end

function M.setup()
    local group = vim.api.nvim_create_augroup("EltotoTreehouse", { clear = true })

    -- refresh git cache whenever a treehouse buffer is entered
    vim.api.nvim_create_autocmd("BufEnter", {
        group = group,
        callback = function(event)
            local display_name = buffer_session(event.buf)
            if display_name then
                refresh_git_cache(display_name)
            end
        end,
    })

    local map = vim.keymap.set
    local opts = { silent = true }
    map("n", "<leader>fa", M.acquire_disposable, vim.tbl_extend("force", opts, { desc = "Treehouse: acquire disposable workspace" }))
    map("n", "<leader>fl", M.acquire_leased,     vim.tbl_extend("force", opts, { desc = "Treehouse: acquire leased workspace" }))
    map("n", "<leader>fs", M.status,             vim.tbl_extend("force", opts, { desc = "Treehouse: status" }))
    map("n", "<leader>fw", M.pick,               vim.tbl_extend("force", opts, { desc = "Treehouse: workspace picker" }))
    map("n", "<leader>fr", M.return_workspace,   vim.tbl_extend("force", opts, { desc = "Treehouse: return leased workspace" }))
end

return M
