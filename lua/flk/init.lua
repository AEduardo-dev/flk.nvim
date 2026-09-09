---@mod flk flk environments for Neovim
---@tag flk.nvim
---@tag :Flk
---@brief [[
---Enter an flk-managed development environment from inside Neovim.
--->
---:Flk
---:Flk docs
---:FlkOff
---<
---@brief ]]

local cache = require("flk.cache")
local env = require("flk.env")
local project = require("flk.project")

local M = {}

---Variables never imported from the dev shell.
---
---`SHELL` is the important one: `nix develop` points it at nixpkgs'
---non-interactive bash, which breaks `:terminal`. The rest describe the shell
---that produced the environment, not the environment itself.
--->lua
---require("flk").ignored_variables["SHELL"] = false
---<
---@class ignored_variables
M.ignored_variables = {
  BASHOPTS = true,
  HOME = true,
  OLDPWD = true,
  PWD = true,
  SHELL = true,
  SHELLOPTS = true,
  SHLVL = true,
  TEMP = true,
  TEMPDIR = true,
  TERM = true,
  TMP = true,
  TMPDIR = true,
  UID = true,
  _ = true,
}

---Build the nix command that dumps a profile's environment.
---@param root string Project root
---@param profile string
---@param fresh boolean Whether the profile cache can be read as-is
---@return string[]
---@private
function M._command(root, profile, fresh)
  local profile_path = cache.profile_path(root, profile)
  local ref = fresh and profile_path or (".#" .. profile)

  local cmd = {
    "nix",
    "develop",
    ref,
    "--extra-experimental-features",
    "nix-command flakes",
    "--impure",
  }

  if not fresh then
    vim.list_extend(cmd, { "--profile", profile_path })
  end

  vim.list_extend(cmd, { "-c", "env", "-0" })

  return cmd
end

local levels = vim.log.levels

-- nvim_echo must not be called from a libuv callback.
local function notify(msg, level)
  vim.schedule(function()
    vim.notify("flk: " .. msg, level or levels.INFO)
  end)
end

-- One activation at a time: a cold profile can take minutes, and two
-- concurrent runs would race on the environment and the cache stamp.
local running = false

---Pick the profile to activate.
---@param root string
---@param requested string? Explicit profile, if the user named one
---@return string? profile nil when nothing valid could be resolved
---@private
function M._resolve_profile(root, requested)
  if requested then
    return project.is_valid_profile(requested) and requested or nil
  end

  return env.active_profile() or project.default_profile(root)
end

---A human-readable list of the profiles this project defines.
---
---Filesystem only, so it is instant and works before nix has been asked. It
---misses flk's generated combinations, which is fine for an error message.
---@param root string
---@return string
---@private
function M._available_profiles(root)
  local names = project.profile_files(root)
  if #names == 0 then
    return "none"
  end

  table.sort(names)
  return table.concat(names, ", ")
end

---Record that the cache at `profile_path` is current as of now.
---@param root string
---@param profile string
local function touch_stamp(root, profile)
  if not vim.uv.fs_stat(cache.profile_path(root, profile)) then
    return
  end

  local stamp = cache.stamp_path(root, profile)
  local fd = vim.uv.fs_open(stamp, "w", 420)
  if fd then
    vim.uv.fs_close(fd)
  end
end

---Report a failed nix run with enough context to debug it.
---@param result table Result from vim.system
local function report_failure(result)
  local stderr = vim.trim(result.stderr or "")
  local lines = vim.split(stderr, "\n", { trimempty = true })
  local tail = {}
  for i = math.max(1, #lines - 5), #lines do
    table.insert(tail, lines[i])
  end

  local detail = #tail > 0 and ("\n" .. table.concat(tail, "\n")) or ""
  notify(
    string.format("nix exited with code %d%s", result.code, detail),
    levels.ERROR
  )
end

---Enter an flk profile's environment.
---
---With no argument this refreshes the active profile, or enters the project's
---default profile when nothing is active.
---@param requested string? Profile name
---@usage `require("flk").activate("docs")`
function M.activate(requested)
  if running then
    notify("an activation is already running", levels.WARN)
    return
  end

  local root = project.find_root()
  if not root then
    notify("not an flk project (no .flk/ directory found)", levels.ERROR)
    return
  end

  local profile = M._resolve_profile(root, requested)
  if not profile then
    if requested then
      notify(string.format("invalid profile name: %s", requested), levels.ERROR)
    else
      -- No nix-eval fallback here on purpose: resolution is synchronous, and
      -- naming the profiles the user can pass is more useful than a slow guess.
      notify(
        string.format(
          "no profile given and no defaultProfile in .flk/config.nix; available: %s",
          M._available_profiles(root)
        ),
        levels.ERROR
      )
    end
    return
  end

  local fresh = cache.is_fresh(root, profile)
  local baseline_path = env.baseline_path()

  notify(
    string.format(
      "activating %s%s",
      profile,
      fresh and "" or " (building, this may take a while)"
    )
  )

  running = true
  vim.system(M._command(root, profile, fresh), {
    cwd = root,
    text = true,
    -- Merged over Neovim's environment. Forcing PATH back to the baseline is
    -- what keeps a switch from layering onto the previous profile; see
    -- flk src/commands/hook.rs.
    env = {
      PATH = baseline_path,
      FLK_ORIG_PATH = baseline_path,
    },
  }, function(result)
    running = false

    if result.code ~= 0 then
      vim.schedule(function()
        report_failure(result)
      end)
      return
    end

    local vars = env.parse(result.stdout or "")
    if vim.tbl_isempty(vars) then
      notify("nix produced an empty environment; nothing changed", levels.ERROR)
      return
    end

    vim.schedule(function()
      env.activate(vars, M.ignored_variables, profile)
      if not fresh then
        touch_stamp(root, profile)
      end
      notify(string.format("entered %s", profile))
    end)
  end)
end

---Restore the environment as it stood before the first activation.
---@usage `require("flk").deactivate()`
function M.deactivate()
  if not env.active_profile() then
    notify("no active profile", levels.WARN)
    return
  end

  local profile = env.active_profile()
  env.deactivate()
  notify(string.format("left %s", profile))
end

---The active profile name, or nil.
---@return string?
---@usage `require("flk").status()`
function M.status()
  return env.active_profile()
end

return M
