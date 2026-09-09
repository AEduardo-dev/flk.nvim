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

return M
