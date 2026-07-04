local M = {}

local process_backend = require("eltoto.process_backend")
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

local function run_git(path, args, callback)
    local command = { "git", "-C", path }
    vim.list_extend(command, args)
    vim.system(
        command,
        { text = true },
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

local function preferred_default_ref(path, branch, callback)
    local local_ref = "refs/heads/" .. branch
    local remote_ref = "refs/remotes/origin/" .. branch
    run_git(path, { "rev-parse", "--verify", local_ref .. "^{commit}" }, function(local_commit)
        run_git(path, { "rev-parse", "--verify", remote_ref .. "^{commit}" }, function(remote_commit)
            if not remote_commit then
                if local_commit then
                    callback(local_ref)
                else
                    callback(nil, "default branch refs are unavailable")
                end
                return
            end
            if not local_commit then
                callback(remote_ref)
                return
            end
            run_git(path, { "rev-list", "--left-right", "--count", local_ref .. "..." .. remote_ref }, function(counts, detail)
                if not counts then
                    callback(nil, detail)
                    return
                end
                local local_ahead, remote_ahead = counts:match("(%d+)%s+(%d+)")
                if not local_ahead then
                    callback(nil, "cannot compare local and remote default branches")
                    return
                end
                if tonumber(local_ahead) > 0 and tonumber(remote_ahead) == 0 then
                    callback(local_ref)
                else
                    callback(remote_ref)
                end
            end)
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

        run_git(path, { "symbolic-ref", "--short", "refs/remotes/origin/HEAD" }, function(remote_head)
            local branch = remote_head and vim.trim(remote_head):match("^origin/(.+)$") or nil
            if branch then
                preferred_default_ref(path, branch, callback)
                return
            end
            local_default_branch(path, function(local_branch, detail)
                if not local_branch then
                    callback(nil, detail)
                    return
                end
                preferred_default_ref(path, local_branch, callback)
            end)
        end)
    end)
end

local function hash_untracked(path, files, callback)
    local hashes = {}
    local index = 1
    local function next_file()
        local file = files[index]
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
            index = index + 1
            next_file()
        end)
    end
    next_file()
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

local function open_session(display_name, path, create)
    local exists = process_backend.session_exists(display_name)
    if create and exists then
        vim.notify("treehouse: session already exists: " .. display_name, vim.log.levels.ERROR)
        return false
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
    terminal.configure_persistent_buffer(bufnr)

    refresh_git_cache(display_name)
    return true
end

local function finish_acquisition(display_name, path)
    local opened = open_session(display_name, path, true)
    reserved_sessions[display_name] = nil
    if opened then return end

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
