-- Run with: nvim --headless -l tests/run.lua
-- Exits non-zero if any test fails.
package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local files = vim.fn.glob("tests/*_spec.lua", false, true)
table.sort(files)

local total, failures = 0, {}

for _, file in ipairs(files) do
  local suite = dofile(file)
  local names = vim.tbl_keys(suite)
  table.sort(names)
  for _, name in ipairs(names) do
    total = total + 1
    local ok, err = pcall(suite[name])
    if ok then
      io.write(".")
    else
      io.write("F")
      table.insert(failures, string.format("%s :: %s\n    %s", file, name, tostring(err)))
    end
  end
end

io.write("\n\n")
for _, failure in ipairs(failures) do
  io.write(failure, "\n\n")
end
io.write(string.format("%d tests, %d failures\n", total, #failures))

os.exit(#failures > 0 and 1 or 0)
