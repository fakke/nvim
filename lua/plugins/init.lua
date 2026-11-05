local function can_build_parsers()
  local has = vim.fn.executable
  return has "tree-sitter" == 1
    and (has "cc" == 1 or has "gcc" == 1 or has "clang" == 1)
    and has "curl" == 1
    and has "tar" == 1
end

return {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = function()
      if can_build_parsers() then
        vim.cmd "TSUpdate"
      end
    end,
    opts = function()
      return require "configs.treesitter"
    end,
    config = function(_, opts)
      local treesitter = require "nvim-treesitter"
      treesitter.setup {}
      if can_build_parsers() then
        treesitter.install(opts.ensure_installed)
      end
    end,
  },

  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    lazy = false,
    dependencies = { "mason-org/mason.nvim" },
    opts = function()
      return require "configs.mason"
    end,
  },

  -- test new blink
  -- { import = "nvchad.blink.lazyspec" },

  -- {
  -- 	"nvim-treesitter/nvim-treesitter",
  -- 	opts = {
  -- 		ensure_installed = {
  -- 			"vim", "lua", "vimdoc",
  --      "html", "css"
  -- 		},
  -- 	},
  -- },
}
