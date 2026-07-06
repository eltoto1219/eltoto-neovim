local M = {}

-- Voice dictation: <leader>v toggles recording; on stop the clip is
-- transcribed locally (faster-whisper, GPU when available) and the text lands
-- in the buffer captured at record start — sent to the pty for terminals (AI
-- prompts, shells), inserted at the cursor for file buffers. No window-system
-- injection, so it works the same on X11, Wayland, and over ssh.
-- Transcription runs in a persistent transcribe.py --serve job so the model
-- loads once per nvim session, not once per dictation.

local recording_job = nil

-- nil = script default (medium on GPU, base on CPU); set to force a model.
M.model = nil

-- Overridable seams: swap the recorder per machine, or point transcription
-- at something else (e.g. an API-based transcriber) without touching logic.
function M.record_command(path)
    return { "arecord", "-q", "-f", "S16_LE", "-r", "16000", "-c", "1", path }
end

function M.serve_command()
    local python = vim.fs.joinpath(vim.fn.stdpath("config"), ".venv", "bin", "python")
    if vim.fn.executable(python) ~= 1 then
        python = "python3"
    end

    local cmd = { python, vim.fs.joinpath(vim.fn.stdpath("config"), "scripts", "transcribe.py"), "--serve" }
    if M.model then
        table.insert(cmd, M.model)
    end
    return cmd
end

-- One transcript line comes back per wav path sent; pending callbacks are
-- resolved in send order.
local server_job = nil
local pending = {}
local stdout_partial = ""

local function ensure_server()
    if server_job then
        return server_job
    end

    stdout_partial = ""
    server_job = vim.fn.jobstart(M.serve_command(), {
        on_stdout = function(_, data)
            data[1] = stdout_partial .. data[1]
            stdout_partial = table.remove(data)
            for _, line in ipairs(data) do
                local callback = table.remove(pending, 1)
                if callback then
                    vim.schedule(function()
                        callback(line)
                    end)
                end
            end
        end,
        on_exit = vim.schedule_wrap(function()
            server_job = nil
            stdout_partial = ""
            local failed = pending
            pending = {}
            for _, callback in ipairs(failed) do
                callback(nil)
            end
        end),
    })
    if server_job <= 0 then
        server_job = nil
    end
    return server_job
end

local function capture_target()
    local bufnr = vim.api.nvim_get_current_buf()
    local is_terminal = vim.bo[bufnr].buftype == "terminal"
    return {
        bufnr = bufnr,
        channel = is_terminal and vim.bo[bufnr].channel or nil,
        cursor = not is_terminal and vim.api.nvim_win_get_cursor(0) or nil,
    }
end

local function deliver(tgt, text)
    if tgt.channel then
        if vim.api.nvim_buf_is_valid(tgt.bufnr) and vim.bo[tgt.bufnr].channel == tgt.channel then
            vim.api.nvim_chan_send(tgt.channel, text)
            return
        end
        vim.notify("Dictation target closed; transcript: " .. text, vim.log.levels.WARN)
        return
    end

    if not vim.api.nvim_buf_is_valid(tgt.bufnr) then
        vim.notify("Dictation target closed; transcript: " .. text, vim.log.levels.WARN)
        return
    end

    local row = tgt.cursor[1] - 1
    local col = tgt.cursor[2]
    vim.api.nvim_buf_set_text(tgt.bufnr, row, col, row, col, { text })
end

local function transcribe(path, tgt)
    vim.notify("Transcribing...")
    if not ensure_server() then
        vim.fn.delete(path)
        vim.notify("Could not start transcription server", vim.log.levels.ERROR)
        return
    end

    table.insert(pending, function(line)
        vim.fn.delete(path)

        if line == nil then
            vim.notify("Transcription failed (server exited)", vim.log.levels.ERROR)
            return
        end

        local text = vim.trim(line)
        if text == "" then
            vim.notify("No speech detected", vim.log.levels.INFO)
            return
        end

        deliver(tgt, text)
    end)
    vim.fn.chansend(server_job, path .. "\n")
end

function M.toggle()
    if recording_job then
        -- SIGTERM (not jobstop's SIGHUP) so arecord finalizes the wav header.
        local pid = vim.fn.jobpid(recording_job)
        recording_job = nil
        if pid > 0 then
            vim.uv.kill(pid, "sigterm")
        end
        return
    end

    if vim.fn.executable(M.record_command("")[1]) ~= 1 then
        vim.notify(M.record_command("")[1] .. " is required for dictation", vim.log.levels.WARN)
        return
    end

    local captured_target = capture_target()
    local path = vim.fn.tempname() .. ".wav"

    local this_job
    this_job = vim.fn.jobstart(M.record_command(path), {
        on_exit = vim.schedule_wrap(function(_, code)
            -- SIGTERM exit is the normal stop; only bail on startup failures
            -- that left no usable recording behind.
            if vim.fn.getfsize(path) <= 44 then
                vim.fn.delete(path)
                if code ~= 0 then
                    vim.notify("Recording failed (arecord exit " .. code .. ")", vim.log.levels.ERROR)
                else
                    vim.notify("No audio captured", vim.log.levels.WARN)
                end
                if recording_job == this_job then
                    recording_job = nil
                end
                return
            end

            transcribe(path, captured_target)
        end),
    })
    recording_job = this_job

    if recording_job <= 0 then
        recording_job = nil
        vim.notify("Could not start recording", vim.log.levels.ERROR)
        return
    end

    vim.notify("Recording... press <leader>v to stop")
end

return M
