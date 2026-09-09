local h = dofile("tests/helpers.lua")
local flk = require("flk")

return {
  ["command uses the flake ref when the cache is stale"] = function()
    h.same(flk._command("/p", "rust", false), {
      "nix",
      "develop",
      ".#rust",
      "--extra-experimental-features",
      "nix-command flakes",
      "--impure",
      "--profile",
      "/p/.flk/.nix-profile-rust",
      "-c",
      "env",
      "-0",
    })
  end,

  ["command uses the cached profile when fresh"] = function()
    -- No --profile: the cache is being read, not rebuilt.
    h.same(flk._command("/p", "rust", true), {
      "nix",
      "develop",
      "/p/.flk/.nix-profile-rust",
      "--extra-experimental-features",
      "nix-command flakes",
      "--impure",
      "-c",
      "env",
      "-0",
    })
  end,

  ["SHELL is ignored by default"] = function()
    -- nix develop exports SHELL pointing at store bash, which breaks :terminal.
    h.ok(flk.ignored_variables.SHELL)
    h.ok(flk.ignored_variables.HOME)
    h.ok(flk.ignored_variables.TERM)
  end,

  ["resolve_profile prefers the explicit argument"] = function()
    local dir = h.tmpdir()
    h.write(dir .. "/.flk/config.nix", '{ defaultProfile = "rust"; }')
    h.eq(flk._resolve_profile(dir, "docs"), "docs")
  end,

  ["resolve_profile falls back to the active profile"] = function()
    local dir = h.tmpdir()
    h.write(dir .. "/.flk/config.nix", '{ defaultProfile = "rust"; }')

    local env = require("flk.env")
    env.reset()
    env.activate({ FLK_TEST_REFRESH = "1" }, {}, "docs")

    h.eq(flk._resolve_profile(dir, nil), "docs", "no argument should refresh the active profile")

    env.deactivate()
  end,

  ["resolve_profile falls back to the configured default"] = function()
    local dir = h.tmpdir()
    h.write(dir .. "/.flk/config.nix", '{ defaultProfile = "rust"; }')
    require("flk.env").reset()
    h.eq(flk._resolve_profile(dir, nil), "rust")
  end,

  ["resolve_profile returns nil with no argument, no active profile and no default"] = function()
    local dir = h.tmpdir()
    h.write(dir .. "/.flk/config.nix", "{ }")
    require("flk.env").reset()
    h.falsy(flk._resolve_profile(dir, nil))
  end,

  ["available_profiles lists what the project offers"] = function()
    -- Used to make the "no default profile" error actionable rather than a
    -- dead end. Reads the filesystem only, so it works before nix has answered.
    local dir = h.tmpdir()
    h.write(dir .. "/.flk/profiles/rust.nix", "{}")
    h.write(dir .. "/.flk/profiles/docs.nix", "{}")
    h.eq(flk._available_profiles(dir), "docs, rust")
  end,

  ["available_profiles reports none when there are no profiles"] = function()
    local dir = h.tmpdir()
    vim.fn.mkdir(dir .. "/.flk", "p")
    h.eq(flk._available_profiles(dir), "none")
  end,

  ["resolve_profile rejects an invalid argument"] = function()
    local dir = h.tmpdir()
    h.write(dir .. "/.flk/config.nix", '{ defaultProfile = "rust"; }')
    h.falsy(flk._resolve_profile(dir, "../evil"))
  end,

  ["complete filters the candidate list by prefix"] = function()
    flk._set_profiles({ "default", "docs", "docs-rust", "rust" })
    h.same(flk.complete("do"), { "docs", "docs-rust" })
    h.same(flk.complete("r"), { "rust" })
  end,

  ["complete with an empty prefix returns everything"] = function()
    flk._set_profiles({ "docs", "rust" })
    h.same(flk.complete(""), { "docs", "rust" })
  end,

  ["complete returns a sorted list"] = function()
    flk._set_profiles({ "rust", "docs", "default" })
    h.same(flk.complete(""), { "default", "docs", "rust" })
  end,

  ["complete escapes prefix characters that are magic in Lua patterns"] =
    function()
      flk._set_profiles({ "docs", "rust" })
      h.same(flk.complete("-"), {})
    end,
}
