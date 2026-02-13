require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")

map("n", "<leader>X", function()
  local bufs = vim.api.nvim_list_bufs()
  for _, buf in ipairs(bufs) do
    if
      vim.bo[buf].filetype ~= "NvimTree"
      and vim.bo[buf].buftype ~= "terminal"
      and buf ~= vim.api.nvim_get_current_buf()
    then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  vim.cmd 'normal`"'
end, { desc = "buffer close others" })

map("t", "<C-q>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })
