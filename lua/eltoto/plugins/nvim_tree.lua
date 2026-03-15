return {
    {
        "nvim-tree/nvim-tree.lua",
        dependencies = {
            "nvim-tree/nvim-web-devicons",
        },
        config = function()
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

            vim.keymap.set("n", "<leader>pv", function()
                require("nvim-tree.api").tree.toggle({
                    find_file = true,
                    focus = true,
                })
            end, { desc = "Toggle file explorer" })
        end,
    },
}
