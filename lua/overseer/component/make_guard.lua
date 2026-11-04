return {
  desc = "Save files and prevent overlapping make operations",
  constructor = function()
    return {
      on_pre_start = function(_, task)
        local make = require "configs.make"
        if make.ready(task.cwd, task) and make.save() then
          return true
        end
        vim.schedule(function()
          task:dispose(true)
        end)
        return false
      end,
    }
  end,
}
