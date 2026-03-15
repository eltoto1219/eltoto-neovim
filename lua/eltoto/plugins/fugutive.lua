return {
    {
    'tpope/vim-fugitive',
    config = function()
        -- require('vim-fugitive').setup({})
        vim.keymap.set("n", "<leader>gs", vim.cmd.Git, { desc = "Git status" })
    end
    }
}
-- for fugitive
