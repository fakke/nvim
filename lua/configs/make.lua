local M = {}

local targets = {
  a = { "all", "overseer" },
  c = { "clean", "overseer" },
  t = { "test", "overseer" },
  r = { "run", "tmux" },
}

function M.save()
  local ok, err = pcall(function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" and vim.bo[buf].modified then
        vim.api.nvim_buf_call(buf, function()
          vim.cmd "write"
        end)
      end
    end
  end)
  if not ok then
    vim.notify(tostring(err), vim.log.levels.ERROR)
  end
  return ok
end

function M.terminal()
  return {
    command = vim.fn.exepath "python3",
    args = { vim.fn.stdpath "config" .. "/scripts/tmux-run.py", "--owner", vim.env.TMUX_PANE or "", "--" },
  }
end

function M.terminal_ready()
  if vim.fn.executable "python3" ~= 1 then
    vim.notify("Application runs require python3", vim.log.levels.WARN)
    return false
  end
  if not vim.env.TMUX or not vim.env.TMUX_PANE then
    vim.notify("Application runs require Neovim inside tmux", vim.log.levels.ERROR)
    return false
  end
  return true
end

function M.ready(cwd, current_task)
  if vim.fn.executable "make" ~= 1 then
    vim.notify("Build tasks require make", vim.log.levels.WARN)
    return false
  end
  for _, task in ipairs(require("overseer").list_tasks {}) do
    if task ~= current_task and task.cwd == cwd and task:is_running() then
      vim.notify("A task is already running in " .. cwd, vim.log.levels.WARN)
      return false
    end
  end
  if vim.env.TMUX and vim.fn.executable "python3" == 1 then
    local terminal = M.terminal()
    local cmd = { terminal.command, terminal.args[1], "--owner", vim.env.TMUX_PANE, "--check" }
    local result = vim.system(cmd, { text = true }):wait()
    if result.code ~= 0 then
      vim.notify(vim.trim(result.stderr), vim.log.levels.WARN)
      return false
    end
  end
  return true
end

function M.components()
  return {
    "make_guard",
    { "on_output_quickfix", open_on_exit = "failure", focus = false, tail = false, items_only = true },
    { "open_output", direction = "dock", on_start = "always", focus = false },
    "default",
  }
end

function M.run(target, destination)
  local cwd = vim.fn.getcwd()
  if not M.ready(cwd) or not M.save() then
    return
  end
  if destination == "tmux" then
    if not M.terminal_ready() then
      return
    end
    local terminal = M.terminal()
    local cmd = { terminal.command }
    vim.list_extend(cmd, terminal.args)
    vim.list_extend(cmd, { "make", target })
    vim.system(cmd, { cwd = cwd, text = true }, function(result)
      if result.code ~= 0 then
        vim.schedule(function()
          vim.notify(vim.trim(result.stderr), vim.log.levels.ERROR)
        end)
      end
    end)
    return
  end
  local task = require("overseer").new_task {
    name = "make " .. target,
    cmd = { "make", target },
    cwd = cwd,
    components = M.components(),
  }
  task:start()
  return task
end

function M.setup_mappings()
  for key, target in pairs(targets) do
    vim.keymap.set("n", "<leader>m" .. key, function()
      M.run(target[1], target[2])
    end, { desc = "make " .. target[1] })
  end
  vim.keymap.set("n", "<leader>mo", function()
    require("overseer").toggle { enter = false }
  end, { desc = "make task list" })
  vim.keymap.set("n", "<leader>mq", "<cmd>copen<cr>", { desc = "make errors" })
  vim.keymap.set("n", "<leader>mn", "<cmd>cnext<cr>", { desc = "make next error" })
  vim.keymap.set("n", "<leader>mp", "<cmd>cprevious<cr>", { desc = "make previous error" })
end

return M
