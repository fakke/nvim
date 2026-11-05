local options = require "nvchad.configs.treesitter"

options.ensure_installed = options.ensure_installed or {}
vim.list_extend(options.ensure_installed, {
  "c",
  "cpp",
  "css",
  "go",
  "gomod",
  "html",
  "make",
  "python",
})

return options
