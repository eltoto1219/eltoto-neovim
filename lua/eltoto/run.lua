local M = {}

local terminal = require("eltoto.terminal")
local session_overrides = {}

local default_runners = {
    python = "python3 {file}",
    lua = "lua {file}",
    javascript = "node {file}",
    typescript = "tsx {file}",
    sh = "bash {file}",
    bash = "bash {file}",
    zsh = "zsh {file}",
    go = "go run {file}",
    ruby = "ruby {file}",
    php = "php {file}",
    perl = "perl {file}",
}

local non_runnable = {
    html = true,
    css = true,
    scss = true,
    json = true,
    yaml = true,
    yml = true,
    markdown = true,
    md = true,
    text = true,
    txt = true,
    toml = true,
    xml = true,
}

local function send_to_terminal(lines)
    local job_id = vim.b.terminal_job_id
    if not job_id then
        return
    end

    vim.api.nvim_chan_send(job_id, table.concat(lines, "\n") .. "\n")
end

local function current_filetype()
    return vim.bo.filetype
end

local function current_filepath()
    return vim.fn.expand("%:p")
end

local function render_command(template, filepath)
    local values = {
        ["{file}"] = vim.fn.shellescape(filepath),
        ["{dir}"] = vim.fn.shellescape(vim.fn.fnamemodify(filepath, ":h")),
        ["{name}"] = vim.fn.shellescape(vim.fn.fnamemodify(filepath, ":t")),
        ["{stem}"] = vim.fn.shellescape(vim.fn.fnamemodify(filepath, ":t:r")),
    }
    local rendered = template

    for placeholder, value in pairs(values) do
        rendered = rendered:gsub(vim.pesc(placeholder), value)
    end

    return rendered
end

local function resolved_runner(filetype)
    return session_overrides[filetype] or default_runners[filetype]
end

local function current_runner_description()
    local filetype = current_filetype()
    local runner = resolved_runner(filetype)

    if runner then
        return runner
    end

    if non_runnable[filetype] then
        return "Not runnable by default"
    end

    return "No default runner configured"
end

local function set_override(filetype, command)
    if command == nil or command == "" then
        session_overrides[filetype] = nil
    else
        session_overrides[filetype] = command
    end
end

local function close_window(win)
    if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
    end
end

function M.configure_popup()
    local filetype = current_filetype()
    local current = current_runner_description()
    local buf = vim.api.nvim_create_buf(false, true)
    local width = 72
    local height = 10
    local row = math.floor((vim.o.lines - height) / 2) - 1
    local col = math.floor((vim.o.columns - width) / 2)
    local lines = {
        "Run Config",
        "",
        "filetype: " .. (filetype ~= "" and filetype or "<none>"),
        "current:  " .. current,
        "",
        "d : use default runner for this filetype",
        "c : set custom command for this filetype",
        "q : close without changes",
        "",
        "Placeholders: {file} {dir} {name} {stem}",
    }

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = false

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        style = "minimal",
        border = "rounded",
        width = width,
        height = height,
        row = math.max(row, 0),
        col = math.max(col, 0),
    })

    vim.keymap.set("n", "q", function()
        close_window(win)
    end, { buffer = buf, silent = true })

    vim.keymap.set("n", "d", function()
        set_override(filetype, nil)
        close_window(win)
        vim.notify("Using default runner for " .. filetype)
    end, { buffer = buf, silent = true })

    vim.keymap.set("n", "c", function()
        vim.ui.input({
            prompt = "Custom run command for " .. filetype .. ": ",
            default = "",
        }, function(input)
            if input and input ~= "" then
                set_override(filetype, input)
                vim.notify("Saved session runner for " .. filetype)
            end
            close_window(win)
        end)
    end, { buffer = buf, silent = true })
end

local function runnable_command()
    local filepath = current_filepath()
    local filetype = current_filetype()
    local runner = resolved_runner(filetype)

    if filepath == "" then
        return nil, "Current buffer is not a file"
    end

    if runner then
        return render_command(runner, filepath), nil
    end

    if non_runnable[filetype] then
        return nil, "Filetype '" .. filetype .. "' is not runnable"
    end

    if filetype == "" then
        return nil, "Buffer has no filetype"
    end

    return nil, "No runner configured for filetype '" .. filetype .. "'"
end

function M.exec_current_file()
    local command, err = runnable_command()
    if not command then
        vim.notify(err, vim.log.levels.WARN)
        return
    end

    terminal.ensure()

    if vim.bo.buftype ~= "terminal" then
        return
    end

    send_to_terminal({ "reset", command })
end

function M.register()
    vim.api.nvim_create_user_command("TermimalConfig", M.configure_popup, {
        desc = "Configure filetype-aware run command for <leader>e",
    })
end

return M
