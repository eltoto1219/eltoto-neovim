local M = {}
local fullscreen_state_by_tab = {}
local hidden_tree_state_by_tab = {}
local AVANTE_TITLE_MODEL = "gpt-4.1-mini"

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

local function is_valid_win(winid)
    return type(winid) == "number" and winid > 0 and vim.api.nvim_win_is_valid(winid)
end

local function current_tab()
    return vim.api.nvim_get_current_tabpage()
end

local function tree_api()
    local ok, api = pcall(require, "nvim-tree.api")
    return ok and api or nil
end

local function is_tree_window(winid)
    if not is_valid_win(winid) then
        return false
    end

    local bufnr = vim.api.nvim_win_get_buf(winid)
    return vim.bo[bufnr].filetype == "NvimTree"
end

local function ensure_sidebar_code_window(sidebar)
    if not sidebar or not sidebar:is_open() then
        return
    end

    local current = sidebar.code and sidebar.code.winid or nil
    if is_valid_win(current) and not sidebar:is_sidebar_winid(current) and not is_tree_window(current) then
        return
    end

    local replacement = nil
    for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(sidebar.id)) do
        if is_valid_win(winid) and not sidebar:is_sidebar_winid(winid) and not is_tree_window(winid) then
            replacement = winid
            break
        end
    end

    if replacement then
        sidebar.code.winid = replacement
        sidebar.code.bufnr = vim.api.nvim_win_get_buf(replacement)
    end
end

local function container_height(container)
    if not container or not is_valid_win(container.winid) then
        return 0
    end

    return vim.api.nvim_win_get_height(container.winid)
end

local function safe_call(object, method)
    if object and type(object[method]) == "function" then
        object[method](object)
    end
end

function M.resize_current_window(delta)
    if vim.bo[vim.api.nvim_get_current_buf()].filetype ~= "AvanteInput" then
        return false
    end

    local sidebar = M.get_sidebar()
    if not sidebar or sidebar:get_layout() ~= "vertical" then
        return false
    end

    local input = sidebar.containers and sidebar.containers.input
    local result = sidebar.containers and sidebar.containers.result
    if not input or not result or not is_valid_win(input.winid) or not is_valid_win(result.winid) then
        return false
    end

    local current_height = vim.api.nvim_win_get_height(input.winid)
    local current_total_height = current_height + vim.api.nvim_win_get_height(result.winid)
    for _, name in ipairs({ "selected_code", "selected_files", "todos" }) do
        current_total_height = current_total_height + container_height(sidebar.containers[name])
    end

    safe_call(sidebar, "adjust_selected_code_container_layout")
    safe_call(sidebar, "adjust_selected_files_container_layout")
    safe_call(sidebar, "adjust_todos_container_layout")

    local fixed_height = 0
    if type(sidebar.get_selected_code_container_height) == "function" then
        fixed_height = fixed_height + sidebar:get_selected_code_container_height()
    end
    if type(sidebar.get_selected_files_container_height) == "function" then
        fixed_height = fixed_height + sidebar:get_selected_files_container_height()
    end
    if type(sidebar.get_todos_container_height) == "function" then
        fixed_height = fixed_height + sidebar:get_todos_container_height()
    end

    local available_height = math.max(1, current_total_height - fixed_height)
    local min_input_height = 3
    local min_result_height = 1
    local max_input_height = math.max(min_input_height, available_height - min_result_height)
    local target_height = math.max(min_input_height, math.min(max_input_height, current_height + delta))

    if target_height == current_height then
        return true
    end

    require("avante.config").windows.input.height = target_height
    vim.api.nvim_win_set_height(input.winid, target_height)
    vim.api.nvim_win_set_height(result.winid, math.max(min_result_height, available_height - target_height))

    if vim.api.nvim_get_current_win() == input.winid then
        pcall(function()
            sidebar:show_input_hint()
        end)
    end

    return true
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

local function remember_fullscreen_state(sidebar)
    fullscreen_state_by_tab[current_tab()] = sidebar and sidebar.is_in_full_view == true or false
end

local function hide_tree_for_fullscreen()
    local api = tree_api()
    if not api or not api.tree.is_visible() then
        return
    end

    local tree_winid = api.tree.winid and api.tree.winid() or nil
    hidden_tree_state_by_tab[current_tab()] = {
        width = is_valid_win(tree_winid) and vim.api.nvim_win_get_width(tree_winid) or nil,
    }
    pcall(api.tree.close)
