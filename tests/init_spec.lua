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
}
