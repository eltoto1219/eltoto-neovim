return {
    "folke/noice.nvim",
    event = "VeryLazy",
    opts = {
        -- add any options here
    },
    dependencies = {
        -- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
        "MunifTanjim/nui.nvim",
        -- OPTIONAL:
        --   `nvim-notify` is only needed, if you want to use the notification view.
        --   If not available, we use `mini` as the fallback
        "rcarriga/nvim-notify",
        "hrsh7th/nvim-cmp"
    },
    config = function ()
        require("noice").setup({
            lsp = {
                progress = {
                    enabled = false,
                },
                -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
                override = {
                    ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
                    ["vim.lsp.util.stylize_markdown"] = true,
                    ["cmp.entry.get_documentation"] = true, -- requires hrsh7th/nvim-cmp
                },
            },
            -- you can enable a preset for easier configuration
            presets = {
                bottom_search = false, -- use a classic bottom cmdline for search
                command_palette = true, -- position the cmdline and popupmenu together
                long_message_to_split = true, -- long messages will be sent to a split
                inc_rename = false, -- enables an input dialog for inc-rename.nvim
                lsp_doc_border = true, -- add a border to hover docs and signature help
            },
            -- popupmenu = {
            --     enabled = false,
            -- }
            notify = {
                -- Noice can be used as `vim.notify` so you can route any notification like other messages
                -- Notification messages have their level and other properties set.
                -- event is always "notify" and kind can be any log level as a string
                -- The default routes will forward notifications to nvim-notify
                -- Benefit of using Noice for this is the routing and consistent history view
                enabled = true,
                view = "mini",
            },
            messages = {
                -- NOTE: If you enable messages, then the cmdline is enabled automatically.
                -- This is a current Neovim limitation.
                enabled = true, -- enables the Noice messages UI
                view = "mini", -- default view for messages
                view_error = "mini", -- view for errors
                view_warn = "mini", -- view for warnings
                view_history = "messages", -- view for :messages
                view_search = "virtualtext", -- view for search count messages. Set to `false` to disable
            },
            cmdline = {
                enabled = true, -- enables the Noice cmdline UI
                view = "cmdline", -- view for rendering the cmdline. Change to `cmdline` to get a classic cmdline at the bottom
                opts = {}, -- global options for the cmdline. See section on views
                ---@type table<string, CmdlineFormat>
                format = {
                    -- conceal: (default=true) This will hide the text in the cmdline that matches the pattern.
                    -- view: (default is cmdline view)
                    -- opts: any options passed to the view
                    -- icon_hl_group: optional hl_group for the icon
                    -- title: set to anything or empty string to hide
                    cmdline = { pattern = "^:", icon = "", lang = "vim" },
                    search_down = { kind = "search", pattern = "^/", icon = " ", lang = "regex" },
                    search_up = { kind = "search", pattern = "^%?", icon = " ", lang = "regex" },
                    filter = { pattern = "^:%s*!", icon = "$", lang = "bash" },
                    lua = { pattern = { "^:%s*lua%s+", "^:%s*lua%s*=%s*", "^:%s*=%s*" }, icon = "", lang = "lua" },
                    help = { pattern = "^:%s*he?l?p?%s+", icon = "" },
                    input = {}, -- Used by input()
                    -- lua = false, -- to disable a format, set to `false`
                },
            },
            routes = {
                {
                    filter = {
                        event = "msg_show",
                        kind = "",
                        find = "written",
                    },
                    opts = { skip = true },
                },
            },
        })

        vim.keymap.set("n", "<leader>nd", "<cmd>NoiceDismiss<CR>", {desc = "Dismiss Noice Message"})

    end

}
