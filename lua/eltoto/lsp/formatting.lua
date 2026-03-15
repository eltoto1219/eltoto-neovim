local M = {}

function M.setup()
    local augroup = vim.api.nvim_create_augroup("LspAutoFormat", { clear = true })

    vim.api.nvim_create_autocmd("LspAttach", {
        group = augroup,
        callback = function(args)
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            local bufnr = args.buf

            if not client or not client.server_capabilities.documentFormattingProvider then
                return
            end

            vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
            vim.api.nvim_create_autocmd("BufWritePre", {
                group = augroup,
                buffer = bufnr,
                callback = function()
                    vim.lsp.buf.format({ async = false, bufnr = bufnr, id = client.id })
                end,
            })
        end,
    })
end

return M
