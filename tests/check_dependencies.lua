local ok, err = xpcall(function()
  local plugin = assert(vim.env.MASON_TOOL_INSTALLER, "Set MASON_TOOL_INSTALLER to a plugin checkout")
  vim.opt.runtimepath:append(vim.fn.getcwd())
  vim.opt.runtimepath:append(plugin)

  package.preload["nvchad.configs.treesitter"] = function()
    return { ensure_installed = { "lua", "luadoc", "printf", "vim", "vimdoc" } }
  end

  local parser_setup = false
  local parsers
  package.preload["nvim-treesitter"] = function()
    return {
      setup = function()
        parser_setup = true
      end,
      install = function(languages)
        assert(parser_setup)
        parsers = languages
      end,
    }
  end

  local specs = require "plugins"
  local installer
  for _, spec in ipairs(specs) do
    if spec[1] == "nvim-treesitter/nvim-treesitter" then
      assert(spec.lazy == false, "Parser setup must run on startup")
      spec.config(spec, spec.opts())
    elseif spec[1] == "WhoIsSethDaniel/mason-tool-installer.nvim" then
      assert(spec.lazy == false, "Mason installer must load before VimEnter")
      assert(vim.tbl_contains(spec.dependencies, "mason-org/mason.nvim"))
      installer = spec.opts()
    end
  end
  assert(installer and installer.run_on_start and not installer.auto_update)
  for _, language in ipairs { "lua", "python", "go", "gomod", "html", "css", "c", "cpp", "make" } do
    assert(vim.tbl_contains(parsers, language), "Missing parser: " .. language)
  end

  local installed = { stylua = true }
  local attempts = {}
  local fail_black = true
  package.preload["mason.version"] = function()
    return { MAJOR_VERSION = 2 }
  end
  package.preload["mason-registry"] = function()
    return {
      refresh = function(callback)
        callback()
      end,
      get_package = function(name)
        return {
          name = name,
          is_installed = function()
            return installed[name] or false
          end,
          is_installing = function()
            return false
          end,
          once = function() end,
          install = function(_, _, callback)
            attempts[name] = (attempts[name] or 0) + 1
            installed[name] = not (name == "black" and fail_black)
            callback(installed[name])
          end,
        }
      end,
    }
  end

  local finished = false
  vim.api.nvim_create_autocmd("User", {
    pattern = "MasonToolsUpdateCompleted",
    callback = function()
      finished = true
    end,
  })
  local mason = require "mason-tool-installer"
  mason.setup(installer)
  dofile(plugin .. "/plugin/mason-tool-installer.lua")
  vim.api.nvim_exec_autocmds("VimEnter", {})
  assert(
    vim.wait(1000, function()
      return finished
    end),
    "VimEnter did not trigger installation"
  )
  assert(attempts.stylua == nil, "Installed tool was reinstalled")
  for _, name in ipairs(installer.ensure_installed) do
    assert(name == "stylua" or attempts[name] == 1, "Tool was not installed: " .. name)
  end

  fail_black = false
  mason.check_install(false, true)
  assert(installed.black and attempts.black == 2, "Failed tool was not retried")
  for _, name in ipairs(installer.ensure_installed) do
    assert(name == "black" or name == "stylua" or attempts[name] == 1, "Successful tool was reinstalled")
  end

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
  print "PASS startup installation, retry, installed-tool reuse, parsers, and LSP activation"
end, debug.traceback)
if not ok then
  print(err)
  vim.cmd "cquit"
else
  vim.cmd "qa!"
end
