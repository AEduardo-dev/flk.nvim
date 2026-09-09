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

return M
