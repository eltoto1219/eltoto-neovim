return {
    {
        dir = vim.fs.normalize("~/projects/plugins/aiterm.nvim"),
        lazy = false,
        priority = 900,
        opts = {
            ai = {
                autostart = true,
                kinds = {
                    claude = { args = { "--dangerously-skip-permissions" } },
                    codex = {
                        args = {
                            "--no-alt-screen",
                            "--search",
                            "--dangerously-bypass-approvals-and-sandbox",
                            "--dangerously-bypass-hook-trust",
                        },
                    },
                },
            },
            -- keep the pre-extraction prefix so existing shpool sessions attach
            processes = { enabled = true, session_prefix = "eltoto-process-" },
            treehouse = {
                enabled = true,
                mappings = {
                    acquire = "<leader>fa",
                    lease = "<leader>fl",
                    status = "<leader>fs",
                    pick = "<leader>fw",
                    return_ws = "<leader>fr",
                },
            },
            tabline = { enabled = true },
        },
    },
}
