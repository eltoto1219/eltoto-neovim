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
            local function from_terminal(fn)
                return function()
                    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
                    vim.schedule(fn)
                end
            end
            local function grep_input()
                builtin.grep_string({ search = vim.fn.input("Grep > ")});
            end
            vim.keymap.set('n', '<leader>pf', builtin.find_files, { desc = "Find files" })
            vim.keymap.set('t', '<leader>pf', from_terminal(builtin.find_files), { desc = "Find files from terminal" })
            vim.keymap.set('n', '<leader>ps', builtin.git_files, { desc = "Find git files" })
            vim.keymap.set('t', '<leader>ps', from_terminal(builtin.git_files), { desc = "Find git files from terminal" })
            vim.keymap.set('n', '<leader>b', builtin.buffers, { desc = "Buffer picker" })
            vim.keymap.set('t', '<leader>b', from_terminal(builtin.buffers), { desc = "Buffer picker from terminal" })
            vim.keymap.set('n', '<leader>pg', grep_input, { desc = "Grep string" })
            vim.keymap.set('t', '<leader>pg', from_terminal(grep_input), { desc = "Grep string from terminal" })
        end
    }
}
