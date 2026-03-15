local M = {}

local AVANTE_FILETYPES = {
    "Avante",
    "AvanteInput",
    "AvantePromptInput",
    "AvanteSelectedCode",
    "AvanteSelectedFiles",
    "AvanteTodos",
}

local function require_avante()
    local ok, avante = pcall(require, "avante")
    return ok and avante or nil
end

function M.get_sidebar(open_only)
    local avante = require_avante()
    if not avante then
        return nil
    end

    local sidebar = avante.get(false)
    if not sidebar then
        return nil
    end

    if open_only == false or sidebar:is_open() then
        return sidebar
    end

    return nil
end

function M.is_sidebar_buffer(bufnr)
    local ok, avante_utils = pcall(require, "avante.utils")
    return ok and avante_utils.is_sidebar_buffer(bufnr or vim.api.nvim_get_current_buf()) or false
end

function M.refresh_lualine()
    local ok, lualine = pcall(require, "lualine")
    if not ok then
        return
    end

    lualine.refresh({
        place = { "tabline", "statusline" },
    })
end

local function code_bufnr(sidebar)
    if sidebar and sidebar.code and sidebar.code.bufnr and vim.api.nvim_buf_is_valid(sidebar.code.bufnr) then
        return sidebar.code.bufnr
    end

    return nil
end

local function focus_kind(sidebar)
    local current_buf = vim.api.nvim_get_current_buf()
    local current_win = vim.api.nvim_get_current_win()

    if sidebar.code and sidebar.code.winid == current_win then
        return "code"
    end
    if vim.bo[current_buf].filetype == "AvanteInput" then
        return "input"
    end
    return "result"
end

function M.list_histories()
    local sidebar = M.get_sidebar()
    local target_buf = code_bufnr(sidebar)
    if not target_buf then
        return {}, nil
    end

    local path = require("avante.path")
    local history_module = require("avante.history")
    local histories = path.history.list(target_buf)
    table.sort(histories, function(a, b)
        local a_messages = history_module.get_history_messages(a)
        local b_messages = history_module.get_history_messages(b)
        local timestamp_a = #a_messages > 0 and a_messages[#a_messages].timestamp or a.timestamp
        local timestamp_b = #b_messages > 0 and b_messages[#b_messages].timestamp or b.timestamp

        if timestamp_a == timestamp_b then
            return a.filename < b.filename
        end

        return timestamp_a > timestamp_b
    end)

    local current_filename = sidebar.chat_history and sidebar.chat_history.filename
        or path.history.get_latest_filename(target_buf, false)

    return histories, current_filename
end

function M.history_label(history)
    local title = vim.trim(history.title or "")
    if title == "" or title == "untitled" then
        title = history.filename:gsub("%.json$", "")
    end

    title = title:gsub("%s+", " ")
    if vim.fn.strdisplaywidth(title) > 24 then
        title = vim.fn.strcharpart(title, 0, 24) .. "..."
    end

    return title
end

function M.tabline_items()
    local histories, current_filename = M.list_histories()
    if #histories == 0 then
        return {}
    end

    local items = {}
    for _, history in ipairs(histories) do
        items[#items + 1] = {
            active = history.filename == current_filename,
            label = M.history_label(history),
        }
    end

    return items
end

local function focus_sidebar(sidebar, previous_focus)
    if previous_focus == "input" then
        sidebar:focus_input()
    elseif previous_focus == "result" then
        sidebar:focus()
    elseif sidebar.code and sidebar.code.winid and vim.api.nvim_win_is_valid(sidebar.code.winid) then
        vim.api.nvim_set_current_win(sidebar.code.winid)
    end
end

local function refresh_sidebar(sidebar, previous_focus)
    sidebar:reload_chat_history()
    sidebar:update_content_with_history()
    sidebar:create_todos_container()
    sidebar:initialize_token_count()
    sidebar:create_selected_code_container()
    sidebar:adjust_layout()
    focus_sidebar(sidebar, previous_focus)
    M.refresh_lualine()
end

local function apply_history(sidebar, filename, previous_focus)
    local target_buf = code_bufnr(sidebar)
    if not target_buf then
        return
    end

    require("avante.path").history.save_latest_filename(target_buf, filename)
    refresh_sidebar(sidebar, previous_focus)
end

local function cycle_history(offset)
    local sidebar = M.get_sidebar()
    if not sidebar then
        return
    end

    local histories, current_filename = M.list_histories()
    if #histories < 2 then
        return
    end

    local current_index = 1
    for index, history in ipairs(histories) do
        if history.filename == current_filename then
            current_index = index
            break
        end
    end

    local target_index = current_index + offset
    if target_index < 1 then
        target_index = #histories
    elseif target_index > #histories then
        target_index = 1
    end

    local target = histories[target_index]
    if not target or target.filename == current_filename then
        return
    end

    apply_history(sidebar, target.filename, focus_kind(sidebar))
end

function M.next_history()
    cycle_history(1)
end

function M.previous_history()
    cycle_history(-1)
end

