local h = dofile("tests/helpers.lua")
local env = require("flk.env")

return {
  ["parse reads NUL-separated pairs"] = function()
    h.same(env.parse("A=1\0B=2\0"), { A = "1", B = "2" })
  end,

  ["parse keeps values containing equals signs"] = function()
    h.same(env.parse("URL=postgres://h/d?x=1\0"), { URL = "postgres://h/d?x=1" })
  end,

  ["parse keeps values containing newlines"] = function()
    h.same(env.parse("HOOK=line1\nline2\0X=1\0"), { HOOK = "line1\nline2", X = "1" })
  end,

  ["parse keeps empty values"] = function()
    h.same(env.parse("EMPTY=\0"), { EMPTY = "" })
  end,

  ["parse tolerates a missing trailing NUL"] = function()
    h.same(env.parse("A=1\0B=2"), { A = "1", B = "2" })
  end,

  ["parse skips entries without an equals sign"] = function()
    h.same(env.parse("A=1\0garbage\0B=2\0"), { A = "1", B = "2" })
  end,

  ["parse returns an empty table for empty input"] = function()
    h.same(env.parse(""), {})
  end,
}
