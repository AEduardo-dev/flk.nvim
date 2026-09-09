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

return M
