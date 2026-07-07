return {
    {
        "eltoto1219/whisper-dictation.nvim",
        -- eager: costs ~nothing and keeps :checkhealth working before first use
        lazy = false,
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
