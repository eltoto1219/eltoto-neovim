return {
    {
        'nvim-telescope/telescope.nvim',
        tag = '0.1.5',
        dependencies = { 'nvim-lua/plenary.nvim' } ,
        config = function ()
            local telescope = require('telescope')
            telescope.load_extension("noice")
            telescope.setup({})

            local builtin = require('telescope.builtin')
            vim.keymap.set('n', '<leader>pf', builtin.find_files, { desc = "Find files" })
            vim.keymap.set('n', '<leader>ps', builtin.git_files, { desc = "Find git files" })
            vim.keymap.set('n', '<leader>bb', builtin.buffers, { desc = "Buffer picker" })
            vim.keymap.set('n', '<leader>pg', function()
                builtin.grep_string({ search = vim.fn.input("Grep > ")});
            end, { desc = "Grep string" })
        end
    }
}