end

local function restore_tree_after_fullscreen(sidebar)
    local tree_state = hidden_tree_state_by_tab[current_tab()]
    if type(tree_state) ~= "table" then
        return
    end

    hidden_tree_state_by_tab[current_tab()] = nil

    local api = tree_api()
    if not api or api.tree.is_visible() then
        return
    end

    local current_win = vim.api.nvim_get_current_win()
    pcall(api.tree.open, { find_file = true, focus = false })
    if tree_state.width then
        pcall(api.tree.resize, { absolute = tree_state.width })
    end
    if vim.api.nvim_win_is_valid(current_win) then
        vim.api.nvim_set_current_win(current_win)
    end
    if sidebar and sidebar:is_open() then
        pcall(function()
            sidebar:adjust_layout()
        end)
    end
end

local function restore_fullscreen_state(sidebar)
    if not sidebar or not sidebar:is_open() then
        return
    end

    local should_be_fullscreen = fullscreen_state_by_tab[current_tab()] == true
    if should_be_fullscreen and not sidebar.is_in_full_view then
        sidebar:toggle_code_window()
    elseif not should_be_fullscreen and sidebar.is_in_full_view then
        sidebar:toggle_code_window()
    end
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
    if title == "" then
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

local function extract_text_content(content)
    if type(content) == "string" then
        return content
    end

    if type(content) ~= "table" then
        return nil
    end

    local parts = {}
    for _, item in ipairs(content) do
        if type(item) == "string" then
            parts[#parts + 1] = item
        elseif type(item) == "table" then
            if item.type == "text" and type(item.text) == "string" then
                parts[#parts + 1] = item.text
            elseif item.type == "text" and type(item.content) == "string" then
                parts[#parts + 1] = item.content
            end
        end
    end

    local text = table.concat(parts)
    if text == "" then
        return nil
    end

    return text
end

local function trim_title_candidate(title)
    if type(title) ~= "string" then
        return nil
    end

    title = vim.trim(title:gsub("[\r\n]+", " "):gsub("%s+", " "))
    title = title:gsub('^["' .. "'" .. "`%[]+", ""):gsub('["' .. "'" .. "`%],.:;!?]+$", "")

    if title == "" then
        return nil
    end

    local words = vim.split(title, "%s+")
    if #words > 4 then
        title = table.concat(vim.list_slice(words, 1, 4), " ")
    end

    return title
end

local function first_prompt_title(request)
    if type(request) ~= "string" then
        return ""
    end

    for _, line in ipairs(vim.split(request, "\n")) do
        local trimmed = vim.trim(line)
        if trimmed ~= "" then
            return trimmed
        end
    end

    return ""
end

local function request_short_chat_title(request, on_complete)
    local ok_curl, curl = pcall(require, "plenary.curl")
    local ok_providers, providers = pcall(require, "avante.providers")
    local ok_utils, avante_utils = pcall(require, "avante.utils")
    if not ok_curl or not ok_providers or not ok_utils then
        return false
    end

    local provider = providers.openai
    local provider_conf = providers.get_config("openai") or {}
    local api_key = provider and provider.parse_api_key and provider.parse_api_key() or nil
    if not api_key then
        return false
    end

    local prompt = table.concat({
        "Summarize this developer request into a short chat title.",
        "Return only the title.",
        "Use 1 to 4 words.",
        "Avoid punctuation unless absolutely necessary.",
        "",
        request,
    }, "\n")

    local endpoint = avante_utils.url_join(provider_conf.endpoint or "https://api.openai.com/v1", "/chat/completions")
    curl.post(endpoint, {
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. api_key,
        },
        body = vim.json.encode({
            model = vim.g.eltoto_avante_title_model or AVANTE_TITLE_MODEL,
            messages = {
                {
                    role = "system",
                    content = "You write extremely short chat titles.",
                },
                {
                    role = "user",
                    content = prompt,
                },
            },
            temperature = 0.2,
            max_tokens = 16,
            stream = false,
        }),
        callback = function(resp)
            if resp.status ~= 200 then
                vim.schedule(function()
                    on_complete(nil)
                end)
                return
            end

            local ok_decode, payload = pcall(vim.json.decode, resp.body or "")
            if not ok_decode or type(payload) ~= "table" then
                vim.schedule(function()
                    on_complete(nil)
                end)
                return
            end

            local choice = payload.choices and payload.choices[1]
            local message = choice and choice.message
            local content = message and message.content
            local title = trim_title_candidate(content)
            vim.schedule(function()
                on_complete(title)
            end)
        end,
    })

    return true
end

local function maybe_generate_chat_title(sidebar, request)
    if not sidebar or type(request) ~= "string" then
        return
    end

    local trimmed_request = vim.trim(request)
    if trimmed_request == "" then
        return
    end

    local history = sidebar.chat_history
    if not history or history.title ~= "untitled" or not history.filename then
        return
    end

    if sidebar._eltoto_title_generation_pending then
        return
    end

    local bufnr = sidebar.code and sidebar.code.bufnr
    if not bufnr then
        return
    end

    local filename = history.filename
    local default_title = first_prompt_title(trimmed_request)
    sidebar._eltoto_title_generation_pending = true

    local started = request_short_chat_title(trimmed_request, function(title)
        sidebar._eltoto_title_generation_pending = nil

        if not title then
            return
        end

        local path = require("avante.path")
        local saved_history = path.history.load(bufnr, filename)
        if not saved_history or saved_history.filename ~= filename then
            return
        end

        if saved_history.title ~= "untitled" and saved_history.title ~= default_title then
            return
        end

        saved_history.title = title
        path.history.save(bufnr, saved_history)

        if sidebar.chat_history and sidebar.chat_history.filename == filename then
            sidebar.chat_history.title = title
        end

        M.refresh_lualine()
    end)

    if not started then
        sidebar._eltoto_title_generation_pending = nil
    end
end

local function sanitize_history_message(message)
    if type(message) ~= "table" or type(message.message) ~= "table" then
        return nil, true
    end

    local role = message.message.role
    if role ~= "user" and role ~= "assistant" then
        return nil, true
    end

    local text = extract_text_content(message.message.content)
    if text == nil then
        return nil, true
    end

    if message.message.content ~= text then
        message.message.content = text
        return message, true
    end

    return message, false
end

local function apply_history_sanitize_patch()
    if vim.g.eltoto_avante_history_sanitize_patch then
        return
    end

    local path = require("avante.path")
    local original_load = path.history.load

    path.history.load = function(bufnr, filename)
        local history = original_load(bufnr, filename)
        if type(history) ~= "table" or type(history.messages) ~= "table" then
            return history
        end

        local sanitized = {}
        local changed = false

        for _, message in ipairs(history.messages) do
            local cleaned, message_changed = sanitize_history_message(message)
            if cleaned then
                sanitized[#sanitized + 1] = cleaned
            end
            if message_changed then
                changed = true
            end
        end

        if changed then
            history.messages = sanitized
            path.history.save(bufnr, history)
        end

        return history
    end

    vim.g.eltoto_avante_history_sanitize_patch = true
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

    local path = require("avante.path")
    path.history.delete(target_buf, current_filename)

    if #path.history.list(target_buf) == 0 then
        sidebar:close({ goto_code_win = true })
        M.refresh_lualine()
    else
        refresh_sidebar(sidebar, focus_kind(sidebar))
    end

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
        remember_fullscreen_state(sidebar)
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
        restore_fullscreen_state(M.get_sidebar(false))
        return
    end

    require("avante.api").ask({ new_chat = true })
    vim.schedule(function()
        restore_fullscreen_state(M.get_sidebar(false))
    end)
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

local function apply_sidebar_behavior_patches()
    if vim.g.eltoto_avante_sidebar_behavior_patches then
        return
    end

    local sidebar = require("avante.sidebar")
    local original_update_content = sidebar.update_content
    local original_handle_submit = sidebar.handle_submit
    local original_add_history_messages = sidebar.add_history_messages
    local original_get_message_lines = sidebar.get_message_lines
    local original_render_state = sidebar.render_state
    local original_toggle_code_window = sidebar.toggle_code_window

    sidebar.update_content = function(self, content, opts)
        if content == "New chat" then
            content = ""
        end

        if self._eltoto_keep_submit_focus and type(opts) == "table" and opts.focus == true then
            opts = vim.tbl_extend("force", {}, opts, { focus = false })
        end

        return original_update_content(self, content, opts)
    end

    sidebar.handle_submit = function(self, request)
        local should_generate_title = self.chat_history
            and self.chat_history.title == "untitled"
            and vim.trim(request or "") ~= ""

        self._eltoto_keep_submit_focus = true
        local ok, result = xpcall(function()
            return original_handle_submit(self, request)
        end, debug.traceback)
        self._eltoto_keep_submit_focus = nil

        if not ok then
            error(result)
        end

        if should_generate_title then
            maybe_generate_chat_title(self, request)
        end

        return result
    end

    sidebar.add_history_messages = function(self, messages, opts)
        local should_preserve_untitled = self.chat_history and self.chat_history.title == "untitled"
        local result = original_add_history_messages(self, messages, opts)

        if should_preserve_untitled and self.chat_history and self.chat_history.title ~= "untitled" then
            self.chat_history.title = "untitled"
            self:save_history()
            M.refresh_lualine()
        end

        return result
    end

    sidebar.get_message_lines = function(self, ctx, message, messages, ignore_record_prefix)
        if message and message.is_user_submission then
            ignore_record_prefix = true
        end

        return original_get_message_lines(self, ctx, message, messages, ignore_record_prefix)
    end

    sidebar.render_state = function(self)
        if self.current_state == "succeeded" or self.current_state == "failed" then
            self:clear_state()
            return
        end

        return original_render_state(self)
    end

    sidebar.toggle_code_window = function(self, ...)
        local entering_fullscreen = self.is_in_full_view ~= true
        if entering_fullscreen then
            ensure_sidebar_code_window(self)
            hide_tree_for_fullscreen()
            ensure_sidebar_code_window(self)
        end

        local result = original_toggle_code_window(self, ...)

        if self.is_in_full_view then
            vim.schedule(function()
                if not self:is_open() then
                    return
                end

                pcall(function()
                    self:adjust_layout()
                end)
            end)
        else
            vim.schedule(function()
                restore_tree_after_fullscreen(self)
            end)
        end

        return result
    end

    vim.g.eltoto_avante_sidebar_behavior_patches = true
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

local function set_sidebar_separator_highlights()
    local win_separator_hl = vim.api.nvim_get_hl(0, { name = "WinSeparator", link = false })
    local normal_float_hl = vim.api.nvim_get_hl(0, { name = "NormalFloat", link = false })
    local normal_hl = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
    local fg = win_separator_hl.fg or normal_hl.fg
    local bg = normal_float_hl.bg or normal_hl.bg

    vim.api.nvim_set_hl(0, "AvanteSidebarWinSeparator", {
        fg = fg,
        bg = bg,
        bold = true,
    })
    vim.api.nvim_set_hl(0, "AvanteSidebarWinHorizontalSeparator", {
        fg = fg,
        bg = bg,
        bold = true,
    })
end

local function register_highlight_autocmd()
    local group = vim.api.nvim_create_augroup("eltoto_avante_highlights", { clear = true })
    vim.api.nvim_create_autocmd("ColorScheme", {
        group = group,
        callback = function()
            set_prompt_highlights()
            set_sidebar_separator_highlights()
        end,
    })
end

local function register_local_mappings()
    local group = vim.api.nvim_create_augroup("eltoto_avante_local_mappings", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = AVANTE_FILETYPES,
        callback = function(event)
            local opts = { buffer = event.buf, silent = true }
            local filetype = vim.bo[event.buf].filetype

            if vim.tbl_contains({ "AvanteSelectedCode", "AvanteSelectedFiles", "AvanteTodos" }, filetype) then
                vim.opt_local.winfixheight = true
            elseif vim.tbl_contains({ "Avante", "AvanteInput", "AvantePromptInput" }, filetype) then
                vim.opt_local.winfixheight = false
            end

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
        mode = "agentic",
        behaviour = {
            auto_suggestions = false,
            auto_set_keymaps = false,
            jump_result_buffer_on_finish = false,
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
            ask = {
                start_insert = false,
            },
            input = {
                height = 10,
            },
        },
        providers = {
            openai = {
                model = codex_model,
            },
        },
    })

    apply_debounce_patch()
    apply_history_sanitize_patch()
    hide_sidebar_input_hint()
    apply_prompt_input_patch()
    apply_history_prompt_patch()
    apply_sidebar_behavior_patches()
    set_prompt_highlights()
    set_sidebar_separator_highlights()
    register_highlight_autocmd()
    register_local_mappings()
    register_global_mappings()
end

return M
