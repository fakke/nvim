require("nvchad.configs.lspconfig").defaults()

local servers = { "html", "cssls", "pyright", "make", "clangd" }
vim.lsp.enable(servers)

-- read :h vim.lsp.config for changing options of lsp servers

vim.lsp.config.gopls = {
  cmd = { "gopls" },
  filetypes = { "go", "gomod" },
  root_dir = require("lspconfig.util").root_pattern("go.mod", ".git"),
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
  root_dir = require("lspconfig.util").root_pattern(".git", "setup.py", "pyproject.toml"),
  settings = {
    python = {
      analysis = {
        typeCheckingMode = "basic",
        diagnosticMode = "openFilesOnly",
      },
    },
  },
}
