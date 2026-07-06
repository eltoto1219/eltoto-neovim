return {
    {
        "lewis6991/gitsigns.nvim",
        config = function()
            local gitsigns = require("gitsigns")

            gitsigns.setup({
                current_line_blame = false,
                signcolumn = true,
                numhl = false,
                linehl = false,
                word_diff = false,
            })

            vim.keymap.set("n", "]h", gitsigns.next_hunk, { desc = "Next git hunk" })
            vim.keymap.set("n", "[h", gitsigns.prev_hunk, { desc = "Previous git hunk" })
        end,
    },
}
