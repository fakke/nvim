local tools = {}
for _, language in pairs(require "configs.languages") do
  if language.enabled then
    vim.list_extend(tools, language.tools)
  end
end

return {
  ensure_installed = tools,
  run_on_start = true,
  auto_update = false,
}
