---@mod flk.env Applying and reversing an flk environment

local M = {}

---Parse the NUL-separated output of `env -0` into a name/value table.
---
---Splitting on NUL rather than newlines is what makes values containing
---newlines — shell functions, multi-line hooks — survive intact.
---@param output string
---@return table<string, string>
function M.parse(output)
  local vars = {}

  for _, entry in ipairs(vim.split(output, "\0", { plain = true })) do
    local name, value = entry:match("^([^=]+)=(.*)$")
    if name then
      vars[name] = value
    end
  end

  return vars
end

---What `new` changes relative to `current`, ignoring names in `ignored`.
---
---Variables present in `current` but absent from `new` are left alone: the dev
---shell inherits Neovim's environment, so an absence means "nix did not touch
---it", never "nix removed it".
---@param current table<string, string>
---@param new table<string, string>
---@param ignored table<string, boolean>
---@return table<string, string>
function M.diff(current, new, ignored)
  local changes = {}

  for name, value in pairs(new) do
    if not ignored[name] and current[name] ~= value then
      changes[name] = value
    end
  end

  return changes
end

-- The environment as it stood before the first activation. Every diff is taken
-- against this, never against the currently-active environment, so repeated
-- switches cannot accumulate.
local baseline = nil

-- Names currently overridden by an active profile.
local applied = {}

local active = nil

---@param name string
---@param value string? nil unsets
local function set(name, value)
  if value == nil then
    vim.uv.os_unsetenv(name)
  else
    vim.uv.os_setenv(name, value)
  end
end

local function ensure_baseline()
  if not baseline then
    baseline = vim.fn.environ()
  end
  return baseline
end

---The PATH as it stood before any activation — flk's `FLK_ORIG_PATH`.
---
---Nix is always spawned with this PATH so a switch rebuilds from a clean
---baseline instead of layering onto the previous profile.
---@return string
function M.baseline_path()
  return ensure_baseline().PATH or ""
end

---A copy of the environment as it stood before any activation.
---
---Nix must always be spawned from this pre-activation snapshot, not from
---Neovim's current environment: `vim.system`'s `env` option merges over the
---inherited environment rather than replacing it, so spawning from the
---current environment would leak the previously-activated profile's
---variables into the child, which would then report them back as if they
---belonged to the profile being entered. Returned as a copy so callers
---cannot mutate the stored baseline.
---@return table<string, string>
function M.baseline_env()
  return vim.deepcopy(ensure_baseline())
end

---The active profile name, or nil.
---@return string?
function M.active_profile()
  return active
end

---Apply a dev shell environment, replacing any previously applied one.
---@param vars table<string, string> Parsed `env -0` output
---@param ignored table<string, boolean> Names never to import
---@param profile string
function M.activate(vars, ignored, profile)
  local base = ensure_baseline()
  local changes = M.diff(base, vars, ignored)

  -- Anything the previous profile set that this one does not: back to baseline.
  for name in pairs(applied) do
    if changes[name] == nil then
      set(name, base[name])
      applied[name] = nil
    end
  end

  for name, value in pairs(changes) do
    set(name, value)
    applied[name] = true
  end

  active = profile
end

---Restore the environment as it stood before the first activation.
function M.deactivate()
  if not baseline then
    return
  end

  for name in pairs(applied) do
    set(name, baseline[name])
  end

  applied = {}
  active = nil
  baseline = nil
end

---Drop all state without touching the environment. Tests only.
function M.reset()
  baseline = nil
  applied = {}
  active = nil
end

return M
