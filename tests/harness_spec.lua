local h = dofile("tests/helpers.lua")

return {
  ["eq passes on equal values"] = function()
    h.eq(1 + 1, 2)
  end,

  ["eq raises on unequal values"] = function()
    local ok = pcall(h.eq, 1, 2)
    h.falsy(ok, "eq should have raised")
  end,

  ["same compares tables deeply"] = function()
    h.same({ a = { b = 1 } }, { a = { b = 1 } })
    local ok = pcall(h.same, { a = 1 }, { a = 2 })
    h.falsy(ok, "same should have raised")
  end,

  ["write and tmpdir round trip"] = function()
    local dir = h.tmpdir()
    h.write(dir .. "/sub/file.txt", "hello")
    h.eq(table.concat(vim.fn.readfile(dir .. "/sub/file.txt"), "\n"), "hello")
  end,
}
