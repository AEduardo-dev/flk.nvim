---@mod flk.project Locating and reading an flk project

local M = {}

-- Matches flk's own `_flk_valid_profile` (see flk src/commands/hook.rs).
-- Rejecting path separators here is what keeps a profile name from escaping
-- `.flk/profiles/` when it is interpolated into a path.
local VALID_PROFILE = "^[a-zA-Z0-9_-]+$"

---Is `name` a usable flk profile name?
---@param name any
---@return boolean
function M.is_valid_profile(name)
  return type(name) == "string" and name:match(VALID_PROFILE) ~= nil
end

---Find the flk project root by walking up from `start` looking for `.flk/`.
---@param start? string Directory to start from (default: the cwd)
---@return string? root Absolute, symlink-resolved path, or nil if not found
function M.find_root(start)
  local from = start or vim.fn.getcwd()
  local found = vim.fs.find(".flk", {
    path = from,
    upward = true,
    type = "directory",
  })[1]

  if not found then
    return nil
  end

  return vim.fn.resolve(vim.fs.dirname(found))
end

return M
