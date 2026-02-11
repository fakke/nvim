return {
  {
    "sindrets/diffview.nvim",
    lazy = true,
    cmd = { "DiffviewOpen", "DiffviewFileHistory" },
    keys = {
      { "<leader>gd", ":DiffviewOpen<CR>", mode = "n", desc = "Git diff" },
      { "<leader>gD", ":q<CR>:q<CR>:q<CR>", mode = "n", desc = "Git diff close" },
      { "<leader>gh", ":DiffviewFileHistory<CR>", mode = "n", desc = "Git history" },
    },
    dependencies = "nvim-lua/plenary.nvim",
  },
}
