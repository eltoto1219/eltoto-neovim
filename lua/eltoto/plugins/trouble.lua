return {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {},
    config = function(_, opts)
        local trouble = require("trouble")
        trouble.setup(opts)

        vim.keymap.set("n", "<leader>xx", function() trouble.toggle("diagnostics") end, { desc = "Trouble toggle" })
        vim.keymap.set("n", "<leader>xw", function() trouble.toggle("diagnostics") end, { desc = "Trouble workspace diagnostics" })
        vim.keymap.set("n", "<leader>xd", function()
            trouble.toggle({ mode = "diagnostics", filter = { buf = 0 } })
        end, { desc = "Trouble document diagnostics" })
        vim.keymap.set("n", "<leader>xq", function() trouble.toggle("qflist") end, { desc = "Trouble quickfix" })
        vim.keymap.set("n", "<leader>x]", function() trouble.toggle("loclist") end, { desc = "Trouble loclist" })
        vim.keymap.set("n", "]d", function()
            vim.diagnostic.jump({ count = 1, float = false })
        end, { desc = "Next diagnostic" })
        vim.keymap.set("n", "[d", function()
            vim.diagnostic.jump({ count = -1, float = false })
        end, { nowait = true, desc = "Previous diagnostic" })
    end,
}
