local function has(command)
  return vim.fn.executable(command) == 1
end

local python = has "python3"
local pip = false
if python then
  vim.fn.system { "python3", "-c", "import venv, ensurepip" }
  pip = vim.v.shell_error == 0
end
local node = has "node" and has "npm"
local compiler = has "cc" or has "gcc" or has "clang"

return {
  lua = {
    enabled = true,
    tools = { "lua-language-server", "stylua" },
    servers = { "lua_ls" },
    parsers = { "lua", "luadoc", "printf", "vim", "vimdoc" },
    formatters = { lua = { "stylua" } },
  },
  go = {
    enabled = has "go",
    tools = { "gopls", "goimports" },
    servers = { "gopls" },
    parsers = { "go", "gomod" },
    formatters = { go = { "goimports" } },
  },
  python = {
    enabled = python,
    tools = vim.list_extend(pip and { "black" } or {}, node and { "pyright" } or {}),
    servers = node and { "pyright" } or {},
    parsers = { "python" },
    formatters = pip and { python = { "black" } } or {},
  },
  web = {
    enabled = node,
    tools = { "html-lsp", "css-lsp" },
    servers = { "html", "cssls" },
    parsers = { "html", "css" },
  },
  c = {
    enabled = compiler,
    tools = { "clangd", "codelldb" },
    servers = { "clangd" },
    parsers = { "c", "cpp" },
  },
  make = {
    enabled = has "make",
    tools = pip and { "autotools-language-server" } or {},
    servers = pip and { "autotools_ls" } or {},
    parsers = { "make" },
  },
}
