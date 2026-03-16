return {
    {
        "github/copilot.vim",
        config = function()
            vim.g.copilot_no_tab_map = true

            vim.keymap.set("i", "<C-s>", 'copilot#Accept("\\<CR>")', {
                expr = true,
                replace_keycodes = false,
                silent = true,
                desc = "Accept Copilot suggestion",
            })
        end,
    },
    {
        "yetone/avante.nvim",
        build = "make",
        event = "VeryLazy",
        version = false,
        dependencies = {
            "nvim-treesitter/nvim-treesitter",
            "stevearc/dressing.nvim",
            "nvim-lua/plenary.nvim",
            "MunifTanjim/nui.nvim",
            "nvim-tree/nvim-web-devicons",
            {
                "MeanderingProgrammer/render-markdown.nvim",
                ft = { "markdown", "Avante" },
                opts = {
                    file_types = { "markdown", "Avante" },
                },
            },
        },
        config = function()
            local ai = require("eltoto.ai")
            require("eltoto.avante").setup(ai.codex_model)
        end,
    },
}
