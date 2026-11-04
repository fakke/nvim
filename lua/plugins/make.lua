return {
  "stevearc/overseer.nvim",
  opts = { dap = false, output = { use_terminal = false } },
  cmd = { "OverseerRun", "OverseerOpen", "OverseerToggle", "OverseerTaskAction" },
  config = function(_, opts)
    local overseer = require "overseer"
    overseer.setup(opts)
    overseer.add_template_hook({}, function(task, util)
      local command = type(task.cmd) == "table" and task.cmd[1] or task.cmd
      if command == "make" or (type(command) == "string" and command:match "^make%s") then
        for _, component in ipairs(require("configs.make").components()) do
          if component ~= "default" then
            util.add_component(task, component)
          end
        end
      end
    end)
  end,
}
