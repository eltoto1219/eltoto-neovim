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
            vim.keymap.set("n", "<leader>gs", gitsigns.stage_hunk, { desc = "Stage git hunk" })
            vim.keymap.set("n", "<leader>gr", gitsigns.reset_hunk, { desc = "Reset git hunk" })
            vim.keymap.set("n", "<leader>gp", gitsigns.preview_hunk, { desc = "Preview git hunk" })
            vim.keymap.set("n", "<leader>gb", gitsigns.blame_line, { desc = "Blame current line" })
        end,
    },
}
