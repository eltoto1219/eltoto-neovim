local M = {}

local function plugin_status(module_name)
    local ok = pcall(require, module_name)
    return ok and "ok" or "missing"
end

local function command_status(command_name)
    return vim.fn.executable(command_name) == 1 and "ok" or "missing"
end

local function path_status(path)
    return path ~= "" and vim.fn.executable(path) == 1 and "ok" or "missing"
end

local function python_module_status(python, module_name)
    if python == "" or vim.fn.executable(python) ~= 1 then
        return "missing"
    end

    vim.fn.system({ python, "-c", "import " .. module_name })
    return vim.v.shell_error == 0 and "ok" or "missing"
end

local function report_lines()
    local env = require("eltoto.env")
    local python_host = vim.g.python3_host_prog or ""
    local pylsp_cmd = env.python_cmd()
    local pylsp_rendered = pylsp_cmd and table.concat(pylsp_cmd, " ") or "unavailable"
    local repo_python = env.python
    local uses_repo_python = python_host ~= "" and vim.fs.normalize(python_host) == vim.fs.normalize(repo_python)

    return {
        "Eltoto Health",
        "config_root: " .. env.config_root,
        "venv_dir: " .. env.venv_dir,
        "venv_exists: " .. tostring(vim.fn.isdirectory(env.venv_dir) == 1),
        "repo_python: " .. repo_python,
        "repo_python_executable: " .. path_status(repo_python),
        "python3_host_prog: " .. (python_host ~= "" and python_host or "unset"),
        "python3_host_uses_repo_venv: " .. tostring(uses_repo_python),
        "has_python3_provider: " .. tostring(vim.fn.has("python3") == 1),
        "pylsp_cmd: " .. pylsp_rendered,
        "pynvim_module: " .. python_module_status(python_host, "pynvim"),
        "pylsp_module: " .. python_module_status(python_host, "pylsp"),
        "python3_executable: " .. command_status("python3"),
        "git_executable: " .. command_status("git"),
        "nvim_executable: " .. command_status("nvim"),
        "rg_executable: " .. command_status("rg"),
        "cmp_module: " .. plugin_status("cmp"),
        "luasnip_module: " .. plugin_status("luasnip"),
        "noice_module: " .. plugin_status("noice"),
        "trouble_module: " .. plugin_status("trouble"),
    }
end

function M.run()
    vim.notify(table.concat(report_lines(), "\n"), vim.log.levels.INFO, {
        title = "Eltoto Health",
        timeout = 10000,
    })
end

function M.register()
    vim.api.nvim_create_user_command("EltotoHealth", M.run, {
        desc = "Show environment and plugin health for this config",
    })
end

return M
