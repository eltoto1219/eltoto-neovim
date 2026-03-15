#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

echo "Syncing generated shortcut docs"
nvim --headless "+lua require('eltoto.shortcuts').sync_docs()" "+qa"

echo "Checking Neovim startup"
nvim --headless "+qa"

echo "Checking core modules"
nvim --headless "+lua assert(require('eltoto.ai'))" "+lua assert(require('eltoto.buffers'))" "+lua assert(require('eltoto.terminal'))" "+lua assert(require('eltoto.processes'))" "+lua assert(require('eltoto.run'))" "+lua assert(require('eltoto.shortcuts'))" "+qa"

echo "Checking registered commands"
nvim --headless "+lua for _, cmd in ipairs({':AIStatus', ':EltotoHealth', ':Shortcuts', ':ShortcutsSync', ':TermimalConfig', ':TerminalRename', ':TerminalProcesses', ':TerminalProcessNew', ':TerminalProcessKill', ':TerminalProcessAttachLast'}) do assert(vim.fn.exists(cmd) == 2, cmd) end" "+qa"

echo "Checking plugin modules"
nvim --headless "+lua assert(pcall(require, 'telescope'))" "+qa"

echo "All checks passed"
