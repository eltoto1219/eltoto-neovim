# eltoto.nvim - agent notes

Project memory for agents.
Add only what saves tokens or time later; corrections from Antonio go here so they are not repeated.

## Ground rules

- The leader key is "w" (`vim.g.mapleader = "w"`), so `<leader>t` means `wt`.
- Antonio renames keybinds himself between sessions; always grep `remap.lua` for the current binding instead of trusting docs or past conversations.
- Some of Antonio's machines have no root; every dependency in `scripts/setup.sh` and `scripts/agent_setup.sh` must install user-locally (see rustup/cargo, shpool, brew clone, npm --prefix, Go tarball patterns already there) and degrade with a `warn` instead of failing.
- Setup is split: `scripts/setup.sh` = editor stack (nvim, python, shpool, brew, fonts), `scripts/agent_setup.sh` = agent stack (codex, claude, logins, skills, axi, no-mistakes, treehouse); shared helpers live in `scripts/lib.sh` (sourced, not executed). setup.sh calls agent_setup.sh at the end; both are idempotent.
- `agent/` holds canonical copies of the live agent files (`~/.claude/CLAUDE.md`, `~/OPINIONS.md`, `~/VOICE.md`, `~/.no-mistakes/config.yaml`) plus `motive-skills.txt` (the Motive skill set setup installs). Live files are the source of truth: run `scripts/agent_sync.sh` to copy them back into `agent/`; `check.sh` warns on drift and on skills no setup source covers. `~/AGENTS.md` and `~/.codex/AGENTS.md` are symlinks to `~/.claude/CLAUDE.md`.
- `SHORTCUTS.txt` and the README shortcuts section are generated: edit `lua/eltoto/shortcut_data.lua`, then run `nvim --headless "+ShortcutsSync" "+qa"`.
- After changes run `./scripts/check.sh` from the repo root; it must pass.
- GNOME Terminal with scrollback-lines=10000 is the sizing reference for anything scrollback related.

## Architecture map

- `lua/eltoto/terminal.lua`: terminal buffer workflow (toggle, cycle, labels T:n, custom labels).
- `lua/eltoto/processes.lua` + `process_backend.lua`: persistent terminals backed by shpool (`shpool attach -f eltoto-process-<name>`); labels are `P:<name>`; creation directories are stored in stdpath("state")/eltoto/process_cwds.json for cwd-scoped attach; scrollback is native in the nvim buffer, shpool replays the last 10000 lines on reattach (`~/.config/shpool/config.toml`).
- `lua/eltoto/ai_sessions.lua`: claude/codex sessions in terminal buffers; registry in stdpath("state")/eltoto/ai_sessions.json; always-on CLI flags live in `claude_args`/`codex_args` there (shell aliases never apply to termopen).
- `lua/eltoto/dictation.lua`: `<leader>v` voice dictation (arecord + faster-whisper from the repo `.venv`); transcription runs in a persistent `scripts/transcribe.py --serve` job (one wav path in and one JSON response out per line) so the model loads once per nvim session; model auto-picks medium on GPU / base on CPU (`M.model = nil` = auto), and GPU failures switch that server process to CPU.
- `lua/eltoto/plugins/barline.lua`: lualine config; branch shown via a custom function - uses `treehouse.current_buf_branch()` when in a workspace buffer, else `FugitiveHead()`; a `vim.uv.new_fs_event` watcher filters the relevant git directory for `HEAD` changes, then calls `FugitiveDidChange`, refreshes Treehouse caches, and refreshes lualine so terminal-side branch ops appear immediately.
- `lua/eltoto/ui/tabline.lua`: context-sensitive tabline with three groups: files, plain terminals, AI buffers.
- `lua/eltoto/ui/picker.lua`: shared centered floating list picker; reuse it for any new picker.

## Sharp edges

- AI buffers are terminals tagged with `vim.b.eltoto_ai_kind`; the tag must be set BEFORE `termopen` runs (passed as `ai_kind` in `open_command` opts) because TermOpen/BufEnter autocmds fire inside termopen.
- `<leader>t` and terminal fallbacks must never land on AI buffers; use `plain_terminal_buffers()` in terminal.lua.
- `nvim --headless -l script.lua` skips init.lua: modules load but no autocmds exist; call `buffers/terminal/ai_sessions .setup()` explicitly in test scripts, and use `vim.wait`, not `defer_fn`.
- Stopping a recording job needs SIGTERM via `vim.uv.kill` (jobstop sends SIGHUP and arecord leaves a broken wav header).
- shpool spawns login shells; `.bashrc` sourcing for login shells is handled by `ensure_login_shell_sources_bashrc` in setup.sh.
- The live agent input box is drawn inside a border and never matches `terminal.M.prompt_pattern`; `]a` handles it with an explicit jump-to-bottom fallback that stays in normal mode.
- In `-l` test scripts `startinsert` stays pending until the script ends, so terminal-input mode cannot be asserted; tests also must never send a bare `claude`/`codex` to a shell (it launches a real session whose TUI repaints the buffer).
- To repro real keybind flows (t-mode maps, mode transitions): run `nvim --listen <sock>` inside tmux, drive keys with `tmux send-keys`, assert via `nvim --server <sock> --remote-expr`; fake an AI buffer with `terminal.open_command('<script>', 'x', {ai_kind='claude'})`. `:messages`/`execute("messages")` is empty under noice, useless for debugging.
- `nvim_buf_set_name` has `:file` semantics: the old name lands on a new unlisted buffer, and a later rename to a name such a leftover holds fails with E95. `refresh_names` in terminal.lua wipes those holders; any new buffer-renaming code must do the same.
- Terminal/AI toggles must always land somewhere: with no file ever opened, `get_last_edit_buf()` is nil - fall back via `buffers.get_edit_return_buf()` (else the toggle silently no-ops after the t-mode map already left insert mode).

## Corrections log

- 2026-07-03: `:AIRestore` must be scoped to the current working directory, not all cached sessions.
- 2026-07-03: The `<leader>n` session picker should list cached (restorable) sessions too, not only open buffers.
- 2026-07-04: treehouse acquisition offers an agent via popup (q/Esc = plain shell), never a hardcoded autostart; agents in workspaces stay out of the ai_sessions registry (shpool already provides their persistence).
