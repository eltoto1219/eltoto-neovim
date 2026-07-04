return {
    {
        "lukas-reineke/indent-blankline.nvim",
        main = "ibl",
        config = function()
            require("ibl").setup({
                indent = {
                    char = "|",
                },
                scope = {
                    enabled = false,
                },
                exclude = {
                    filetypes = {
                        "NvimTree",
                        "Trouble",
                        "help",
                        "lazy",
                        "mason",
                        "nofile",
                        "terminal",
                    },
                    buftypes = {
                        "help",
                        "nofile",
                        "prompt",
                        "quickfix",
                        "terminal",
                    },
                },
            })
        end,
    },
}
