local M = {}

-- Voice dictation: <leader>v toggles recording; on stop the clip is
-- transcribed locally (faster-whisper, CPU) and the text lands in the buffer
-- captured at record start — sent to the pty for terminals (AI prompts,
-- shells), inserted at the cursor for file buffers. No window-system
-- injection, so it works the same on X11, Wayland, and over ssh.

local recording_job = nil

M.model = "base"

-- Overridable seams: swap the recorder per machine, or point transcription
-- at something else (e.g. an API-based transcriber) without touching logic.
function M.record_command(path)
    return { "arecord", "-q", "-f", "S16_LE", "-r", "16000", "-c", "1", path }
end

function M.transcribe_command(path)
    local python = vim.fs.joinpath(vim.fn.stdpath("config"), ".venv", "bin", "python")
    if vim.fn.executable(python) ~= 1 then
        python = "python3"
    end

    return { python, vim.fs.joinpath(vim.fn.stdpath("config"), "scripts", "transcribe.py"), path, M.model }
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
    vim.system(M.transcribe_command(path), { text = true }, vim.schedule_wrap(function(result)
        vim.fn.delete(path)

        if result.code ~= 0 then
            vim.notify("Transcription failed: " .. vim.trim(result.stderr or ""), vim.log.levels.ERROR)
            return
        end

        local text = vim.trim(result.stdout or "")
        if text == "" then
            vim.notify("No speech detected", vim.log.levels.INFO)
            return
        end

        deliver(tgt, text)
    end))
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

    recording_job = vim.fn.jobstart(M.record_command(path), {
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
                recording_job = nil
                return
            end

            transcribe(path, captured_target)
        end),
    })

    if recording_job <= 0 then
        recording_job = nil
        vim.notify("Could not start recording", vim.log.levels.ERROR)
        return
    end

    vim.notify("Recording... press <leader>v to stop")
end

return M
