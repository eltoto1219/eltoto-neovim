local M = {}
local data = require("eltoto.shortcut_data")

local function shortcuts_path()
    return vim.fs.normalize(vim.fn.stdpath("config") .. "/SHORTCUTS.txt")
end

local function readme_path()
    return vim.fs.normalize(vim.fn.stdpath("config") .. "/README.md")
end

local function render_plaintext()
    local lines = {
        data.title,
        string.rep("=", #data.title),
        "",
    }

    for _, section in ipairs(data.sections) do
        lines[#lines + 1] = section.title
        if section.notes then
            for _, note in ipairs(section.notes) do
                lines[#lines + 1] = "- " .. note
            end
        end
        for _, entry in ipairs(section.entries) do
            lines[#lines + 1] = "- " .. entry.lhs .. " : " .. entry.desc
        end
        lines[#lines + 1] = ""
    end

    return lines
end

local function render_readme_section()
    local lines = {
        "## Shortcuts",
        "",
        "All custom mappings are generated from `lua/eltoto/shortcut_data.lua` and written to `SHORTCUTS.txt`.",
        "",
        "Inside Neovim:",
        "",
        "```vim",
        ":Shortcuts",
        "```",
        "",
        "Or use:",
        "",
        "```text",
        "<leader>?",
        "```",
        "",
        "That opens a floating window with the shortcut list. Press `q` to close it.",
        "",
        "<!-- shortcuts:start -->",
        "",
    }

    for _, section in ipairs(data.sections) do
        lines[#lines + 1] = section.title
        if section.notes then
            for _, note in ipairs(section.notes) do
                lines[#lines + 1] = "- " .. note
            end
        end
        for _, entry in ipairs(section.entries) do
            lines[#lines + 1] = "- `" .. entry.lhs .. "`: " .. entry.desc
        end
        lines[#lines + 1] = ""
    end

    lines[#lines + 1] = "<!-- shortcuts:end -->"
    lines[#lines + 1] = ""

    return lines
end

local function replace_shortcuts_section(lines, replacement)
    local start_idx
    local end_idx

    for index, line in ipairs(lines) do
        if line == "## Shortcuts" then
            start_idx = index
        elseif start_idx and line:match("^## ") and line ~= "## Shortcuts" then
            end_idx = index - 1
            break
        end
    end

    if not start_idx then
        return lines
    end

    end_idx = end_idx or #lines

    local new_lines = {}
    for index = 1, start_idx - 1 do
        new_lines[#new_lines + 1] = lines[index]
    end
    for _, line in ipairs(replacement) do
        new_lines[#new_lines + 1] = line
    end
    for index = end_idx + 1, #lines do
        new_lines[#new_lines + 1] = lines[index]
    end

    return new_lines
end

function M.sync_docs()
    vim.fn.writefile(render_plaintext(), shortcuts_path())
    local readme_lines = vim.fn.readfile(readme_path())
    vim.fn.writefile(replace_shortcuts_section(readme_lines, render_readme_section()), readme_path())
end

function M.open()
    local lines = render_plaintext()
    local buf = vim.api.nvim_create_buf(false, true)
    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.8)
    local row = math.floor((vim.o.lines - height) / 2) - 1
    local col = math.floor((vim.o.columns - width) / 2)

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = false
    vim.bo[buf].filetype = "text"

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        style = "minimal",
        border = "rounded",
        width = width,
        height = height,
        row = math.max(row, 0),
        col = math.max(col, 0),
    })

    vim.wo[win].wrap = false
    vim.wo[win].cursorline = true

    vim.keymap.set("n", "q", function()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end, { buffer = buf, silent = true })
end

function M.register()
    vim.api.nvim_create_user_command("Shortcuts", M.open, {
        desc = "Show custom keyboard shortcuts",
    })
    vim.api.nvim_create_user_command("ShortcutsSync", M.sync_docs, {
        desc = "Sync generated shortcut docs to SHORTCUTS.txt and README.md",
    })

    vim.keymap.set("n", "<leader>?", M.open, {
        desc = "Show shortcut popup",
        silent = true,
    })
end

return M
