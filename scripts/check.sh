#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

echo "Syncing generated shortcut docs"
nvim --headless "+lua require('eltoto.shortcuts').sync_docs()" "+qa"

echo "Checking Neovim startup"
nvim --headless "+qa"

echo "Checking core modules"
nvim --headless \
  "+lua assert(require('eltoto.ai'))" \
  "+lua assert(require('eltoto.health'))" \
  "+lua assert(require('eltoto.shortcuts'))" \
  "+lua assert(require('aiterm'))" \
  "+lua assert(require('aiterm.buffers'))" \
  "+lua assert(require('aiterm.terminal'))" \
  "+lua assert(require('aiterm.processes'))" \
  "+lua assert(require('aiterm.run'))" \
  "+lua assert(require('aiterm.ai'))" \
  "+qa"

echo "Checking registered commands"
nvim --headless "+lua for _, cmd in ipairs({':AIStatus', ':EltotoHealth', ':Shortcuts', ':ShortcutsSync', ':TerminalConfig', ':TerminalRename', ':TerminalProcesses', ':TerminalProcessNew', ':TerminalProcessKill', ':TerminalProcessAttachLast', ':TerminalProcessAttachAll'}) do assert(vim.fn.exists(cmd) == 2, cmd) end" "+qa"

echo "Checking plugin modules"
nvim --headless "+lua assert(pcall(require, 'telescope'))" "+qa"

echo "Checking agent template drift (warnings only)"
./scripts/agent_sync.sh --check

echo "All checks passed"
