local ok, err = xpcall(function()
  local plugin = assert(vim.env.MASON_TOOL_INSTALLER, "Set MASON_TOOL_INSTALLER to a plugin checkout")
  vim.opt.runtimepath:append(vim.fn.getcwd())
  vim.opt.runtimepath:append(plugin)

  package.preload["nvchad.configs.treesitter"] = function()
    return { ensure_installed = { "lua", "luadoc", "printf", "vim", "vimdoc" } }
  end

  local executable = vim.fn.executable
  local system = vim.fn.system
  local commands = {}
  local venv = true
  vim.fn.executable = function(command)
    return commands[command] and 1 or 0
  end
  vim.fn.system = function()
    return system { venv and "/usr/bin/true" or "/usr/bin/false" }
  end
  local function detect(available)
    commands = available
    for _, module in ipairs { "languages", "mason", "treesitter", "conform" } do
      package.loaded["configs." .. module] = nil
    end
    return require "configs.languages"
  end

  local languages = detect {}
  assert(not languages.go.enabled and not languages.python.enabled and not languages.c.enabled)
  assert(vim.deep_equal(require("configs.mason").ensure_installed, { "lua-language-server", "stylua" }))
  assert(not vim.tbl_contains(require("configs.treesitter").ensure_installed, "go"))
  assert(require("configs.conform").formatters_by_ft.go == nil)
  languages = detect { go = true }
  assert(languages.go.enabled and not languages.python.enabled)
  assert(vim.tbl_contains(require("configs.mason").ensure_installed, "gopls"))
  assert(vim.tbl_contains(require("configs.treesitter").ensure_installed, "go"))
  local go_formatters = require("configs.conform").formatters_by_ft.go
  assert(#go_formatters() == 0, "Missing formatter was enabled")
  commands.goimports = true
  assert(vim.deep_equal(go_formatters(), { "goimports" }), "Newly installed formatter was not enabled")
  languages = detect { python3 = true }
  assert(vim.tbl_contains(languages.python.tools, "black"))
  assert(not vim.tbl_contains(languages.python.tools, "pyright"))
  venv = false
  languages = detect { python3 = true, node = true, npm = true }
  assert(not vim.tbl_contains(languages.python.tools, "black"))
  assert(vim.tbl_contains(languages.python.tools, "pyright"))
  venv = true
  detect {
    go = true,
    python3 = true,
    node = true,
    npm = true,
    cc = true,
    make = true,
    ["tree-sitter"] = true,
    curl = true,
    tar = true,
  }

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
  local enabled = {}
  for _, server in ipairs { "lua_ls", "gopls", "pyright", "html", "cssls", "clangd", "autotools_ls" } do
    vim.lsp.config(server, { cmd = { server } })
    commands[server] = true
  end
  commands["pyright-langserver"] = true
  commands.gopls = nil
  vim.lsp.enable = function(server, enable)
    enabled[server] = enable
  end
  require "configs.lspconfig"
  assert(enabled.gopls == false and enabled.autotools_ls)
  commands.gopls = true
  vim.api.nvim_exec_autocmds("User", { pattern = "MasonToolsUpdateCompleted" })
  assert(enabled.gopls, "Newly installed server was not enabled")
  assert(enabled.make == nil)
  local treesitter
  for _, spec in ipairs(specs) do
    if spec[1] == "nvim-treesitter/nvim-treesitter" then
      treesitter = spec
    end
  end
  parsers = nil
  commands["tree-sitter"] = nil
  treesitter.config(treesitter, treesitter.opts())
  assert(parsers == nil, "Parser installation ran without the CLI")
  vim.fn.executable = executable
  vim.fn.system = system
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
  print "PASS runtime detection, missing prerequisites, startup installation, retry, parsers, and LSP activation"
end, debug.traceback)
if not ok then
  print(err)
  vim.cmd "cquit"
else
  vim.cmd "qa!"
end
