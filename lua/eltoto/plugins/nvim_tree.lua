return {
    {
        "nvim-tree/nvim-tree.lua",
        dependencies = {
            "nvim-tree/nvim-web-devicons",
        },
        config = function()
            local function apply_tree_winhighlight(winid)
                if not winid or not vim.api.nvim_win_is_valid(winid) then
                    return
                end

                local current = vim.wo[winid].winhighlight or ""
                local mappings = {
                    WinSeparator = "NvimTreeWinSeparator",
                    VertSplit = "NvimTreeWinSeparator",
                }

                for from, to in pairs(mappings) do
                    if current:find(from .. ":", 1, true) then
                        current = current:gsub(from .. ":[^,]*", from .. ":" .. to)
                    else
                        current = current == "" and (from .. ":" .. to) or (current .. "," .. from .. ":" .. to)
                    end
                end

                vim.wo[winid].winhighlight = current
            end

            local function set_tree_highlights()
                local colors = require("eltoto.ui.colors")
                local normal = colors.get_hl("Normal")
                local normal_nc = colors.get_hl("NormalNC")
                vim.api.nvim_set_hl(0, "NvimTreeWinSeparator", { link = "WinSeparator" })
                vim.api.nvim_set_hl(0, "NvimTreeNormalFloatBorder", { link = "FloatBorder" })
                vim.api.nvim_set_hl(0, "NvimTreeNormalNC", {
                    fg = normal_nc.fg or normal.fg,
                    bg = normal_nc.bg or normal.bg,
                })
            end

            require("nvim-tree").setup({
                hijack_cursor = true,
                sync_root_with_cwd = true,
                view = {
                    side = "left",
                    preserve_window_proportions = true,
                    width = function()
                        return math.max(20, math.floor(vim.o.columns * 0.15))
                    end,
                },
                renderer = {
                    root_folder_label = false,
                },
                actions = {
                    open_file = {
                        quit_on_open = false,
                        resize_window = false,
                    },
                },
                filters = {
                    dotfiles = false,
                },
                update_focused_file = {
                    enable = true,
                    update_root = false,
                },
            })

            set_tree_highlights()

            local group = vim.api.nvim_create_augroup("EltotoNvimTreeHighlights", { clear = true })
            vim.api.nvim_create_autocmd("ColorScheme", {
                group = group,
                callback = set_tree_highlights,
            })
            vim.api.nvim_create_autocmd("VimEnter", {
                group = group,
                callback = set_tree_highlights,
            })
            vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
                group = group,
                pattern = "NvimTree",
                callback = function()
                    set_tree_highlights()
                    apply_tree_winhighlight(vim.api.nvim_get_current_win())
                end,
            })

            vim.keymap.set("n", "<leader>pv", function()
                require("nvim-tree.api").tree.toggle({
                    find_file = true,
                    focus = true,
                })
            end, { desc = "Toggle file explorer" })
        end,
    },
}
