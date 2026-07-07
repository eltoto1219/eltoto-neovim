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
            -- note: sessions created under an older prefix (eltoto-process-*)
            -- are invisible to the picker until renamed or killed in shpool
            processes = { enabled = true, session_prefix = "proc-" },
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
