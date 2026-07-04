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
        vim.system({ "git", "-C", path, "status", "--short" }, { text = true }, function(st)
            git_cache[display_name] = {
                branch = branch ~= "" and branch or "?",
                dirty = vim.trim(st.stdout or "") ~= "",
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
        process_backend.attach_command(display_name),
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
    if not backend_available() then return end

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
    if not backend_available() then return end

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
    local function do_return(display_name)
        local path = workspace_paths[display_name]
        if not path then
            vim.notify("treehouse: path unknown for " .. display_name .. " (use <leader>fs to check)", vim.log.levels.WARN)
            return
        end

        local task = display_name:sub(#TH_PREFIX + 1)
        vim.system({ "git", "-C", path, "status", "--short", "--untracked-files=all" }, { text = true }, function(st)
            vim.schedule(function()
                if st.code ~= 0 then
                    local detail = vim.trim(st.stderr or "")
                    if detail == "" then detail = "exit code " .. st.code end
                    vim.notify("treehouse: failed to inspect workspace: " .. detail, vim.log.levels.ERROR)
                    return
                end

                local status_lines = vim.split(vim.trim(st.stdout or ""), "\n", { trimempty = true })
                local lines = { "Return workspace: " .. task, "", "  path: " .. path, "" }
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
                vim.keymap.set("n", "r", function()
                    close()
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
                end, opts)
            end)
        end)
    end

    -- if current buffer is a treehouse session, use it directly
    local display_name = buffer_session(vim.api.nvim_get_current_buf())
    if display_name then
        do_return(display_name)
        return
    end

    -- otherwise pick
    local sessions = th_sessions()
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
