local M = {}
local env = require("eltoto.env")

function M.mason()
    return {
        ensure_installed = { "pylsp", "lua_ls" },
        automatic_enabled = true,
    }
end

function M.configs(capabilities)
    local pylsp_cmd = env.python_cmd()
    local pylsp = {
        capabilities = capabilities,
        cmd = pylsp_cmd,
        cmd_env = env.python_env(),
        configuration_sources = { "flake8", "ruff" },
        formatCommand = { "black" },
        settings = {
            pylsp = {
                plugins = {
                    black = { enabled = true },
                    isort = {
                        enabled = true,
                        args = { "--profile", "black", "--float-to-top", "true" },
                    },
                    mypy = { enabled = false },
                    jedi_completion = { enabled = true, include_completion = true, include_params = true },
                    jedi_signature_help = { enabled = true },
                    jedi_symbols = { enabled = true },
                    pylsp_black = { enabled = true, args = { "--line-length=88" } },
                    pylsp_isort = { enabled = false },
                    pylsp_mypy = { enabled = false },
                    pylint = { enabled = true, args = { "--ignore=E401,E501,E231", "-" } },
                    flake8 = {
                        enabled = true,
                        ignore = { "E203", "E741", "E501", "W503", "E402" },
                        args = { "--ignore=E203,E741,E501,W503,E402", "-" },
                    },
                    ropecompletion = { enabled = true },
                    pydocstyle = {
                        enabled = true,
                        ignore = {
                            "D100", "D101", "D102", "D103", "D104", "D105", "D106", "D107",
                            "D200", "D201", "D202", "D203", "D204", "D205", "D206", "D207",
                            "D208", "D209", "D210", "D211", "D212", "D213", "D214", "D215",
                            "D300", "D301", "D302", "D400", "D401", "D402", "D403", "D404",
                            "D405", "D406", "D407", "D408", "D409", "D410", "D411", "D412",
                            "D413", "D414", "D415",
                        },
                    },
                    yapf = { enabled = false },
                    pycodestyle = { enabled = false, args = { "--ignore=E402", "-" } },
                    autopep8 = { enabled = false },
                    pyflakes = { enabled = false },
                    mccabe = { enabled = false },
                },
            },
        },
    }

    local lua_ls = {
        capabilities = capabilities,
        settings = {
            Lua = {
                diagnostics = {
                    globals = { "vim", "it", "describe", "before_each", "after_each", "opts" },
                },
            },
        },
    }

    return {
        pylsp = pylsp,
        lua_ls = lua_ls,
    }
end

function M.register(capabilities)
    for server_name, config in pairs(M.configs(capabilities)) do
        vim.lsp.config(server_name, config)
    end
end

return M
