local M = {}

function M.setup()
    local group = vim.api.nvim_create_augroup("EltotoLspKeymaps", { clear = true })

    vim.api.nvim_create_autocmd("LspAttach", {
        group = group,
        callback = function(event)
            local opts = { buffer = event.buf, silent = true }

            vim.keymap.set("n", "gd", vim.lsp.buf.definition, vim.tbl_extend("force", opts, { desc = "LSP definition" }))
            vim.keymap.set("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", opts, { desc = "LSP hover" }))
            vim.keymap.set("n", "<leader>vw", vim.lsp.buf.workspace_symbol, vim.tbl_extend("force", opts, { desc = "LSP workspace symbols" }))
            vim.keymap.set("n", "<leader>vd", vim.diagnostic.open_float, vim.tbl_extend("force", opts, { desc = "Diagnostic float" }))
            vim.keymap.set("n", "<leader>vc", vim.lsp.buf.code_action, vim.tbl_extend("force", opts, { desc = "LSP code action" }))
            vim.keymap.set("n", "<leader>vr", vim.lsp.buf.references, vim.tbl_extend("force", opts, { desc = "LSP references" }))
            vim.keymap.set("n", "<leader>vn", vim.lsp.buf.rename, vim.tbl_extend("force", opts, { desc = "LSP rename symbol" }))
            vim.keymap.set("n", "<leader>r", vim.diagnostic.open_float, vim.tbl_extend("force", opts, { desc = "Show diagnostic" }))
            vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, vim.tbl_extend("force", opts, { desc = "Diagnostics to loclist" }))
            vim.keymap.set("i", "<C-h>", vim.lsp.buf.signature_help, vim.tbl_extend("force", opts, { desc = "LSP signature help" }))
        end,
    })
end

return M
