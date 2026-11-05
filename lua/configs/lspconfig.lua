require("nvchad.configs.lspconfig").defaults()

local servers = {}
for _, language in pairs(require "configs.languages") do
  if language.enabled then
    vim.list_extend(servers, language.servers)
  end
end

-- read :h vim.lsp.config for changing options of lsp servers

vim.lsp.config.gopls = {
  cmd = { "gopls" },
  filetypes = { "go", "gomod" },
  root_dir = function(bufnr, on_dir)
    on_dir(vim.fs.root(bufnr, { "go.mod", ".git" }))
  end,
  settings = {
    gopls = {
      analyses = { unusedparams = true },
      staticcheck = true,
    },
  },
}

vim.lsp.config.pyright = {
  cmd = { "pyright-langserver", "--stdio" },
  filetypes = { "python" },
  root_dir = function(bufnr, on_dir)
    on_dir(vim.fs.root(bufnr, { ".git", "setup.py", "pyproject.toml" }))
  end,
  settings = {
    python = {
      analysis = {
        typeCheckingMode = "basic",
        diagnosticMode = "openFilesOnly",
      },
    },
  },
}

local function enable_servers()
  for _, server in ipairs(servers) do
    local cmd = vim.lsp.config[server].cmd
    vim.lsp.enable(server, type(cmd) == "table" and vim.fn.executable(cmd[1]) == 1)
  end
end

enable_servers()
vim.api.nvim_create_autocmd("User", {
  pattern = "MasonToolsUpdateCompleted",
  callback = enable_servers,
})
