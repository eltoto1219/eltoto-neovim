# 🛠️ eltoto.nvim

Portable, terminal-centered Neovim workflow with a repo-local Python toolchain, custom buffer and terminal navigation, generated shortcut docs, and bootstrap scripts for Linux and macOS.

> A process-aware Neovim workbench:
> edit code, run files, manage durable terminals, use AI deliberately, and recover the whole setup quickly on a new machine.

### 🌟 At a Glance

- ⚙️ Repo-local Python tooling for a stable Neovim environment
- 🖥️ Separate workflows for file buffers, terminal buffers, and persistent tmux-backed processes
- 🤖 Copilot for inline completion and Avante for explicit chat/edit workflows
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
4. Start working with `<leader>pf`, `<leader>t`, `<leader>e`, and `<leader>aa`.

## ✨ What This Project Does

This project turns Neovim into a portable personal workbench with:

- a repo-local Python environment for Neovim itself, so editor tooling stays separate from project virtualenvs
- custom regular-buffer and terminal-buffer workflows, including named terminal buffers like `T:1`, `T:2`, and direct `:b T:1` navigation
- persistent terminal processes backed by `tmux`, so long-running jobs survive buffer closes and Neovim restarts
- AI assistance through Copilot inline completions and Avante chat/edit flows with OpenAI
- fast project search with Telescope
- semantic symbol rename through LSP for supported languages
- filetype-aware run-current-file behavior via `<leader>e`, with session-only overrides through `:TermimalConfig`
- bootstrap scripts for fonts, dependencies, Mason installs, Python setup, and plugin sync
- a health command and a check script so the setup can verify itself after changes or on a fresh machine

## 🔥 Why This Is Awesome

This repo is strong because it is not just a Neovim config. It is an opinionated working system.

Most configs stop at plugins and keymaps. This one goes further:

- 🚀 It bootstraps a fresh machine quickly, including fonts, Python tooling, plugin sync, Mason installs, and optional Copilot auth.
- 🧪 It isolates Neovim’s Python environment from project virtualenvs, which keeps editor tooling stable.
- 🗂️ It has separate, deliberate workflows for files, terminals, and persistent tmux-backed processes.
- ▶️ It can run the current file intelligently by filetype instead of making you context-switch into another shell.
- 🤖 It treats AI as a tool, not as the center of the editor. Copilot stays lightweight, while Avante now has a real workflow with history switching, tabline visibility, chat lifecycle actions, polished prompts, and terminal round-trip behavior.
- 🩺 It is maintainable. `:EltotoHealth` and `./scripts/check.sh` give you a direct way to verify the setup instead of guessing.
- 🎛️ It has a real UI layer. The tabline, terminal names, and Avante session views reflect how the workflow actually works, not just what Neovim happens to expose by default.

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
- Configure session-only filetype runner overrides with `:TermimalConfig`
- Navigate regular buffers and terminal buffers with separate rules
- Open, reuse, and cycle through named terminal buffers
- Create, attach, list, and kill persistent terminal processes without leaving Neovim
- Run current files through filetype-aware runners inside the Neovim terminal workflow
- Use Avante for in-editor AI chat and edit workflows
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
4. Use `<leader>pn` to create a persistent tmux-backed process for anything long-running, then `<leader>pp` or `<leader>pa` to reattach later.
5. Run the current file with `<leader>e`, using the filetype-aware runner instead of opening another shell manually.
6. Use `<leader>aa` or `<leader>ac` when you want Codex help, while keeping normal editing and terminal work in the foreground.
7. Use `:AIStatus`, `:EltotoHealth`, and `./scripts/check.sh` when something looks wrong instead of guessing.

The point is that editing, running code, long-lived processes, and AI assistance all live in one coherent workflow.

## 🚀 Bootstrap

The setup script will:

- run dependency preflight checks
- offer to install missing system dependencies on Linux or macOS
- create a repo-local `.venv`
- install Python packages from `reqs.txt`
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

The setup script checks for and can offer to install:

- `git`
- `python3` or `python`
- Python `venv` support
- `curl` or `wget`
- `unzip`

It also checks for these recommended tools:

- `nvim`
- `tar`
- `ripgrep`
- `tmux`
- `node`
- `make`
- `gcc` or `clang`

## 🤖 AI Setup

This config uses two separate auth paths:

- OpenAI / Codex: set `OPENAI_API_KEY` in your shell profile, for example in `~/.bashrc` or `~/.zshrc`
- GitHub Copilot: run `:Copilot setup` once inside Neovim and sign in with your GitHub account

Recommended model choices:

- Avante / OpenAI chat: `gpt-5.4`
- Copilot inline completions: keep the default Copilot inline model, because `copilot.vim` does not expose a repo-local per-model inline selector here

This repo does not store API keys. Keep `OPENAI_API_KEY` in your shell environment so both terminal Codex and Neovim can use the same credential.

## 🧠 AI Workflow

This setup intentionally uses three different AI modes for three different jobs:

