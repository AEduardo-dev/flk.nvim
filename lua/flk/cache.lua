---@mod flk.cache flk's per-profile nix profile cache
---
---Mirrors flk src/commands/profile_cache.rs so a profile warmed by the flk
---CLI activates instantly here, and vice versa.

local M = {}

-- The slim layout keeps the mkProject driver in a remote flake, so bumps
-- arrive through flake.lock rather than local .nix files.
local SLIM_INPUTS = {
  "flake.nix",
  "flake.lock",
  ".flk/config.nix",
  ".flk/pins.nix",
}

local LEGACY_INPUTS = {
  "flake.nix",
  "flake.lock",
  ".flk/default.nix",
  ".flk/pins.nix",
  ".flk/overlays.nix",
}

---Path of the cached nix profile for `profile`.
---@param root string
---@param profile string
---@return string
function M.profile_path(root, profile)
  return root .. "/.flk/.nix-profile-" .. profile
end

---Path of the freshness stamp for `profile`.
---@param root string
---@param profile string
---@return string
function M.stamp_path(root, profile)
  return M.profile_path(root, profile) .. ".stamp"
end

---Absolute paths whose mtime decides whether the cache is stale.
---@param root string
---@param profile string
---@return string[]
function M.inputs(root, profile)
  local slim = vim.uv.fs_stat(root .. "/.flk/config.nix") ~= nil
  local base = slim and SLIM_INPUTS or LEGACY_INPUTS

  local paths = {}
  for _, relative in ipairs(base) do
    table.insert(paths, root .. "/" .. relative)
  end
  table.insert(paths, root .. "/.flk/profiles/" .. profile .. ".nix")

  return paths
end

---Is `a` strictly newer than `b`? Both are `vim.uv` stat tables.
---@param a table
---@param b table
---@return boolean
local function newer_than(a, b)
  if a.mtime.sec ~= b.mtime.sec then
    return a.mtime.sec > b.mtime.sec
  end
  return (a.mtime.nsec or 0) > (b.mtime.nsec or 0)
end

---Can the cached profile be reused as-is?
---
---False whenever the cached profile or its stamp is missing, or any watched
---input is newer than the stamp. Inputs that do not exist are skipped,
---matching flk's `[ -e "$f" ] || continue`.
---@param root string
---@param profile string
---@return boolean
function M.is_fresh(root, profile)
  -- fs_stat follows symlinks, so a dangling profile link reads as absent —
  -- the same as flk's `[ -e ]` test.
  if not vim.uv.fs_stat(M.profile_path(root, profile)) then
    return false
  end

  local stamp = vim.uv.fs_stat(M.stamp_path(root, profile))
  if not stamp then
    return false
  end

  for _, path in ipairs(M.inputs(root, profile)) do
    local stat = vim.uv.fs_stat(path)
    if stat and newer_than(stat, stamp) then
      return false
    end
  end

  return true
end

return M
