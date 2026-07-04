local M = {}

function M.setup()
    vim.diagnostic.config({
        virtual_text = false,
        float = {
            focusable = false,
            style = "minimal",
            border = "rounded",
            source = true,
            header = "",
            prefix = "",
        },
    })
end

return M
