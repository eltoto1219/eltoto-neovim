local function disable_legacy_packer_plugins()
  local data_site = vim.fs.joinpath(vim.fn.stdpath("data"), "site")
  local packer_root = vim.fs.joinpath(data_site, "pack", "packer")
  local packer_start = vim.fs.joinpath(packer_root, "start")

  if vim.fn.isdirectory(packer_root) == 1 then
    pcall(vim.opt.packpath.remove, vim.opt.packpath, data_site)
  end

  for _, path in ipairs(vim.api.nvim_list_runtime_paths()) do
    if path:sub(1, #packer_start) == packer_start then
      pcall(vim.opt.rtp.remove, vim.opt.rtp, path)
    end
  end
end

disable_legacy_packer_plugins()

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup("eltoto.plugins")
