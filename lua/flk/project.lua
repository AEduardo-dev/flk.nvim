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

---Read `defaultProfile` from `<root>/.flk/config.nix`.
---
---The file is flk-generated and simple, so a pattern is enough. A hand-edited
---config with unusual formatting will defeat it; callers should fall back to
---asking nix (`nix eval --raw .#defaultShell.<system>`).
---@param root string Project root
---@return string? profile
function M.default_profile(root)
  local path = root .. "/.flk/config.nix"
  local fd = vim.uv.fs_open(path, "r", 420)
  if not fd then
    return nil
  end

  local stat = vim.uv.fs_fstat(fd)
  local content = stat and vim.uv.fs_read(fd, stat.size, 0) or nil
  vim.uv.fs_close(fd)
  if not content then
    return nil
  end

  local profile = content:match('defaultProfile%s*=%s*"([^"]*)"')
  if not M.is_valid_profile(profile) then
    return nil
  end

  return profile
end

---List profile names from `<root>/.flk/profiles/*.nix`.
---
---Used for instant completion. It misses flk's generated profile
---combinations, which only nix can enumerate.
---@param root string Project root
---@return string[] names
function M.profile_files(root)
  local dir = root .. "/.flk/profiles"
  local handle = vim.uv.fs_scandir(dir)
  if not handle then
    return {}
  end

  local names = {}
  while true do
    local name, kind = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end
    if
      kind ~= "directory"
      and name:sub(-4) == ".nix"
      and name ~= "default.nix"
    then
      local profile = name:sub(1, -5)
      if M.is_valid_profile(profile) then
        table.insert(names, profile)
      end
    end
  end

  return names
end

return M
