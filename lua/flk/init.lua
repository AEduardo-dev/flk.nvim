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

return M
