local M = {}

M.codex_model = "gpt-5.3-codex"

local function openai_key_status()
    local value = vim.env.OPENAI_API_KEY or ""
    return value ~= "" and "set" or "missing"
end

local function copilot_status()
    if vim.fn.exists(":Copilot") ~= 2 then
        return "missing"
    end

    local ok, output = pcall(vim.fn.execute, "silent Copilot status")
    if not ok then
        return "unavailable"
    end

    output = vim.trim(output or "")
    output = output:gsub("^Copilot:%s*", "")

    return output ~= "" and output or "unknown"
end

local function avante_status()
    return pcall(require, "avante") and "ok" or "missing"
end

local function command_status(command_name)
    return vim.fn.executable(command_name) == 1 and "ok" or "missing"
end

function M.report_lines()
    return {
        "Eltoto AI Status",
        "openai_api_key: " .. openai_key_status(),
        "codex: " .. command_status("codex"),
        "avante_model: " .. M.codex_model,
        "avante_module: " .. avante_status(),
        "copilot_status: " .. copilot_status(),
    }
end

function M.run()
    vim.notify(table.concat(M.report_lines(), "\n"), vim.log.levels.INFO, {
        title = "Eltoto AI Status",
        timeout = 10000,
    })
end

function M.register()
    vim.api.nvim_create_user_command("AIStatus", M.run, {
        desc = "Show AI provider, model, and auth status",
    })
end

return M
