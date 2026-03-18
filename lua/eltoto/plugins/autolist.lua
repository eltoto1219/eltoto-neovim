return {
    {
        "gaoDean/autolist.nvim",
        ft = { "markdown", "text" },
        config = function()
            local autolist = require("autolist")
            autolist.setup({
                lists = {
                    markdown = {
                        "[-+*]",
                        "%d+[.)]",
                        "%a[.)]",
                        "%u*[.)]",
                    },
                    text = {
                        "[-+*]",
                        "%d+[.)]",
                        "%a[.)]",
                        "%u*[.)]",
                    },
                },
            })

            local group = vim.api.nvim_create_augroup("EltotoAutolist", { clear = true })

            local function set_buffer_maps(bufnr)
                local opts = { buffer = bufnr, silent = true }
                vim.keymap.set("i", "<Tab>", "<cmd>AutolistTab<CR>", opts)
                vim.keymap.set("i", "<S-Tab>", "<cmd>AutolistShiftTab<CR>", opts)
                vim.keymap.set("i", "<CR>", "<CR><cmd>AutolistNewBullet<CR>", opts)
                vim.keymap.set("n", "o", "o<cmd>AutolistNewBullet<CR>", opts)
                vim.keymap.set("n", "O", "O<cmd>AutolistNewBulletBefore<CR>", opts)
            end

            vim.api.nvim_create_autocmd("FileType", {
                group = group,
                pattern = { "markdown", "text" },
                callback = function(event)
                    set_buffer_maps(event.buf)
                end,
            })

            local current = vim.api.nvim_get_current_buf()
            local ft = vim.bo[current].filetype
            if ft == "markdown" or ft == "text" then
                set_buffer_maps(current)
            end
        end,
    },
}
