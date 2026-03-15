return {
    "neovim/nvim-lspconfig",
    dependencies = {
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-path",
        "hrsh7th/cmp-cmdline",
        "hrsh7th/nvim-cmp",
        "L3MON4D3/LuaSnip",
        "saadparwaiz1/cmp_luasnip",
        "j-hui/fidget.nvim",
    },
    config = function()
        local capabilities = require("eltoto.lsp.capabilities").make()
        local servers = require("eltoto.lsp.servers")

        require("fidget").setup({
            progress = {
                ignore = { "pylsp" },
            },
        })
        require("mason").setup({})
        require("mason-lspconfig").setup(servers.mason())

        servers.register(capabilities)
        require("eltoto.lsp.formatting").setup()
        require("eltoto.lsp.cmp").setup()
        require("eltoto.lsp.diagnostics").setup()
        require("eltoto.lsp.keymaps").setup()
    end,
}
