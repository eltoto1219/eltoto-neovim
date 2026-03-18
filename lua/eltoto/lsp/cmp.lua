local M = {}

function M.setup()
    local cmp = require("cmp")
    local cmp_select = { behavior = cmp.SelectBehavior.Select }
    local bordered_window = cmp.config.window.bordered({
        border = "rounded",
        winhighlight = table.concat({
            "Normal:Pmenu",
            "FloatBorder:FloatBorder",
            "CursorLine:PmenuSel",
            "Search:None",
        }, ","),
    })

    cmp.setup({
        preselect = true,
        completion = {
            completeopt = "menu,menuone,noinsert",
        },
        window = {
            completion = bordered_window,
            documentation = bordered_window,
        },
        sources = cmp.config.sources({
            { name = "pylsp" },
            { name = "nvim_lsp" },
            { name = "nvim_lua" },
            { name = "luasnip" },
            { name = "buffer" },
            { name = "path" },
            {
                name = "cmdline",
                option = {
                    ignore_cmds = { "Man", "!" },
                },
            },
        }),
        mapping = cmp.mapping.preset.insert({
            ["<C-Space>"] = cmp.mapping.confirm({ select = true }),
            ["<Esc>"] = cmp.mapping.abort(),
            ["<S-Tab>"] = cmp.mapping.select_prev_item(cmp_select),
            ["<Tab>"] = cmp.mapping.select_next_item(cmp_select),
            ["<C-p>"] = cmp.mapping(function()
                if cmp.visible() then
                    cmp.select_prev_item({ behavior = "insert" })
                else
                    cmp.complete()
                end
            end),
            ["<C-n>"] = cmp.mapping(function()
                if cmp.visible() then
                    cmp.select_next_item({ behavior = "insert" })
                else
                    cmp.complete()
                end
            end),
        }),
        snippet = {
            expand = function(args)
                require("luasnip").lsp_expand(args.body)
            end,
        },
    })
end

return M
