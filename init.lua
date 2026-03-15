if vim.islist then
  vim.tbl_islist = vim.islist
end

local env = require("eltoto.env")

if env.python_host_prog() ~= "" then
  vim.g.python3_host_prog = env.python_host_prog()
end

require('eltoto')
require("eltoto.ai").register()
require("eltoto.debug").register()
require("eltoto.health").register()
require("eltoto.processes").setup()
require("eltoto.run").register()
require("eltoto.shortcuts").register()

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    require("eltoto.avante").open_startup_chat_if_empty()
  end,
})

local function inspect_lsp_client()
  vim.ui.input({ prompt = 'Enter LSP client name: ' }, function(name)
    if not name then return end
    local clients = vim.lsp.get_clients({ name = name })
    if #clients == 0 then
      vim.notify('No LSP client named "' .. name .. '"', vim.log.levels.WARN)
      return
    end
    local cfg = clients[1].config
    vim.pretty_print(cfg.settings.pylsp and cfg.settings.pylsp.plugins or cfg.settings)
  end)
end


vim.keymap.set('n', '<leader>I', inspect_lsp_client, { desc = 'Inspect LSP config' })
vim.keymap.set('n', '<leader>H', "<cmd>EltotoHealth<CR>", { desc = 'Show config health' })
