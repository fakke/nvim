-- find the branch this one was actually forked from, not just the repo's
-- default branch: the real parent is whichever ref's merge-base with HEAD
-- sits deepest in history (i.e. most recent), since a branch forked later
-- diverges at a point further downstream than one forked earlier
local function detect_base_branch()
  local current = vim.fn.systemlist("git rev-parse --abbrev-ref HEAD")[1]
  local head_sha = vim.fn.systemlist("git rev-parse HEAD")[1]

  -- a ref's merge-base commit with HEAD, or nil if the ref isn't a real
  -- ancestor (no merge-base, or the "merge-base" is HEAD itself, meaning
  -- the candidate is a descendant, not an ancestor branch)
  local function merge_base(ref)
    local mb = vim.fn.systemlist("git merge-base HEAD " .. ref .. " 2>/dev/null")[1]
    if not mb or mb == "" or mb == head_sha then
      return nil
    end
    return mb
  end

  -- true if `a` is an ancestor of (or the same commit as) `b`. this - not
  -- commit timestamps - is how "more downstream" gets decided: commits made
  -- in a burst (rebase, squash, a fast run of manual commits) can share the
  -- same second-resolution timestamp, which would make a wall-clock
  -- comparison pick the wrong branch on a tie; ancestry is exact regardless
  local function is_ancestor(a, b)
    vim.fn.system("git merge-base --is-ancestor " .. a .. " " .. b)
    return vim.v.shell_error == 0
  end

  -- the repo's default branch (main/master) is always a trivially valid
  -- ancestor of everything, so its own merge-base can't be used as a signal
  -- for "did the scan find a real answer" - a candidate has to sit strictly
  -- downstream of it, not just share the same fork point (e.g. an unrelated
  -- sibling branch forked from the same commit isn't a genuine ancestor)
  local default_branch = vim.fn.systemlist("git symbolic-ref refs/remotes/origin/HEAD --short 2>/dev/null")[1]
  default_branch = default_branch and default_branch:gsub("^origin/", "")
  local floor_mb = default_branch and merge_base(default_branch) or nil

  local function find_in(refs)
    local best_ref, best_mb = nil, floor_mb
    for _, ref in ipairs(refs) do
      if ref ~= current and ref ~= "origin/" .. current and ref ~= "origin/HEAD" and ref ~= default_branch then
        local mb = merge_base(ref)
        if mb and mb ~= best_mb and (not best_mb or is_ancestor(best_mb, mb)) then
          best_mb, best_ref = mb, ref
        end
      end
    end
    return best_ref
  end

  -- scan local branches first: on a stacked-branch workflow the parent is
  -- almost always already checked out, and this stays small even in repos
  -- with hundreds of remote branches. only fall back to scanning every
  -- remote-tracking branch (which can be genuinely large and slow to
  -- search) if nothing local beats the default branch, e.g. right after a
  -- fresh clone, or when the current branch forks straight off the default
  local local_refs = vim.fn.systemlist "git for-each-ref --format='%(refname:short)' refs/heads"

  return find_in(local_refs)
    or find_in(vim.fn.systemlist "git for-each-ref --format='%(refname:short)' refs/remotes/origin")
    or default_branch
end

return {
  {
    "sindrets/diffview.nvim",
    lazy = true,
    cmd = { "DiffviewOpen", "DiffviewFileHistory" },
    keys = {
      { "<leader>gd", ":DiffviewOpen<CR>", mode = "n", desc = "Git diff" },
      { "<leader>gD", ":q<CR>:q<CR>:q<CR>", mode = "n", desc = "Git diff close" },
      { "<leader>gh", ":DiffviewFileHistory<CR>", mode = "n", desc = "Git history" },
      {
        "<leader>gp",
        function()
          local base = detect_base_branch()
          if not base then
            vim.notify("could not detect a parent branch", vim.log.levels.WARN)
            return
          end
          vim.cmd("DiffviewOpen " .. base .. "...HEAD")
        end,
        mode = "n",
        desc = "Git diff vs PR base",
      },
    },
    dependencies = "nvim-lua/plenary.nvim",
    -- default file panel keymaps open the diff for an entry without moving
    -- the cursor there (`select_entry`); switch <cr>/o/l to `focus_entry`
    -- so they open *and* jump focus to the diff, like everywhere else
    config = function()
      local actions = require "diffview.actions"
      require("diffview").setup {
        keymaps = {
          file_panel = {
            ["<cr>"] = actions.focus_entry,
            ["o"] = actions.focus_entry,
            ["l"] = actions.focus_entry,
          },
        },
      }
    end,
  },
}