- Use Copilot for inline completion while you are already typing and do not want to stop your flow.
- Use Avante when you want an explicit conversation, code-aware editing, or a side chat that stays inside Neovim.
- Use terminal Codex when you want the full terminal-first Codex workflow outside the editor UI.

The practical split is:

- Copilot: fast, low-friction, inline suggestions
- Avante: deliberate in-editor help, edits, and chat
- Codex in terminal: best standalone Codex TUI experience when you want to work directly in the terminal

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
- the configured Avante model
- whether Avante loads
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

- make sure `tmux` is installed
- create a new process with `<leader>pn`
- reopen it with `<leader>pp` or `<leader>pa`

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
- `:AIStatus`: show OpenAI key visibility, Avante model, Codex availability, and Copilot status
- `:EltotoHealth`: run the Neovim health check for this config
- `:TermimalConfig`: open the runner popup for the current filetype and set default or session-only custom <leader>e behavior
- `:TerminalRename`: rename the current terminal buffer, or reset to default numbering with an empty name
- `:TerminalProcesses`: open the persistent terminal picker
- `:TerminalProcessNew`: create a new persistent terminal process
- `:TerminalProcessKill`: kill a persistent terminal process
- `:TerminalProcessKillAll`: kill all persistent terminal processes
- `:TerminalProcessAttachLast`: attach the last persistent terminal process
- `:ShortcutsSync`: regenerate SHORTCUTS.txt and the README shortcuts section

AI
- Avante is configured to use OpenAI with the gpt-5.4 model.
- Copilot handles inline completions separately and authenticates through :Copilot setup.
- This config does not currently force a specific Copilot inline model from Neovim.
- `<leader>aa`: open Avante ask
- `<leader>ac`: open Avante chat
- `<leader>at`: toggle the Avante sidebar, or create a new chat if none exists
- `visual <leader>aa`: ask Avante about the current visual selection
- `visual <leader>ae`: send the current visual selection to Avante edit
- `visual <leader>as`: send the current visual selection to Avante edit
- `Avante window <leader>an`: start a new Avante chat
- `Avante window <leader>ah`: open the Avante chat history picker
- `Avante window <leader>ac`: clear the current Avante chat history
- `Avante window <leader>ad`: delete the currently active Avante chat
- `Avante window <leader>aD`: delete all saved Avante chats for the current project
- `Avante window <leader>;`: switch to the next Avante chat history entry
- `Avante window <leader>,`: switch to the previous Avante chat history entry
- `Avante window <leader>z`: toggle the Avante layout between split and full view
- `Avante prompt <C-s>`: submit the current Avante prompt or edit request
- `insert <C-]>`: accept the current Copilot inline suggestion

Files and Search
- `<leader>pf`: Telescope file picker
- `<leader>ps`: Telescope git-tracked file picker
- `<leader>pg`: grep for an entered string with Telescope
- `<leader>bb`: Telescope buffer picker
- `<leader>pv`: toggle the file explorer in a left vertical split
- `<leader>w`: save the current file
- `qa`: force quit the current window
- `qq`: close the current window if split, otherwise close the current buffer or quit Neovim when only terminal buffers remain
- `<leader>ba`: jump to the alternate or last file buffer

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
- Persistent processes use tmux as a hidden backend so they survive terminal buffer closes and Neovim restarts.
- Closing the attached terminal buffer detaches from the process; it does not kill the tmux session.
- `<leader>pp`: open the persistent terminal picker and attach to a selected process
- `<leader>pn`: create a new persistent terminal process
- `<leader>pa`: attach the last persistent terminal process
- `<leader>pk`: kill the current persistent terminal process, or select one to kill
- `<leader>pK`: kill all persistent terminal processes at once

Run Current File
- <leader>e uses the current buffer filetype to pick a runner.
- Examples: python -> python3, lua -> lua, javascript -> node, typescript -> tsx, shell -> bash, go -> go run.
- Non-runnable filetypes like json, yaml, html, and markdown show a warning instead of trying to execute.
- Custom runner commands set through :TermimalConfig last only for the current Neovim session.
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
- `<leader>gs`: stage the current git hunk
- `<leader>gr`: reset the current git hunk
- `<leader>gp`: preview the current git hunk
- `<leader>gb`: show Git blame for the current line
- `<leader>m`: add current file to Harpoon
- `<C-e>`: toggle Harpoon quick menu
- `<C-h>`: jump to Harpoon file 1
- `<C-j>`: jump to Harpoon file 2
- `<C-k>`: jump to Harpoon file 3
- `<C-l>`: jump to Harpoon file 4

Messages and Diagnostics
- `<leader>nd`: dismiss Noice messages
- `<leader>xx`: toggle Trouble
- `<leader>xw`: Trouble workspace diagnostics
- `<leader>xd`: Trouble document diagnostics
- `<leader>xq`: Trouble quickfix list
- `<leader>x]`: Trouble location list
- `<leader>xt`: TODO comments in Trouble
- `]d`: jump to the next diagnostic or Trouble item
- `[d`: jump to the previous diagnostic or Trouble item
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
