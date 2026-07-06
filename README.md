# 🛠️ eltoto.nvim

Portable, terminal-centered Neovim workflow with a repo-local Python toolchain, custom buffer and terminal navigation, generated shortcut docs, and bootstrap scripts for Linux and macOS.

> A process-aware Neovim workbench:
> edit code, run files, manage durable terminals, use AI deliberately, and recover the whole setup quickly on a new machine.

### 🌟 At a Glance

- ⚙️ Repo-local Python tooling for a stable Neovim environment
- 🖥️ Separate workflows for file buffers, terminal buffers, and persistent shpool-backed processes
- 🤖 Copilot for inline completion and Claude/Codex harness sessions for explicit AI workflows
- 📚 Generated shortcut docs in the README, `SHORTCUTS.txt`, and `:Shortcuts`
- 🩺 Setup, health, and check scripts so the config can verify itself

## 📚 Table of Contents

- [Quick Start](#-quick-start)
- [What This Project Does](#-what-this-project-does)
- [Why This Is Awesome](#-why-this-is-awesome)
- [Core Capabilities](#-core-capabilities)
- [Who This Is For](#-who-this-is-for)
- [Typical Workflow](#-typical-workflow)
- [Bootstrap](#-bootstrap)
- [Python Environment](#-python-environment)
- [Required Dependencies](#-required-dependencies)
- [Treehouse Workspaces](#-treehouse-workspaces)
- [AI Setup](#-ai-setup)
- [AI Workflow](#-ai-workflow)
- [Fonts](#-fonts)
- [Health Check](#-health-check)
- [Troubleshooting](#-troubleshooting)
- [Shortcuts](#shortcuts)
- [Useful Commands](#-useful-commands)
- [Recovery](#-recovery)
- [Notes](#-notes)

## ⚡ Quick Start

```bash
git clone https://github.com/eltoto1219/eltoto-neovim.git ~/.config/nvim
cd ~/.config/nvim
./scripts/setup.sh
```

Then:

1. Open Neovim.
2. Run `:AIStatus` to confirm your AI environment is visible.
3. Open the shortcut popup with `<leader>?`.
4. Start working with `<leader>pf`, `<leader>t`, `<leader>e`, and `<leader>m`.

## ✨ What This Project Does

This project turns Neovim into a portable personal workbench with:

- a repo-local Python environment for Neovim itself, so editor tooling stays separate from project virtualenvs
- custom regular-buffer and terminal-buffer workflows, including named terminal buffers like `T:1`, `T:2`, and direct `:b T:1` navigation
- persistent terminal processes backed by `shpool`, so long-running jobs survive buffer closes and Neovim restarts
- isolated Git workspaces managed by Treehouse and kept alive in persistent `shpool` sessions
- AI assistance through Copilot inline completions and Claude/Codex harness sessions in terminal buffers
- fast project search with Telescope
- semantic symbol rename through LSP for supported languages
- filetype-aware run-current-file behavior via `<leader>e`, with session-only overrides through `:TerminalConfig`
- bootstrap scripts for fonts, dependencies, Mason installs, Python setup, and plugin sync
- a health command and a check script so the setup can verify itself after changes or on a fresh machine

## 🔥 Why This Is Awesome

This repo is strong because it is not just a Neovim config. It is an opinionated working system.

Most configs stop at plugins and keymaps. This one goes further:

- 🚀 It bootstraps a fresh machine quickly, including fonts, Python tooling, plugin sync, Mason installs, and optional Copilot auth.
- 🧪 It isolates Neovim’s Python environment from project virtualenvs, which keeps editor tooling stable.
- 🗂️ It has separate, deliberate workflows for files, terminals, and persistent shpool-backed processes.
- ▶️ It can run the current file intelligently by filetype instead of making you context-switch into another shell.
- 🤖 It treats AI as a tool, not as the center of the editor. Copilot stays lightweight, while Claude and Codex run in plain terminal buffers with native scrollback, a dedicated tabline group, session caching, and voice dictation injection.
- 🩺 It is maintainable. `:EltotoHealth` and `./scripts/check.sh` give you a direct way to verify the setup instead of guessing.
- 🎛️ It has a real UI layer. The tabline, terminal names, and AI session views reflect how the workflow actually works, not just what Neovim happens to expose by default.

The uncommon part is the combination:

- portability
- workflow design
- operational tooling
- generated documentation
- health checks
- persistent processes
- terminal-first interaction
- deliberate AI integration

That is what makes it feel like a workbench instead of a pile of plugins.

## 🧰 Core Capabilities

- Install a Nerd Font with `./scripts/font_setup.sh`
- Run a full config check with `./scripts/check.sh`
- Open the generated shortcut popup with `:Shortcuts` or `<leader>?`
- Configure session-only filetype runner overrides with `:TerminalConfig`
- Navigate regular buffers and terminal buffers with separate rules
- Open, reuse, and cycle through named terminal buffers
- Create, attach, list, and kill persistent terminal processes without leaving Neovim
- Acquire, inspect, reopen, and return Treehouse-managed Git workspaces
- Run current files through filetype-aware runners inside the Neovim terminal workflow
- Use Claude or Codex harness sessions for in-editor AI chat workflows
- Use GitHub Copilot for inline completions
- Use LSP for definitions, hover, references, rename, diagnostics, and completion
- Use Telescope for file and buffer discovery

## 👥 Who This Is For

This setup is for people who want Neovim to behave like a real coding workbench instead of just a text editor with plugins.

It is a good fit if you:

- work from the terminal most of the time
- want to run code, manage shells, and keep long-lived processes close to your editor
- use Python enough to care about keeping editor tooling separate from project virtualenvs
- want AI help in Neovim without turning the whole editor into a chat product
- care about portability, bootstrap speed, and being able to clone your setup onto a new machine quickly

It is probably not the right fit if you want a minimal config, a stock distro-style setup, or a GUI-first Neovim workflow.

## 🔄 Typical Workflow

A common workflow in this config looks like this:

1. Open a project and jump around with Telescope using `<leader>pf`, `<leader>ps`, `<leader>pg`, and `<leader>bb`.
2. Edit across normal file buffers with `<leader>;`, `<leader>,`, splits, and window navigation.
3. Use `<leader>t` or `<leader>T` for short-lived terminal work inside Neovim.
4. Use `<leader>pn` to create a persistent shpool-backed process for anything long-running, then `<leader>pp` or `<leader>pa` to reattach later.
5. Use `<leader>fa` for a disposable Treehouse workspace or `<leader>fl` for a named lease, then work in its persistent terminal session.
6. Run the current file with `<leader>e`, using the filetype-aware runner instead of opening another shell manually.
7. Use `<leader>m` to toggle the last AI buffer or `<leader>M` to open a new Claude or Codex session.
8. Use `:AIStatus`, `:EltotoHealth`, and `./scripts/check.sh` when something looks wrong instead of guessing.

The point is that editing, running code, long-lived processes, and AI assistance all live in one coherent workflow.

## 🚀 Bootstrap

The setup script will:

- run dependency preflight checks
- prompt per missing system dependency and install only the ones you approve, with `a` available to install all remaining prompts at once
- create a repo-local `.venv`
- install Python packages from `reqs.txt`
- attempt to pre-download the faster-whisper dictation model selected for the available GPU or CPU
- add an `OPENAI_API_KEY` placeholder to your shell rc file if neither your current environment nor that rc file already defines it
- add `~/.local/bin` to your shell `PATH` when needed for user-local AI tooling
- install Hack Nerd Font into your user font directory
- sync plugins with `lazy.nvim`
- install `codex` globally into `~/.local` through `npm` when it is missing
- install `lua-language-server` through Mason

## 🐍 Python Environment

This config intentionally uses its own Python environment at `.venv/`.

That keeps Neovim tooling like:

- `pynvim`
- `python-lsp-server`
- `black`
- `isort`
- `flake8`

out of your project virtualenvs.

`python3_host_prog` and the `pylsp` command are both resolved from the repo-local `.venv` when it exists.

## 📦 Required Dependencies

The setup script checks for and can prompt to install, with `a` available to install all remaining prompts at once:

- `git`
- `python3` or `python`
- Python `venv` support
- `curl` or `wget`
- `unzip`

It also checks for these recommended tools, and prompts to install them when it can:

- `nvim`
- `tar`
- `ripgrep`
- `node`
- `make`
- `gcc` or `clang`

It also installs `shpool` (via a user-local rustup/cargo, no root required) to back persistent terminal processes, and writes `~/.config/shpool/config.toml` with a 10000-line restore window.

On Linux it installs Homebrew user-locally (cloned to `~/.linuxbrew`, no root required) and adds `brew shellenv` to your shell rc. Note: the non-default prefix means some brew packages compile from source instead of using prebuilt bottles.

Treehouse is an optional external dependency and is not installed by `scripts/setup.sh`. Install the `treehouse` executable using the [upstream instructions](https://github.com/kunchenguid/treehouse#install) and ensure it is on Neovim's `PATH` to use the workspace mappings.

## 🌳 Treehouse Workspaces

The Treehouse integration is a launcher and visibility layer over Treehouse's reusable Git worktree pool. Run the mappings from inside the repository whose pool you want to use:

- `<leader>fa` acquires an auto-named disposable workspace.
- `<leader>fl` prompts for a task name and records it as the lease holder.
- `<leader>fw` reopens an active `shpool` session and shows its cached branch and dirty state.
- `<leader>fs` shows the full `treehouse status` output, including workspace paths.
- `<leader>fr` previews commits and working-tree changes, then returns and resets the workspace only after `r` confirms it.

After a successful acquisition, a picker offers to start Claude or Codex in the workspace; press `q` or `Esc` to keep the plain shell. Selecting an agent that is not installed reports the problem and also leaves the shell active. A selected agent runs inside the workspace's `shpool` session with the same always-on CLI flags as a regular AI session, including Claude's `--dangerously-skip-permissions` or Codex's approval, sandbox, and hook-trust bypasses. It stays out of the AI session registry because `shpool` already provides its persistence.

Every acquired workspace uses a durable Treehouse lease and a persistent `shpool` session named `th:<task>`. It appears as `P:th:<task>` in the persistent process picker and survives terminal-buffer closes and Neovim restarts. The statusline shows the task, branch, and `*` when the workspace is dirty.

Workspace paths are cached only for the current Neovim process. After restarting Neovim, use `<leader>fs` to recover a path; existing Treehouse sessions can still be reopened with `<leader>fw`, but returning a workspace requires its path to have been cached in the current process.

## 🤖 AI Setup

This config uses two separate auth paths:

- OpenAI / Codex: set `OPENAI_API_KEY` in your shell profile, for example in `~/.bashrc` or `~/.zshrc`
- GitHub Copilot: run `:Copilot setup` once inside Neovim and sign in with your GitHub account

Recommended model choices:

- Copilot inline completions: keep the default Copilot inline model, because `copilot.vim` does not expose a repo-local per-model inline selector here

This repo does not store API keys. Keep `OPENAI_API_KEY` in your shell environment so both terminal Codex and Neovim can use the same credential.

## 🧠 AI Workflow

This setup intentionally uses two different AI modes for two different jobs:

- Use Copilot for inline completion while you are already typing and do not want to stop your flow.
- Use Claude or Codex harness sessions when you want an explicit conversation or agentic help in a terminal buffer inside Neovim.

The practical split is:

- Copilot: fast, low-friction, inline suggestions
- Claude / Codex sessions: deliberate in-editor help in a native terminal buffer with full scrollback, visual mode, and voice dictation

That separation keeps AI useful without letting it take over the whole editor.

## 🔤 Fonts

The setup script runs `scripts/font_setup.sh`, which installs Hack Nerd Font into the user font directory:

- Linux: `~/.local/share/fonts`
- macOS: `~/Library/Fonts`

After installation, you still need to configure your terminal emulator to use the font.

## 🩺 Health Check

Inside Neovim, run:

```vim
:EltotoHealth
```

This reports:

- resolved config root
- resolved `.venv`
- active `python3_host_prog`
- whether Neovim sees a Python provider
- resolved `pylsp` command
- whether core modules like `cmp`, `luasnip`, `noice`, and `trouble` load

For AI-specific status, run:

```vim
:AIStatus
```

This reports:

- whether `OPENAI_API_KEY` is visible to Neovim
- whether `codex` is executable
- whether `claude` is executable
- the current Copilot status reported by `copilot.vim`

## 🧯 Troubleshooting

<details>
<summary><strong>AI chat is not working</strong></summary>

- run `:AIStatus`
- make sure `OPENAI_API_KEY` says `set`
- make sure `codex` says `ok`
- if it does not, rerun `./scripts/setup.sh` or open a new shell so `~/.local/bin` is on `PATH`

</details>

<details>
<summary><strong>Copilot suggestions are not appearing</strong></summary>

- run `:Copilot status`
- run `:Copilot setup` if you are not signed in yet
- make sure `node` is installed and available on `PATH`

</details>

<details>
<summary><strong>Persistent terminal processes are not available</strong></summary>

- make sure `shpool` is installed (`./scripts/setup.sh` installs it user-locally, no root needed)
- create a new process with `<leader>pn`
- reopen it with `<leader>pp` or `<leader>pa`

</details>

<details>
<summary><strong>Treehouse workspace mappings are not available</strong></summary>

- install Treehouse using its [upstream installation instructions](https://github.com/kunchenguid/treehouse#install)
- make sure `treehouse` and `shpool` are both available on Neovim's `PATH`
- run Neovim from inside the Git repository whose Treehouse pool you want to use

</details>

<details>
<summary><strong>Fonts or icons look wrong</strong></summary>

- rerun `./scripts/font_setup.sh`
- then make sure your terminal emulator is actually using Hack Nerd Font

</details>

## Shortcuts

All custom mappings are generated from `lua/eltoto/shortcut_data.lua` and written to `SHORTCUTS.txt`.

Inside Neovim:

```vim
:Shortcuts
```

Or use:

```text
<leader>?
```

That opens a floating window with the shortcut list. Press `q` to close it.

<!-- shortcuts:start -->

General
- `<leader>?`: open the shortcuts popup
- `:AIStatus`: show OpenAI key visibility, Codex/Claude availability, and Copilot status
- `:EltotoHealth`: run the Neovim health check for this config
- `:TerminalConfig`: open the runner popup for the current filetype and set default or session-only custom <leader>e behavior
- `:TerminalRename`: rename the current terminal buffer, or reset to default numbering with an empty name
- `:TerminalProcesses`: open the persistent terminal picker
- `:TerminalProcessNew`: create a new persistent terminal process
- `:TerminalProcessKill`: kill a persistent terminal process
- `:TerminalProcessKillAll`: kill all persistent terminal processes
- `:TerminalProcessAttachLast`: attach the last persistent terminal process
- `:ShortcutsSync`: regenerate SHORTCUTS.txt and the README shortcuts section

AI Harness Sessions
- Claude and Codex run in plain terminal buffers with native scrollback, visual mode, and clipboard yank.
- Tabs show Unnamed:<n> until the harness titles the session, then follow the session name live.
- Quitting the harness process (Ctrl-C at its prompt) closes the buffer and drops the session from the cache; closing the buffer with qq keeps the session cached and restorable. Ctrl-C mid-turn just interrupts the harness.
- Running plain vim with no file arguments restores the cached sessions born in the current directory with the most recent focused, or starts a fresh Claude session there if none exist.
- `<leader>m`: toggle between the current buffer and the last AI buffer; offers a Claude/Codex picker when none are open
- `<leader>M`: pick Claude or Codex and open a new AI session buffer
- `<leader>n`: open a picker of AI sessions, named as in the tabline: open ones switch, cached ones are marked and resume on selection
- `AI buffers`: get their own tabline group, separate from plain terminal buffers
- `[a / ]a`: in AI and persistent buffers: jump to the previous / next prompt line (❯, ›, or >); ]a past the last one moves to the live input while staying in normal mode; also works from terminal input mode
- `:Claude`: open a new Claude Code session in a terminal buffer
- `:Codex`: open a new Codex session in a terminal buffer
- `:AIRestore`: restore the cached AI harness sessions born in the current directory

Voice Dictation
- Recording uses arecord; transcription runs locally with faster-whisper from the repo venv, using the 'medium' model on GPU or 'base' on CPU.
- A persistent transcription server loads the model once per Neovim session; GPU failures fall back to CPU for the rest of that server process.
- The target is captured when recording starts: terminal buffers (AI prompts, shells) receive the text on their pty input, file buffers get it inserted at the cursor.
- The first use downloads the model to ~/.cache/huggingface unless scripts/setup.sh already pre-downloaded it.
- `<leader>v`: start voice recording; press again to stop, transcribe, and inject the text

AI
- Copilot handles inline completions and authenticates through :Copilot setup.
- This config does not currently force a specific Copilot inline model from Neovim.
- `insert <C-s>`: accept the current Copilot inline suggestion

Files and Search
- <leader>pf, <leader>ps, <leader>pg, <leader>pv, <leader>b, and <leader>? also work from terminal input mode (including AI buffers).
- `<leader>pf`: Telescope file picker
- `<leader>ps`: Telescope git-tracked file picker
- `<leader>pg`: grep for an entered string with Telescope
- `<leader>b`: Telescope buffer picker
- `<leader>pv`: toggle the file explorer in a left vertical split
- `<leader>w`: save the current file
- `qa`: force quit the current window
- `qq`: close the current window when multiple file windows are visible; otherwise close the current buffer or quit Neovim when only terminal buffers remain
- `<leader>y`: jump to the alternate or last file buffer

Regular Buffer Navigation
- `<leader>;`: jump to the next regular file buffer
- `<leader>,`: jump to the previous regular file buffer

Terminal Workflow
- `<leader>t`: toggle between the current file buffer and the last terminal buffer you used
- `<leader>T`: always open a new terminal buffer
- `terminal <leader>;`: jump to the next terminal buffer and stay in terminal input mode
- `terminal <leader>,`: jump to the previous terminal buffer and stay in terminal input mode
- `terminal <leader>1`: jump to buffer 1 from a terminal
- `terminal <leader>r`: rename the current terminal buffer
- `terminal qq`: close the current window if split, otherwise close the current terminal buffer or quit Neovim if no file buffers remain
- `terminal jk`: leave terminal input mode
- `terminal buffers`: default to T:1, T:2, T:3, ... and may be manually renamed
- `:b T:1`: jump directly to a named terminal buffer

Persistent Processes
- Persistent processes use shpool as a hidden backend so they survive terminal buffer closes and Neovim restarts.
- Closing the attached terminal buffer detaches from the process; it does not kill the shpool session.
- Scrollback is native: shpool passes raw output through, so the terminal buffer holds the history and all normal vim motions, search, visual mode, and yank work directly.
- On reattach, shpool replays the last 10000 lines of session output into the buffer (session_restore_mode in ~/.config/shpool/config.toml).
- All <leader>p* maps below also work from terminal input mode (including AI buffers).
- `persistent buffers`: are labeled P:<name> in the tabline, and :b P:<name> jumps to one directly
- `<leader>pp`: open the persistent terminal picker and attach to a selected process
- `<leader>pn`: create a new persistent terminal process
- `<leader>pa`: attach the last persistent terminal process
- `<leader>pA`: attach all persistent terminal processes created in the current working directory
- `<leader>pk`: kill the current persistent terminal process, or select one to kill
- `<leader>pK`: kill all persistent terminal processes at once
- `persistent <Esc>`: leave terminal input mode and navigate the scrollback like a normal buffer

Treehouse Workspaces
- Treehouse manages a pool of git worktrees. Leased workspaces persist until explicitly returned; disposable ones are auto-named.
- Workspace sessions are backed by shpool and appear in the persistent process picker (<leader>pp) as P:th:<name>.
- Workspace paths are tracked in memory; use <leader>fs to see paths if Neovim was restarted.
- The statusline component shows [TH: <task> | <branch> *] when inside a treehouse buffer.
- After acquisition, pick claude or codex to run it inside the shpool session with the standard unsafe flags; q/Esc or an unavailable agent keeps a plain shell. Workspace agents are not added to the AI session registry.
- `<leader>fa`: acquire a disposable treehouse workspace and open a persistent session inside it; a popup offers to start claude or codex there
- `<leader>fl`: acquire a leased treehouse workspace (prompts for task name) and open a persistent session inside it, with the same agent popup
- `<leader>fs`: show treehouse status in a float (all pool workspaces, lease holders, paths)
- `<leader>fw`: pick from active treehouse sessions; shows branch and dirty indicator
- `<leader>fr`: return the current (or selected) leased workspace; shows git status and requires confirmation

Run Current File
- <leader>e uses the current buffer filetype to pick a runner.
- Examples: python -> python3, lua -> lua, javascript -> node, typescript -> tsx, shell -> bash, go -> go run.
- Non-runnable filetypes like json, yaml, html, and markdown show a warning instead of trying to execute.
- Custom runner commands set through :TerminalConfig last only for the current Neovim session.
- `<leader>e`: open or reuse a terminal and run the current file with the resolved filetype runner

Windows and Layout
- `<leader>h`: move to the window on the left
- `<leader>j`: move to the window below
- `<leader>k`: move to the window above
- `<leader>l`: move to the window on the right
- `<leader>sv`: create a vertical split
- `<leader>sh`: create a horizontal split
- `<leader>o`: keep only the current window and close all other splits
- `<leader>=`: increase current window height
- `<leader>-`: decrease current window height
- `W=`: increase current window width
- `W-`: decrease current window width

Editing
- `gf`: open the file path under the cursor
- `gF`: open the file path under the cursor and jump to its line number
- `insert jk`: leave insert mode and land one character to the right
- `select jk`: leave select mode and land one character to the right
- `visual <space>`: leave visual mode
- `visual J`: move selected lines down
- `visual K`: move selected lines up
- `<space>`: toggle search highlighting on and off
- `<leader>c`: toggle fold under cursor
- `<leader>'`: wrap current word in single quotes
- `<leader>"`: wrap current word in double quotes
- `W'`: wrap current WORD in single quotes
- `W"`: wrap current WORD in double quotes
- `gu`: swap case on the current word
- `gU`: swap case on the current WORD
- `dw`: delete one word
- `d2w`: delete two words
- `d3w`: delete three words
- `d4w`: delete four words
- `yw`: yank one word
- `cw`: change one word
- `<C-z>`: disabled

Git and Project Marks
- Use :Git to open Fugitive status. Inside :Git status, use - to stage or unstage, = to inspect diffs, cc to commit, ca to amend, p to push, P to pull, and q to close the window.
- Useful commands: :Git push, :Git pull, :Git fetch, :Git blame, :Gdiffsplit, :Gvdiffsplit, :Git log -- %, :0Gclog, :Git rebase -i HEAD~N.
- A git hunk is one contiguous changed block in the current file compared with Git.
- `:Git`: open Fugitive git status
- `]h`: jump to the next git hunk
- `[h`: jump to the previous git hunk
- `<leader>gr`: reset the current git hunk
- `<leader>gp`: preview the current git hunk
- `<leader>gb`: show Git blame for the current line

Messages and Diagnostics
- `<leader>nd`: dismiss Noice messages
- `<leader>xx`: toggle Trouble
- `<leader>xw`: Trouble workspace diagnostics
- `<leader>xd`: Trouble document diagnostics
- `<leader>xq`: Trouble quickfix list
- `<leader>x]`: Trouble location list
- `<leader>xt`: TODO comments in Trouble
- `]d`: jump to the next diagnostic
- `[d`: jump to the previous diagnostic
- `]t`: jump to the next TODO comment
- `[t`: jump to the previous TODO comment
- `<leader>pt`: TODO comments in Telescope

LSP and Diagnostics
- These mappings only exist in buffers with an attached LSP client.
- Use <leader>vn for semantic symbol rename when you want only references to the current symbol changed.
- `gd`: go to definition
- `K`: hover documentation
- `<leader>vw`: workspace symbols
- `<leader>vd`: open diagnostic float
- `<leader>vc`: code action
- `<leader>vr`: references
- `<leader>vn`: rename the symbol under the cursor across project references
- `<leader>r`: show diagnostic float
- `<leader>q`: send diagnostics to the location list
- `insert <C-h>`: signature help

<!-- shortcuts:end -->

## ⚡ Useful Commands

```bash
./scripts/setup.sh
./scripts/font_setup.sh
./scripts/check.sh
nvim --headless "+Lazy! sync" "+qa"
nvim --headless "+MasonInstall lua-language-server" "+qa"
```

## 🛟 Recovery

If a plugin checkout becomes corrupted or dirty under `~/.local/share/nvim/lazy`, remove that plugin directory and sync again. Example:

```bash
rm -rf ~/.local/share/nvim/lazy/LuaSnip
nvim --headless "+Lazy! sync" "+qa"
```

## 📝 Notes

- The config is intended to work on both Linux and macOS.
- The Neovim Python provider is repo-local by design.
- Project-specific Python environments should remain separate from Neovim’s tooling environment.
- The remaining legacy-style plugins in `lua/eltoto/plugins/init.lua` are intentional and were kept because they still map to active workflows.
