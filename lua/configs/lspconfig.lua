require("nvchad.configs.lspconfig").defaults()

local servers = { "html", "cssls", "pyright", "autotools_ls", "clangd", "gopls" }

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

vim.lsp.enable(servers)
