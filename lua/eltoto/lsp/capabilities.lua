local M = {}

function M.make()
    local cmp_lsp = require("cmp_nvim_lsp")

    return vim.tbl_deep_extend(
        "force",
        {},
        vim.lsp.protocol.make_client_capabilities(),
        cmp_lsp.default_capabilities()
    )
end

return M
