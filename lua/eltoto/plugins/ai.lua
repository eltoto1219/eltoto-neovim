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
        "MeanderingProgrammer/render-markdown.nvim",
        dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
        ft = { "markdown" },
        opts = {
            file_types = { "markdown" },
        },
    },
}
