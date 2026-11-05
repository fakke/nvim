local options = {
  formatters_by_ft = {},

  default_format_opts = {
    timeout_ms = 3000,
    lsp_fallback = true,
  },

  format_on_save = {
    -- These options will be passed to conform.format()
    timeout_ms = 3000,
    lsp_fallback = true,
  },
}

for _, language in pairs(require "configs.languages") do
  if language.enabled then
    for filetype, formatters in pairs(language.formatters or {}) do
      options.formatters_by_ft[filetype] = function()
        return vim.tbl_filter(function(formatter)
          return vim.fn.executable(formatter) == 1
        end, formatters)
      end
    end
  end
end

return options
