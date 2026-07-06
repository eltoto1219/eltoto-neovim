# eltoto.nvim - agent notes

Project memory for agents.
Add only what saves tokens or time later; corrections from Antonio go here so they are not repeated.

## Ground rules

- The leader key is "w" (`vim.g.mapleader = "w"`), so `<leader>t` means `wt`.
- Antonio renames keybinds himself between sessions; always grep `remap.lua` for the current binding instead of trusting docs or past conversations.
- Some of Antonio's machines have no root; every dependency in `scripts/setup.sh` must install user-locally (see rustup/cargo, shpool, brew clone, npm --prefix patterns already there) and degrade with a `warn` instead of failing.
- `SHORTCUTS.txt` and the README shortcuts section are generated: edit `lua/eltoto/shortcut_data.lua`, then run `nvim --headless "+ShortcutsSync" "+qa"`.
- After changes run `./scripts/check.sh` from the repo root; it must pass.
- GNOME Terminal with scrollback-lines=10000 is the sizing reference for anything scrollback related.

## Architecture map

- `lua/eltoto/terminal.lua`: terminal buffer workflow (toggle, cycle, labels T:n, custom labels).
- `lua/eltoto/processes.lua` + `process_backend.lua`: persistent terminals backed by shpool (`shpool attach -f eltoto-process-<name>`); labels are `P:<name>`; scrollback is native in the nvim buffer, shpool replays the last 10000 lines on reattach (`~/.config/shpool/config.toml`).
- `lua/eltoto/ai_sessions.lua`: claude/codex sessions in terminal buffers; registry in stdpath("state")/eltoto/ai_sessions.json; always-on CLI flags live in `claude_args`/`codex_args` there (shell aliases never apply to termopen).
- `lua/eltoto/dictation.lua`: `<leader>v` voice dictation (arecord + faster-whisper from the repo `.venv`, `scripts/transcribe.py`).
- `lua/eltoto/ui/tabline.lua`: context-sensitive tabline with three groups: files, plain terminals, AI buffers.
- `lua/eltoto/ui/picker.lua`: shared centered floating list picker; reuse it for any new picker.

## Sharp edges

- AI buffers are terminals tagged with `vim.b.eltoto_ai_kind`; the tag must be set BEFORE `termopen` runs (passed as `ai_kind` in `open_command` opts) because TermOpen/BufEnter autocmds fire inside termopen.
- `<leader>t` and terminal fallbacks must never land on AI buffers; use `plain_terminal_buffers()` in terminal.lua.
- `nvim --headless -l script.lua` skips init.lua: modules load but no autocmds exist; call `buffers/terminal/ai_sessions .setup()` explicitly in test scripts, and use `vim.wait`, not `defer_fn`.
- Stopping a recording job needs SIGTERM via `vim.uv.kill` (jobstop sends SIGHUP and arecord leaves a broken wav header).
- shpool spawns login shells; `.bashrc` sourcing for login shells is handled by `ensure_login_shell_sources_bashrc` in setup.sh.
- The live agent input box is drawn inside a border and never matches `terminal.M.prompt_pattern`; `]a` handles it with an explicit jump-to-bottom fallback.
- In `-l` test scripts `startinsert` stays pending until the script ends, so terminal-input mode cannot be asserted; tests also must never send a bare `claude`/`codex` to a shell (it launches a real session whose TUI repaints the buffer).

## Corrections log

- 2026-07-03: `:AIRestore` must be scoped to the current working directory, not all cached sessions.
- 2026-07-03: `<leader>aa`-style pickers should list cached (restorable) sessions too, not only open buffers.
- 2026-07-04: treehouse acquisition offers an agent via popup (q/Esc = plain shell), never a hardcoded autostart; agents in workspaces stay out of the ai_sessions registry (shpool already provides their persistence).
