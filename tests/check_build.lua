vim.schedule(function()
  local ok, err = xpcall(function()
    assert(vim.fn.maparg(" ma", "n", false, true).desc == "make all", "mapping override")
    local make = require "configs.make"
    local ov = require "overseer"
    local diagnostics_received = false
    vim.api.nvim_create_autocmd("DiagnosticChanged", {
      callback = function(event)
        if vim.api.nvim_buf_get_name(event.buf) == vim.fn.getcwd() .. "/src/main.c" then
          diagnostics_received = true
        end
      end,
    })
    vim.cmd "edit src/main.c"
    local win = vim.api.nvim_get_current_win()
    local failed = make.run("compile-error", "overseer")
    assert(
      vim.wait(15000, function()
        return failed:is_complete()
      end, 20),
      "build timeout"
    )
    assert(failed.status == "FAILURE")
    local found = false
    for _, item in ipairs(vim.fn.getqflist()) do
      if item.valid == 1 and item.lnum == 2 then
        found = true
      end
    end
    assert(found, "no navigable compiler error")
    assert(vim.api.nvim_get_current_win() == win, "focus stolen")
    local succeeded = make.run("all", "overseer")
    assert(vim.wait(15000, function()
      return succeeded:is_complete()
    end, 20))
    assert(succeeded.status == "SUCCESS")
    for _, item in ipairs(vim.fn.getqflist()) do
      assert(item.valid ~= 1, "stale error")
    end
    local cleaned = make.run("clean", "overseer")
    assert(vim.wait(15000, function()
      return cleaned:is_complete()
    end, 20))
    assert(cleaned.status == "SUCCESS")
    assert(vim.fn.filereadable "compile_commands.json" == 1, "make clean removed clangd's compiler flags")
    local rebuilt = make.run("all", "overseer")
    assert(vim.wait(15000, function()
      return rebuilt:is_complete()
    end, 20))
    assert(rebuilt.status == "SUCCESS")
    assert(#vim.fn.getqflist() == 0, "successful build logs appeared as errors")
    local busy = ov.new_task { cmd = { "sleep", "60" }, cwd = vim.fn.getcwd() }
    busy:start()
    local count = #ov.list_tasks {}
    make.run("clean", "overseer")
    assert(#ov.list_tasks {} == count, "overlapping task was started")
    busy:stop()
    busy:dispose(true)
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "unsaved unnamed file" })
    count = #ov.list_tasks {}
    make.run("all", "overseer")
    assert(#ov.list_tasks {} == count, "build proceeded after save failure")
    vim.api.nvim_buf_delete(buf, { force = true })
    local noisy = ov.new_task {
      cmd = { "./build/demo", "--verbose" },
      cwd = vim.fn.getcwd(),
      components = make.components(),
    }
    noisy:start()
    local responsive = false
    vim.schedule(function()
      responsive = true
    end)
    assert(
      vim.wait(10000, function()
        return noisy:is_complete() and responsive
      end, 20),
      "verbose output stalled the event loop"
    )
    assert(noisy.status == "SUCCESS")
    assert(
      vim.wait(5000, function()
        local output = table.concat(vim.api.nvim_buf_get_lines(noisy:get_bufnr(), 0, -1, false), "\n")
        return output:find("Output line 9999", 1, true) ~= nil
      end, 20),
      "verbose output was not captured"
    )
    vim.cmd "edit src/main.c"
    vim.api.nvim_exec_autocmds("User", { pattern = "FilePost" })
    assert(
      vim.wait(10000, function()
        return #vim.lsp.get_clients { name = "clangd", bufnr = 0 } > 0
      end, 50),
      "clangd did not attach"
    )
    assert(
      vim.wait(10000, function()
        return diagnostics_received
      end, 50),
      "clangd did not publish diagnostics"
    )
    assert(#vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR }) == 0, "false clangd errors")
    print "PASS mappings, compiler errors, focus, rebuild, busy guard, cancellation, save failure, verbose output, clangd"
  end, debug.traceback)
  if not ok then
    print(err)
    vim.cmd "cquit"
  else
    vim.cmd "noautocmd qa!"
  end
end)