function M.delete_current_history()
    local sidebar = M.get_sidebar()
    if not sidebar then
        return
    end

    local target_buf = code_bufnr(sidebar)
    if not target_buf then
        return
    end

    local histories, current_filename = M.list_histories()
    if #histories == 0 or not current_filename then
        vim.notify("No active Avante chat to delete", vim.log.levels.INFO)
        return
    end

    require("avante.path").history.delete(target_buf, current_filename)
    refresh_sidebar(sidebar, focus_kind(sidebar))
    vim.notify("Deleted current Avante chat")
end

function M.delete_all_histories()
    local sidebar = M.get_sidebar()
    if not sidebar then
        return
    end

    local target_buf = code_bufnr(sidebar)
    if not target_buf then
        return
    end

    local histories = M.list_histories()
    if #histories == 0 then
        vim.notify("No Avante chats to delete", vim.log.levels.INFO)
        return
    end

    vim.ui.input({
        prompt = string.format("Delete all %d Avante chats for this project? [y/N] ", #histories),
        default = "",
    }, function(input)
        local answer = vim.trim((input or ""):lower())
        if answer ~= "y" and answer ~= "yes" then
            return
        end

        local path = require("avante.path")
        for _, history in ipairs(histories) do
            path.history.delete(target_buf, history.filename)
        end

        sidebar:close({ goto_code_win = true })
        vim.schedule(function()
            if target_buf and vim.api.nvim_buf_is_valid(target_buf) then
                local current_buf = vim.api.nvim_get_current_buf()
                if current_buf == target_buf or vim.bo[current_buf].buftype ~= "terminal" then
                    vim.cmd("noautocmd stopinsert")
                end
            end
        end)
        M.refresh_lualine()
        vim.notify("Deleted all Avante chats for this project")
    end)
end

function M.toggle_or_create()
    local avante = require_avante()
    if not avante then
        return
    end

    local sidebar = M.get_sidebar(false)
    if sidebar and sidebar:is_open() then
        avante.toggle()
        return
    end

    local target_bufnr = vim.api.nvim_get_current_buf()
    if sidebar then
        local sidebar_bufnr = code_bufnr(sidebar)
        if sidebar_bufnr then
            target_bufnr = sidebar_bufnr
        end
    end

    local histories = require("avante.path").history.list(target_bufnr)
    if #histories > 0 then
        avante.open_sidebar({ ask = false })
        return
    end

    require("avante.api").ask({ new_chat = true })
end

function M.open_startup_chat_if_empty()
    if vim.fn.argc() ~= 0 then
        return
    end

    if vim.api.nvim_buf_get_name(0) ~= "" then
        return
    end

    vim.schedule(function()
        local target_bufnr = vim.api.nvim_get_current_buf()
        local histories = require("avante.path").history.list(target_bufnr)
        if #histories > 0 then
            require("avante").open_sidebar({ ask = false })
        else
            require("avante.api").ask({ ask = false, new_chat = true })
        end

        vim.schedule(function()
            local sidebar = M.get_sidebar()
            if sidebar and sidebar:is_open() and not sidebar.is_in_full_view then
                sidebar:toggle_code_window()
            end
        end)
    end)
end

local function apply_debounce_patch()
    if vim.g.eltoto_avante_debounce_patch then
        return
    end

    local avante_utils = require("avante.utils")
    local original_debounce = avante_utils.debounce

    avante_utils.debounce = function(func, delay)
        return original_debounce(function(...)
            local ok, err = xpcall(func, debug.traceback, ...)
            if ok then
                return
            end

            local message = tostring(err)
            local is_stale_input_hint = message:find("avante/sidebar.lua:3029", 1, true)
                and message:find("field 'input' (a nil value)", 1, true)

            if is_stale_input_hint then
                return
            end

            vim.schedule(function()
                error(err)
            end)
        end, delay)
    end

    vim.g.eltoto_avante_debounce_patch = true
end

local function hide_sidebar_input_hint()
    require("avante.sidebar").show_input_hint = function(self)
        self:close_input_hint()
    end
end

local function apply_prompt_input_patch()
    if vim.g.eltoto_avante_prompt_input_patch then
        return
    end

    local avante_prompt_input = require("avante.ui.prompt_input")
    local original_open = avante_prompt_input.open

    avante_prompt_input.show_shortcuts_hints = function(self)
        self:close_shortcuts_hints()
    end

    avante_prompt_input.open = function(self, ...)
        original_open(self, ...)

        self:close_shortcuts_hints()

        if self.winid and vim.api.nvim_win_is_valid(self.winid) then
            vim.api.nvim_set_option_value("winblend", 0, { win = self.winid })
        end
    end

    vim.g.eltoto_avante_prompt_input_patch = true
end

local function apply_history_prompt_patch()
    if vim.g.eltoto_avante_history_prompt_patch then
        return
    end

    local selector_native = require("avante.ui.selector.providers.native")
    local original_show = selector_native.show

    selector_native.show = function(selector)
        local is_history_selector = selector
            and selector.title == "Avante History (Select, then choose action)"
            and type(selector.on_delete_item) == "function"

        if not is_history_selector then
            return original_show(selector)
        end

        local items = {}
        for _, item in ipairs(selector.items) do
            if not vim.list_contains(selector.selected_item_ids, item.id) then
                items[#items + 1] = item
            end
        end

        vim.ui.select(items, {
            prompt = "Avante History",
            format_item = function(item)
                local title = item.title
                if item.id == selector.default_item_id then
                    title = "● " .. title
                end
                return title
            end,
        }, function(item)
            if not item then
                selector.on_select(nil)
                return
            end

            vim.ui.input({
                prompt = "History action: [Enter/o] open, d delete, c cancel",
                default = "",
            }, function(input)
                if not input then
                    selector.on_select(nil)
                    return
                end

                local choice = input:lower()
                if choice == "" or choice == "o" or choice == "open" then
                    selector.on_select({ item.id })
                elseif choice == "d" or choice == "delete" then
                    selector.on_delete_item(item.id)
                    selector.on_open()
                elseif choice == "c" or choice == "cancel" then
                    if type(selector.on_open) == "function" then
                        selector.on_open()
                    else
                        selector.on_select(nil)
                    end
                else
                    selector.on_select(nil)
                end
            end)
        end)
    end

    vim.g.eltoto_avante_history_prompt_patch = true
end

local function set_prompt_highlights()
    local normal_hl = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
    local float_border_hl = vim.api.nvim_get_hl(0, { name = "FloatBorder", link = false })

    vim.api.nvim_set_hl(0, "AvantePromptInput", {
        fg = normal_hl.fg,
        bg = normal_hl.bg,
    })
    vim.api.nvim_set_hl(0, "AvantePromptInputBorder", {
        fg = float_border_hl.fg or normal_hl.fg,
        bg = normal_hl.bg,
    })
end

local function register_local_mappings()
    local group = vim.api.nvim_create_augroup("eltoto_avante_local_mappings", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = AVANTE_FILETYPES,
        callback = function(event)
            local opts = { buffer = event.buf, silent = true }

            vim.keymap.set("n", "<leader>an", "<cmd>AvanteChatNew<CR>", vim.tbl_extend("force", opts, {
                desc = "Avante new chat",
            }))
            vim.keymap.set("n", "<leader>ah", "<cmd>AvanteHistory<CR>", vim.tbl_extend("force", opts, {
                desc = "Avante chat history",
            }))
            vim.keymap.set("n", "<leader>ac", "<cmd>AvanteClear<CR>", vim.tbl_extend("force", opts, {
                desc = "Avante clear chat",
            }))
            vim.keymap.set("n", "<leader>ad", M.delete_current_history, vim.tbl_extend("force", opts, {
                desc = "Avante delete current chat",
            }))
            vim.keymap.set("n", "<leader>aD", M.delete_all_histories, vim.tbl_extend("force", opts, {
                desc = "Avante delete all chats",
            }))
            vim.keymap.set("n", "<leader>;", M.next_history, vim.tbl_extend("force", opts, {
                desc = "Avante next chat",
            }))
            vim.keymap.set("n", "<leader>,", M.previous_history, vim.tbl_extend("force", opts, {
                desc = "Avante previous chat",
            }))
        end,
    })
end

local function register_global_mappings()
    local avante_api = require("avante.api")

    vim.keymap.set("n", "<leader>aa", function()
        avante_api.ask()
    end, {
        silent = true,
        desc = "Avante ask",
    })
    vim.keymap.set("n", "<leader>ac", "<cmd>AvanteChat<CR>", {
        silent = true,
        desc = "Avante chat",
    })
    vim.keymap.set("n", "<leader>at", M.toggle_or_create, {
        silent = true,
        desc = "Avante toggle or create chat",
    })
    vim.keymap.set("v", "<leader>aa", function()
        avante_api.ask()
    end, {
        silent = true,
        desc = "Avante ask selection",
    })
    vim.keymap.set("v", "<leader>ae", function()
        avante_api.edit()
    end, {
        silent = true,
        desc = "Avante edit selection",
    })
    vim.keymap.set("v", "<leader>as", function()
        avante_api.edit()
    end, {
        silent = true,
        desc = "Avante edit selection",
    })
end

function M.setup(codex_model)
    require("avante").setup({
        provider = "openai",
        behaviour = {
            auto_suggestions = false,
            auto_set_keymaps = false,
        },
        mappings = {
            submit = {
                normal = "<C-s>",
                insert = "<C-s>",
            },
            sidebar = {
                toggle_code_window = "<leader>z",
                toggle_code_window_from_input = {
                    normal = "<leader>z",
                },
            },
        },
        windows = {
            input = {
                height = 14,
            },
        },
        providers = {
            openai = {
                model = codex_model,
                use_response_api = true,
            },
        },
    })

    apply_debounce_patch()
    hide_sidebar_input_hint()
    apply_prompt_input_patch()
    apply_history_prompt_patch()
    set_prompt_highlights()
    register_local_mappings()
    register_global_mappings()
end

return M
