return {
  "mfussenegger/nvim-dap",
  dependencies = {
    "stevearc/overseer.nvim",
    "mason-org/mason.nvim",
    { "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" } },
  },
  keys = {
    {
      "<leader>db",
      function()
        require("dap").toggle_breakpoint()
      end,
      desc = "debug breakpoint",
    },
    {
      "<leader>dc",
      function()
        local dap = require "dap"
        if dap.session() then
          dap.continue()
        else
          local make = require "configs.make"
          if make.terminal_ready() and make.ready(vim.fn.getcwd()) and make.save() then
            dap.continue()
          end
        end
      end,
      desc = "debug start / continue",
    },
    {
      "<leader>dn",
      function()
        require("dap").step_over()
      end,
      desc = "debug step over",
    },
    {
      "<leader>di",
      function()
        require("dap").step_into()
      end,
      desc = "debug step into",
    },
    {
      "<leader>do",
      function()
        require("dap").step_out()
      end,
      desc = "debug step out",
    },
    {
      "<leader>dx",
      function()
        require("dap").terminate()
      end,
      desc = "debug terminate",
    },
    {
      "<leader>du",
      function()
        require("dapui").toggle()
      end,
      desc = "debug UI",
    },
  },
  config = function()
    local dap = require "dap"
    local ui = require "dapui"
    ui.setup {}
    dap.adapters.codelldb = {
      type = "executable",
      command = vim.fn.stdpath "data" .. "/mason/bin/codelldb",
    }
    dap.defaults.codelldb.external_terminal = require("configs.make").terminal()
    dap.configurations.c = {
      {
        name = "Launch executable (build manually)",
        type = "codelldb",
        request = "launch",
        program = function()
          local path = vim.fn.input("Executable: ", vim.fn.getcwd() .. "/", "file")
          return path ~= "" and path or dap.ABORT
        end,
        cwd = "${workspaceFolder}",
        terminal = "external",
      },
    }
    dap.listeners.after.event_initialized.dev = function()
      ui.open()
    end
    dap.listeners.before.event_terminated.dev = function()
      ui.close()
    end
    dap.listeners.before.event_exited.dev = function()
      ui.close()
    end
    require("overseer").enable_dap()
  end,
}
