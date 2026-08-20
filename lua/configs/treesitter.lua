local options = require "nvchad.configs.treesitter"

options.ensure_installed = options.ensure_installed or {}
vim.list_extend(options.ensure_installed, {
  "go",
  "gomod",
  "python",
})

return options
