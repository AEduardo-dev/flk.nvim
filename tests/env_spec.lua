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

  ["diff reports new variables"] = function()
    h.same(env.diff({ A = "1" }, { A = "1", B = "2" }, {}), { B = "2" })
  end,

  ["diff reports changed variables"] = function()
    h.same(env.diff({ PATH = "/usr/bin" }, { PATH = "/nix/bin:/usr/bin" }, {}), {
      PATH = "/nix/bin:/usr/bin",
    })
  end,

  ["diff skips unchanged variables"] = function()
    h.same(env.diff({ A = "1" }, { A = "1" }, {}), {})
  end,

  ["diff honours the ignore list"] = function()
    -- SHELL from a nix shell points at non-interactive bash in the store and
    -- would break :terminal if it leaked into Neovim.
    h.same(env.diff({ SHELL = "/bin/zsh" }, { SHELL = "/nix/store/x/bash", A = "1" }, {
      SHELL = true,
    }), { A = "1" })
  end,

  ["diff does not report variables missing from the new env"] = function()
    -- Neovim's own variables must survive activation.
    h.same(env.diff({ NVIM_LOG_FILE = "/tmp/log" }, { A = "1" }, {}), { A = "1" })
  end,

  ["activate sets variables and records the profile"] = function()
    env.reset()
    vim.uv.os_setenv("FLK_TEST_ORIGINAL", "before")
    vim.uv.os_unsetenv("FLK_TEST_NEW")

    env.activate({ FLK_TEST_ORIGINAL = "after", FLK_TEST_NEW = "fresh" }, {}, "rust")

    h.eq(vim.uv.os_getenv("FLK_TEST_ORIGINAL"), "after")
    h.eq(vim.uv.os_getenv("FLK_TEST_NEW"), "fresh")
    h.eq(env.active_profile(), "rust")

    env.deactivate()
  end,

  ["deactivate restores prior values and unsets new ones"] = function()
    env.reset()
    vim.uv.os_setenv("FLK_TEST_ORIGINAL", "before")
    vim.uv.os_unsetenv("FLK_TEST_NEW")

    env.activate({ FLK_TEST_ORIGINAL = "after", FLK_TEST_NEW = "fresh" }, {}, "rust")
    env.deactivate()

    h.eq(vim.uv.os_getenv("FLK_TEST_ORIGINAL"), "before")
    h.falsy(vim.uv.os_getenv("FLK_TEST_NEW"))
    h.falsy(env.active_profile())
  end,

  ["switching profiles diffs against the original baseline"] = function()
    -- The bug this prevents: rust's store paths surviving a switch to docs.
    env.reset()
    vim.uv.os_setenv("FLK_TEST_PATH", "/usr/bin")

    env.activate({ FLK_TEST_PATH = "/nix/rust:/usr/bin" }, {}, "rust")
    env.activate({ FLK_TEST_PATH = "/nix/docs:/usr/bin" }, {}, "docs")

    h.eq(vim.uv.os_getenv("FLK_TEST_PATH"), "/nix/docs:/usr/bin")
    h.eq(env.active_profile(), "docs")

    env.deactivate()
    h.eq(vim.uv.os_getenv("FLK_TEST_PATH"), "/usr/bin")
  end,

  ["a variable dropped by the new profile returns to its baseline"] = function()
    env.reset()
    vim.uv.os_setenv("FLK_TEST_ORIGINAL", "before")
    vim.uv.os_unsetenv("FLK_TEST_ONLY_RUST")

    env.activate(
      { FLK_TEST_ORIGINAL = "after", FLK_TEST_ONLY_RUST = "yes" },
      {},
      "rust"
    )
    env.activate({ FLK_TEST_ORIGINAL = "after" }, {}, "docs")

    h.eq(vim.uv.os_getenv("FLK_TEST_ORIGINAL"), "after")
    h.falsy(
      vim.uv.os_getenv("FLK_TEST_ONLY_RUST"),
      "rust-only variable should be gone"
    )

    env.deactivate()
  end,

  ["baseline_path reports the pre-activation PATH"] = function()
    env.reset()
    local before = vim.uv.os_getenv("PATH")

    h.eq(env.baseline_path(), before)
    env.activate({ PATH = "/nix/rust:" .. before }, {}, "rust")
    h.eq(env.baseline_path(), before, "baseline must not drift after activation")

    env.deactivate()
    h.eq(vim.uv.os_getenv("PATH"), before)
  end,

  ["deactivate with nothing active is a no-op"] = function()
    env.reset()
    h.falsy(env.active_profile())
    env.deactivate()
    h.falsy(env.active_profile())
  end,
}
