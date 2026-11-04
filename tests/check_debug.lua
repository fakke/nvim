vim.o.columns = 160
vim.o.lines = 50
vim.schedule(function()
  local ok, err = xpcall(function()
    require("lazy").load { plugins = { "nvim-dap" } }
    local dap = require "dap"
    dap.set_log_level "INFO"
    local function tmux(args)
      local cmd = { "tmux" }
      vim.list_extend(cmd, args)
      local r = vim.system(cmd, { text = true }):wait()
      assert(r.code == 0, r.stderr)
      return vim.trim(r.stdout)
    end
    local function runner()
      local result = tmux { "list-panes", "-a", "-F", "#{pane_id}\t#{@nvim_runner_owner}" }
      for line in result:gmatch "[^\n]+" do
        local pane, owner = line:match "([^\t]+)\t(.+)"
        if owner == vim.env.TMUX_PANE then
          return pane
        end
      end
    end
    local function output()
      local pane = runner()
      return pane and tmux { "capture-pane", "-p", "-t", pane } or ""
    end
    local function evaluate(expression)
      assert(
        vim.wait(5000, function()
          return dap.session().current_frame ~= nil
        end, 20),
        "no frame"
      )
      local done, value, failure
      dap.session():request(
        "evaluate",
        { expression = expression, context = "watch", frameId = dap.session().current_frame.id },
        function(e, r)
          failure = e
          value = r
          done = true
        end
      )
      assert(
        vim.wait(5000, function()
          return done
        end, 20),
        "evaluate timeout"
      )
      assert(not failure, vim.inspect(failure))
      return value.result
    end
    vim.cmd "edit src/demo.c"
    vim.api.nvim_win_set_cursor(0, { 6, 0 })
    dap.toggle_breakpoint()
    local stopped = 0
    dap.listeners.after.event_stopped.check = function()
      stopped = stopped + 1
    end
    local configurations = vim.json.decode(table.concat(vim.fn.readfile ".vscode/launch.json", "\n")).configurations
    dap.run(configurations[1])
    assert(
      vim.wait(25000, function()
        return output():find("Enter a number", 1, true) ~= nil
      end, 100),
      "stdin prompt timeout: " .. output()
    )
    local pane = runner()
    tmux { "send-keys", "-t", pane, "5", "Enter" }
    assert(
      vim.wait(10000, function()
        return stopped > 0
      end, 50),
      "breakpoint timeout"
    )
    assert(evaluate "total" == "0", "unexpected total")
    vim.wait(300)
    dap.step_over()
    assert(
      vim.wait(5000, function()
        return stopped > 1
      end, 20),
      "step timeout"
    )
    assert(evaluate "total" == "1", "step did not update variable")
    vim.wait(300)
    dap.clear_breakpoints()
    dap.continue()
    assert(
      vim.wait(10000, function()
        return dap.session() == nil
      end, 20),
      "exit timeout"
    )
    print "PASS interactive stdin, breakpoint, variable evaluation, step, clean exit"
    assert(vim.wait(5000, function()
      return tmux { "show-options", "-pqv", "-t", pane, "@nvim_runner_state" } == "ready"
    end, 20))
    stopped = 0
    dap.run(configurations[2])
    assert(
      vim.wait(25000, function()
        return stopped > 0
      end, 50),
      "crash stop timeout"
    )
    assert(runner() == pane, "debug pane was not reused")
    assert(dap.session(), "editor lost debug session on crash")
    dap.terminate()
    assert(
      vim.wait(10000, function()
        return dap.session() == nil
      end, 20),
      "terminate timeout"
    )
    print "PASS crash handling, pane reuse and termination"
    assert(vim.wait(5000, function()
      return tmux { "show-options", "-pqv", "-t", pane, "@nvim_runner_state" } == "ready"
    end, 20))
    local bad = vim.deepcopy(configurations[1])
    bad.preLaunchTask = "make compile-error"
    local ov = require "overseer"
    dap.run(bad)
    assert(
      vim.wait(10000, function()
        for _, task in ipairs(ov.list_tasks {}) do
          if task.name == "make compile-error" and task.status == "FAILURE" then
            return true
          end
        end
      end, 20),
      "failed prelaunch task did not finish"
    )
    vim.wait(300)
    assert(dap.session() == nil, "debugger launched despite build failure")
    assert(tmux { "show-options", "-pqv", "-t", pane, "@nvim_runner_state" } == "ready", "old executable launched")
    print "PASS failed prelaunch build prevents execution"
  end, debug.traceback)
  if not ok then
    print(err)
    vim.cmd "cquit"
  else
    vim.cmd "noautocmd qa!"
  end
end)
