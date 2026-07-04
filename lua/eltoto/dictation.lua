local M = {}

-- Voice dictation: <leader>v toggles recording; on stop the clip is
-- transcribed locally (faster-whisper, CPU) and the text lands in the buffer
-- captured at record start — sent to the pty for terminals (AI prompts,
-- shells), inserted at the cursor for file buffers. No window-system
-- injection, so it works the same on X11, Wayland, and over ssh.

local recording_job = nil
local wav_path = nil
local target = nil -- captured at record start

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
    return {
        bufnr = bufnr,
        channel = vim.bo[bufnr].buftype == "terminal" and vim.bo[bufnr].channel or nil,
    }
end

local function deliver(text)
    if target and target.channel then
        if vim.api.nvim_buf_is_valid(target.bufnr) and vim.bo[target.bufnr].channel == target.channel then
            vim.api.nvim_chan_send(target.channel, text)
            return
        end
        vim.notify("Dictation target closed; transcript: " .. text, vim.log.levels.WARN)
        return
    end

    vim.api.nvim_put({ text }, "c", true, true)
end

local function transcribe(path)
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

        deliver(text)
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

    target = capture_target()
    wav_path = vim.fn.tempname() .. ".wav"

    local path = wav_path
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

            transcribe(path)
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
