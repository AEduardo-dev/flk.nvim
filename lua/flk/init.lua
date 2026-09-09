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

  notify(
    string.format(
      "activating %s%s",
      profile,
      fresh and "" or " (building, this may take a while)"
    )
  )

  local child_env = env.baseline_env()
  child_env.FLK_ORIG_PATH = child_env.PATH

  running = true
  vim.system(M._command(root, profile, fresh), {
    cwd = root,
    text = true,
    -- vim.system's `env` merges over the inherited environment rather than
    -- replacing it, so without clear_env the child would inherit the active
    -- profile's variables and report them back as if they belonged to the
    -- profile being entered. Spawning from the baseline with clear_env
    -- ensures the child gets exactly the pre-activation environment.
    env = child_env,
    clear_env = true,
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

-- Completion candidates for this session. Seeded from the profiles directory,
-- then replaced by the flake's devShells once nix has answered.
local profiles = nil
local profiles_pending = false

---Replace the cached completion candidates. Tests and the nix callback.
---@param names string[]
---@private
function M._set_profiles(names)
  profiles = vim.deepcopy(names)
  table.sort(profiles)
end

---Nix's name for the current system, e.g. "x86_64-linux" or "aarch64-darwin".
---@return string
local function nix_system()
  local uname = vim.uv.os_uname()

  -- Darwin reports "arm64"; nix calls it "aarch64".
  local arch = uname.machine == "arm64" and "aarch64" or uname.machine

  return arch .. "-" .. uname.sysname:lower()
end

---Ask nix for the flake's devShell names, including generated combinations.
---@param root string
local function refresh_profiles(root)
  if profiles_pending then
    return
  end
  profiles_pending = true

  vim.system({
    "nix",
    "eval",
    "--extra-experimental-features",
    "nix-command flakes",
    "--impure",
    "--json",
    string.format(".#devShells.%s", nix_system()),
    "--apply",
    "builtins.attrNames",
  }, { cwd = root, text = true }, function(result)
    profiles_pending = false
    if result.code ~= 0 then
      return
    end

    local ok, names = pcall(vim.json.decode, result.stdout or "")
    if ok and type(names) == "table" and #names > 0 then
      vim.schedule(function()
        M._set_profiles(names)
      end)
    end
  end)
end

---Completion candidates for `:Flk`.
---@param prefix string
---@return string[]
---@usage `require("flk").complete("do")`
function M.complete(prefix)
  if not profiles then
    local root = project.find_root()
    if not root then
      return {}
    end
    M._set_profiles(project.profile_files(root))
    refresh_profiles(root)
  end

  local matches = {}
  for _, name in ipairs(profiles) do
    if vim.startswith(name, prefix) then
      table.insert(matches, name)
    end
  end

  return matches
end

---All known profile names.
---@return string[]
---@usage `require("flk").profiles()`
function M.profiles()
  return M.complete("")
end

return M
