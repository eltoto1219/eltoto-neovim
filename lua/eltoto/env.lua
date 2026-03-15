local M = {}

local path_sep = package.config:sub(1, 1) == "\\" and ";" or ":"
local launch_env = vim.fn.environ()

M.config_root = vim.fs.normalize(vim.fn.stdpath("config"))
M.venv_dir = M.config_root .. "/.venv"
M.bin_dir = M.venv_dir .. "/bin"
M.python = M.bin_dir .. "/python"

local function is_executable(path)
    return path ~= nil and path ~= "" and vim.fn.executable(path) == 1
end

local function first_executable(candidates)
    for _, candidate in ipairs(candidates) do
        if is_executable(candidate) then
            return candidate
        end
    end

    return ""
end

function M.python_host_prog()
    return first_executable({
        M.python,
        vim.fn.exepath("python3"),
        vim.fn.exepath("python"),
    })
end

function M.python_cmd()
    local python = M.python_host_prog()

    if python == "" then
        return nil
    end

    return { python, "-m", "pylsp" }
end

function M.python_env()
    local path = os.getenv("PATH") or ""
    local entries = { M.bin_dir }

    if path ~= "" then
        entries[#entries + 1] = path
    end

    return {
        VIRTUAL_ENV = M.venv_dir,
        PATH = table.concat(entries, path_sep),
    }
end

function M.terminal_env()
    return vim.deepcopy(launch_env)
end

return M
