local h = dofile("tests/helpers.lua")
local cache = require("flk.cache")

return {
  ["profile_path and stamp_path follow flk's naming"] = function()
    h.eq(cache.profile_path("/p", "rust"), "/p/.flk/.nix-profile-rust")
    h.eq(cache.stamp_path("/p", "rust"), "/p/.flk/.nix-profile-rust.stamp")
  end,

  ["inputs uses the slim set when config.nix exists"] = function()
    local dir = h.tmpdir()
    h.write(dir .. "/.flk/config.nix", "{}")
    h.same(cache.inputs(dir, "rust"), {
      dir .. "/flake.nix",
      dir .. "/flake.lock",
      dir .. "/.flk/config.nix",
      dir .. "/.flk/pins.nix",
      dir .. "/.flk/profiles/rust.nix",
    })
  end,

  ["inputs uses the legacy set without config.nix"] = function()
    local dir = h.tmpdir()
    vim.fn.mkdir(dir .. "/.flk", "p")
    h.same(cache.inputs(dir, "rust"), {
      dir .. "/flake.nix",
      dir .. "/flake.lock",
      dir .. "/.flk/default.nix",
      dir .. "/.flk/pins.nix",
      dir .. "/.flk/overlays.nix",
      dir .. "/.flk/profiles/rust.nix",
    })
  end,
}
