local M = {}
local eltoto_avante = require("eltoto.avante")
local env = require("eltoto.env")
local buffers = require("eltoto.buffers")

local last_terminal_bufnr = nil
local custom_labels = {}
local reopen_tree_on_file_focus = false
local avante_return_state_by_tab = {}

local function tree_api()
    local ok, api = pcall(require, "nvim-tree.api")
    return ok and api or nil
end

local function hide_tree_for_terminal()
    local api = tree_api()
    if api and api.tree.is_visible() then
        reopen_tree_on_file_focus = true
        pcall(api.tree.close)
    end
end

local function restore_tree_for_file()
    local api = tree_api()
    if not reopen_tree_on_file_focus or not api or api.tree.is_visible() then
        return
    end

    local current_win = vim.api.nvim_get_current_win()
    reopen_tree_on_file_focus = false
    pcall(api.tree.open, { find_file = true, focus = false })
    if vim.api.nvim_win_is_valid(current_win) then
        vim.api.nvim_set_current_win(current_win)
    end
end

local function close_tree_permanently()
    local ok, api = pcall(require, "nvim-tree.api")
    if ok and api.tree.is_visible() then
        reopen_tree_on_file_focus = false
        pcall(api.tree.close)
    end
end

local function listed_terminal_buffers()
    local terminals = {}

    for _, bufinfo in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
        if vim.bo[bufinfo.bufnr].buftype == "terminal" then
            terminals[#terminals + 1] = bufinfo
        end
    end

    table.sort(terminals, function(a, b)
        return a.bufnr < b.bufnr
    end)

    return terminals
end

function M.is_terminal(bufnr)
    return vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "terminal"
end

function M.buffers()
    local buffers = {}

    for _, bufinfo in ipairs(listed_terminal_buffers()) do
        buffers[#buffers + 1] = bufinfo.bufnr
    end

    return buffers
end

function M.buffer_info()
    return listed_terminal_buffers()
end

function M.label_for_buf(bufnr)
    local custom = custom_labels[bufnr]
    if custom and custom ~= "" then
        return custom
    end

    for index, bufinfo in ipairs(listed_terminal_buffers()) do
        if bufinfo.bufnr == bufnr then
            return "T:" .. index
        end
    end

    return nil
end

function M.get_last_terminal_buf()
    if M.is_terminal(last_terminal_bufnr or -1) and vim.fn.buflisted(last_terminal_bufnr) == 1 then
        return last_terminal_bufnr
    end

    return nil
end

local function enter_insert()
    vim.cmd.startinsert()
end

local safe_switch_buffer

local function current_tab()
    return vim.api.nvim_get_current_tabpage()
end

local function capture_avante_return_state()
    local sidebar = eltoto_avante.get_sidebar()
    if not sidebar then
        return nil
    end

    local code_winid = sidebar.code and sidebar.code.winid or nil
    local code_bufnr = sidebar.code and sidebar.code.bufnr or nil
    if not code_winid or not vim.api.nvim_win_is_valid(code_winid) then
        return nil
    end

    local current_buf = vim.api.nvim_get_current_buf()
    local current_win = vim.api.nvim_get_current_win()
    local focus
    if current_win == code_winid then
        focus = "code"
    elseif vim.bo[current_buf].filetype == "AvanteInput" then
        focus = "input"
    else
        focus = "result"
    end
    local state = {
        code_winid = code_winid,
        code_bufnr = code_bufnr,
        focus = focus,
        was_full_view = sidebar.is_in_full_view == true,
        term_bufnr = nil,
    }

    sidebar:close({ goto_code_win = true })
    avante_return_state_by_tab[current_tab()] = state
    return state
end

local function restore_avante_return_state(current_terminal_bufnr)
    local state = avante_return_state_by_tab[current_tab()]
    if not state or state.term_bufnr ~= current_terminal_bufnr then
        return false
    end

    avante_return_state_by_tab[current_tab()] = nil

    if state.code_winid and vim.api.nvim_win_is_valid(state.code_winid) then
        vim.api.nvim_set_current_win(state.code_winid)
    end

    if state.code_bufnr and vim.api.nvim_buf_is_valid(state.code_bufnr) then
        if vim.api.nvim_get_current_buf() ~= state.code_bufnr then
            safe_switch_buffer(state.code_bufnr)
        end
    end

    local ok, avante = pcall(require, "avante")
    if not ok then
        return false
    end
    local avante_config = require("avante.config")
    local previous_auto_focus_sidebar = avante_config.behaviour.auto_focus_sidebar
    avante_config.behaviour.auto_focus_sidebar = false

    local sidebar = eltoto_avante.get_sidebar(false)
    if sidebar then
        sidebar:open({ ask = false })
    else
        avante.open_sidebar({ ask = false })
        sidebar = eltoto_avante.get_sidebar(false)
    end

    if not sidebar or not sidebar:is_open() then
        return false
    end

    if state.was_full_view and not sidebar.is_in_full_view then
        sidebar:toggle_code_window()
    end

    if state.focus == "input" then
        sidebar:focus_input()
    elseif state.focus == "code" then
        if state.code_winid and vim.api.nvim_win_is_valid(state.code_winid) then
            vim.api.nvim_set_current_win(state.code_winid)
        end
        vim.cmd("noautocmd stopinsert")
    else
        sidebar:focus()
        vim.schedule(function()
            if sidebar:is_open() and sidebar.containers.result and vim.api.nvim_win_is_valid(sidebar.containers.result.winid) then
                vim.api.nvim_set_current_win(sidebar.containers.result.winid)
                vim.cmd("noautocmd stopinsert")
            end
        end)
    end

    vim.schedule(function()
        avante_config.behaviour.auto_focus_sidebar = previous_auto_focus_sidebar
    end)

    return true
end

local function with_current_window_buffer_unlocked(callback)
    local current_win = vim.api.nvim_get_current_win()
    if not vim.api.nvim_win_is_valid(current_win) then
        return false
    end

    local had_winfixbuf = vim.wo[current_win].winfixbuf
    if had_winfixbuf then
        vim.wo[current_win].winfixbuf = false
    end

    local ok = pcall(callback)

    if vim.api.nvim_win_is_valid(current_win) then
        vim.wo[current_win].winfixbuf = had_winfixbuf
    end

    return ok
end

safe_switch_buffer = function(bufnr)
    return with_current_window_buffer_unlocked(function()
        vim.cmd.buffer(bufnr)
    end)
end

local function safe_switch_alternate_buffer()
    return with_current_window_buffer_unlocked(function()
        vim.cmd.buffer({ args = { "#" }, bang = true })
    end)
end

local function safe_enew()
    return with_current_window_buffer_unlocked(function()
        vim.cmd.enew()
    end)
end

function M.open_new()
    hide_tree_for_terminal()
    if not safe_enew() then
        return
    end
    vim.fn.termopen(vim.o.shell, { env = env.terminal_env() })
    enter_insert()
end

function M.open_command(command, label)
    hide_tree_for_terminal()
    if not safe_enew() then
        return nil
    end
    local bufnr = vim.api.nvim_get_current_buf()

    if label and label ~= "" then
        custom_labels[bufnr] = label
    end

    vim.fn.termopen(command, { env = env.terminal_env() })
    vim.schedule(M.refresh_names)
    enter_insert()

    return bufnr
end

function M.ensure()
    local terms = M.buffers()
    local current = vim.api.nvim_get_current_buf()

    if M.is_terminal(current) then
        enter_insert()
        return
    end

    local last_terminal = M.get_last_terminal_buf()
    if last_terminal then
        hide_tree_for_terminal()
        if not safe_switch_buffer(last_terminal) then
            return
        end
        enter_insert()
        return
    end

    if #terms > 0 then
        hide_tree_for_terminal()
        if not safe_switch_buffer(terms[1]) then
            return
        end
        enter_insert()
        return
    end

    M.open_new()
end

function M.toggle()
    local current = vim.api.nvim_get_current_buf()
    local avante_state = nil

    if eltoto_avante.is_sidebar_buffer(current) then
        avante_state = capture_avante_return_state()
        current = vim.api.nvim_get_current_buf()
    else
        local sidebar = eltoto_avante.get_sidebar(false)
        local current_win = vim.api.nvim_get_current_win()
        if sidebar and sidebar:is_open() and sidebar.code and sidebar.code.winid == current_win then
            avante_state = capture_avante_return_state()
            current = vim.api.nvim_get_current_buf()
        end
    end

    local terms = M.buffers()

    if M.is_terminal(current) then
        if restore_avante_return_state(current) then
            return
        end

        local last_edit = buffers.get_last_edit_buf()
        if last_edit then
            if not safe_switch_buffer(last_edit) then
                return
            end
            restore_tree_for_file()
            return
        end

        local alternate = vim.fn.bufnr("#")
        if buffers.is_named_edit_buf(alternate) then
            if not safe_switch_alternate_buffer() then
                return
            end
            restore_tree_for_file()
        end
        return
    end

    local last_terminal = M.get_last_terminal_buf()
    if last_terminal then
        hide_tree_for_terminal()
        if not safe_switch_buffer(last_terminal) then
            return
        end
        if avante_state then
            avante_state.term_bufnr = vim.api.nvim_get_current_buf()
            avante_return_state_by_tab[current_tab()] = avante_state
        end
        enter_insert()
        return
    end

    if #terms > 0 then
        hide_tree_for_terminal()
        if not safe_switch_buffer(terms[1]) then
            return
        end
        if avante_state then
            avante_state.term_bufnr = vim.api.nvim_get_current_buf()
            avante_return_state_by_tab[current_tab()] = avante_state
        end
        enter_insert()
        return
    end

    M.open_new()
    if avante_state and M.is_terminal(vim.api.nvim_get_current_buf()) then
        avante_state.term_bufnr = vim.api.nvim_get_current_buf()
        avante_return_state_by_tab[current_tab()] = avante_state
    end
end

local function cycle(offset)
    local current = vim.api.nvim_get_current_buf()
    local terms = M.buffer_info()

    for index, item in ipairs(terms) do
        if item.bufnr == current then
            local target = terms[index + offset]
            if not target then
                target = offset > 0 and terms[1] or terms[#terms]
            end

            if target and target.bufnr ~= current then
                hide_tree_for_terminal()
                if not safe_switch_buffer(target.bufnr) then
                    return
                end
                enter_insert()
            end
            return
        end
    end
end

function M.forward()
    cycle(1)
end

function M.backward()
    cycle(-1)
end

function M.refresh_names()
    for index, bufinfo in ipairs(listed_terminal_buffers()) do
        local desired = M.label_for_buf(bufinfo.bufnr) or ("T:" .. index)

        if vim.api.nvim_buf_get_name(bufinfo.bufnr) ~= desired then
            pcall(vim.api.nvim_buf_set_name, bufinfo.bufnr, desired)
        end
    end
end

function M.rename_current()
    local current = vim.api.nvim_get_current_buf()

    if not M.is_terminal(current) then
        vim.notify("Current buffer is not a terminal", vim.log.levels.WARN)
        return
    end

    vim.ui.input({
        prompt = "Terminal name: ",
        default = "",
    }, function(input)
        if input == nil then
            return
        end

        local trimmed = vim.trim(input)
        if trimmed == "" then
            custom_labels[current] = nil
            vim.notify("Reset terminal name to default numbering")
        else
            custom_labels[current] = trimmed
            vim.notify("Renamed terminal to " .. trimmed)
        end

        M.refresh_names()
        if M.is_terminal(current) and vim.api.nvim_get_current_buf() == current then
            enter_insert()
        end
    end)
end

function M.setup()
    local group = vim.api.nvim_create_augroup("EltotoTerminalState", { clear = true })

    vim.api.nvim_create_user_command("TerminalRename", M.rename_current, {
        desc = "Rename the current terminal buffer",
    })

    vim.api.nvim_create_autocmd({ "TermOpen", "BufAdd", "BufEnter", "BufWipeout", "BufDelete" }, {
        group = group,
        callback = function(event)
            if event.event == "BufWipeout" or event.event == "BufDelete" then
                custom_labels[event.buf] = nil
            elseif M.is_terminal(event.buf) then
                last_terminal_bufnr = event.buf
                hide_tree_for_terminal()
            elseif buffers.is_named_edit_buf(event.buf) then
                restore_tree_for_file()
            end
            vim.schedule(M.refresh_names)
        end,
    })

    vim.api.nvim_create_autocmd("TermOpen", {
        group = group,
        callback = function(event)
            local opts = { buffer = event.buf, silent = true }

            vim.keymap.set("n", "j", "gj", vim.tbl_extend("force", opts, {
                desc = "Terminal scrollback down",
            }))
            vim.keymap.set("n", "k", "gk", vim.tbl_extend("force", opts, {
                desc = "Terminal scrollback up",
            }))
        end,
    })
end

function M.close_tree_permanently()
    close_tree_permanently()
end

return M
