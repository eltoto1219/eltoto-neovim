return {
    {
        "dense-analysis/ale",
        enabled = false,
        init = function()
            vim.g.ale_fixers = {
                python = {},
                javascript = {},
            }
            vim.g.ale_fix_on_save = 1
            vim.g.ale_fix_on_insert_leave = 0
            vim.g.ale_completion_enabled = 0
            vim.g.ale_completion_autoimport = 0
            vim.g.ale_linter_aliases = {}
            vim.g.ale_linters = {
                python = {},
                javascript = {},
            }
            vim.g.ale_linters_explicit = 0
            vim.g.ale_lint_on_text_changed = "never"
            vim.g.ale_lint_on_insert_leave = 0
            vim.b.ale_warn_about_trailing_whitespace = 0
            vim.g.ale_sign_column_always = 0
            vim.g.ale_set_highlights = 0
            vim.g.ale_sign_error = "!"
            vim.g.ale_sign_warning = "?"
            vim.g.LanguageClient_useVirtualText = 0
        end,
    },
}
