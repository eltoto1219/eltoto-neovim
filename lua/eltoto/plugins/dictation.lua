return {
    {
        dir = vim.fs.normalize("~/projects/plugins/whisper-dictation.nvim"),
        keys = {
            {
                "<leader>v",
                function()
                    require("whisper-dictation").toggle()
                end,
                mode = { "n", "t" },
                desc = "Toggle voice dictation",
            },
        },
        -- reuse the config venv (already has faster-whisper via reqs.txt)
        opts = { python = vim.fs.joinpath(vim.fn.stdpath("config"), ".venv", "bin", "python") },
    },
}
