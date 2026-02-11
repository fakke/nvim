local options = require("nvchad.configs.mason").opts

vim.list_extend(options.ensure_installed, {
  "gopls",
  "goimports",
})

return options
