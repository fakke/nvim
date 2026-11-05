local options = require "nvchad.configs.treesitter"

options.ensure_installed = {}
for _, language in pairs(require "configs.languages") do
  if language.enabled then
    vim.list_extend(options.ensure_installed, language.parsers)
  end
end

return options
