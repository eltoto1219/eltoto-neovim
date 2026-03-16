local M = {}

function M.centered(opts, on_submit)
    local ok_input, Input = pcall(require, "nui.input")
    if not ok_input then
        vim.ui.input({
            prompt = opts.prompt,
            default = opts.default or "",
        }, on_submit)
        return
    end

    local submitted = false
    local input = Input({
        position = "50%",
        size = {
            width = math.max(40, math.min(72, vim.o.columns - 8)),
        },
        border = {
            style = "rounded",
            text = {
                top = opts.title or "",
                top_align = "center",
            },
        },
        win_options = {
            winblend = 0,
        },
    }, {
        prompt = opts.prompt,
        default_value = opts.default or "",
        on_close = function()
            if submitted then
                return
            end
            submitted = true
            on_submit(nil)
        end,
        on_submit = function(value)
            submitted = true
            on_submit(value)
        end,
    })

    input:mount()

    local function focus_input()
        if input.winid and vim.api.nvim_win_is_valid(input.winid) then
            vim.api.nvim_set_current_win(input.winid)
            vim.cmd("startinsert!")
        end
    end

    vim.schedule(focus_input)
    vim.defer_fn(focus_input, 20)

    local function close_input()
        submitted = true
        input:unmount()
    end

    input:map("n", "<Esc>", close_input, { noremap = true, nowait = true })
    input:map("i", "<Esc>", close_input, { noremap = true, nowait = true })
    input:map("n", "q", close_input, { noremap = true, nowait = true })
    input:map("n", "qq", close_input, { noremap = true, nowait = true })
end

return M
