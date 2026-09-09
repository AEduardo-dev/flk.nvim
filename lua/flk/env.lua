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

return M
