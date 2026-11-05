local ok, err = xpcall(function()
  vim.opt.runtimepath:append(vim.fn.getcwd())
  package.preload["nvchad.configs.lspconfig"] = function()
    return { defaults = function() end }
  end
  local enabled
  vim.lsp.enable = function(servers)
    enabled = servers
  end
  require "configs.lspconfig"
  assert(vim.tbl_contains(enabled, "gopls") and vim.tbl_contains(enabled, "autotools_ls"))
  assert(not vim.tbl_contains(enabled, "make"))
  local project = vim.fn.tempname()
  vim.fn.mkdir(project)
  vim.fn.writefile({}, project .. "/go.mod")
  vim.fn.writefile({}, project .. "/pyproject.toml")
  local bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(bufnr, project .. "/main.go")
  for _, server in ipairs { "gopls", "pyright" } do
    local root
    vim.lsp.config[server].root_dir(bufnr, function(directory)
      root = directory
    end)
    assert(root and vim.uv.fs_realpath(root) == vim.uv.fs_realpath(project), "Incorrect root callback for " .. server)
  end
  vim.fn.delete(project, "rf")
  print "PASS native LSP roots and server activation"
end, debug.traceback)
if not ok then
  print(err)
  vim.cmd "cquit"
else
  vim.cmd "qa!"
end
