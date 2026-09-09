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

  ["is_fresh is false without a cached profile"] = function()
    local dir = h.tmpdir()
    h.write(dir .. "/.flk/config.nix", "{}")
    h.falsy(cache.is_fresh(dir, "rust"))
  end,

  ["is_fresh is false without a stamp"] = function()
    local dir = h.tmpdir()
    h.write(dir .. "/.flk/config.nix", "{}")
    h.write(dir .. "/.flk/.nix-profile-rust", "")
    h.falsy(cache.is_fresh(dir, "rust"))
  end,

  ["is_fresh is true when every input predates the stamp"] = function()
    local dir = h.tmpdir()
    h.write(dir .. "/flake.nix", "{}")
    h.write(dir .. "/flake.lock", "{}")
    h.write(dir .. "/.flk/config.nix", "{}")
    h.write(dir .. "/.flk/pins.nix", "{}")
    h.write(dir .. "/.flk/profiles/rust.nix", "{}")
    h.write(dir .. "/.flk/.nix-profile-rust", "")
    h.write(dir .. "/.flk/.nix-profile-rust.stamp", "")

    for _, path in ipairs(cache.inputs(dir, "rust")) do
      h.set_mtime(path, 1000)
    end
    h.set_mtime(dir .. "/.flk/.nix-profile-rust.stamp", 2000)

    h.ok(cache.is_fresh(dir, "rust"))
  end,

  ["is_fresh is false when an input is newer than the stamp"] = function()
    local dir = h.tmpdir()
    h.write(dir .. "/flake.nix", "{}")
    h.write(dir .. "/flake.lock", "{}")
    h.write(dir .. "/.flk/config.nix", "{}")
    h.write(dir .. "/.flk/pins.nix", "{}")
    h.write(dir .. "/.flk/profiles/rust.nix", "{}")
    h.write(dir .. "/.flk/.nix-profile-rust", "")
    h.write(dir .. "/.flk/.nix-profile-rust.stamp", "")

    for _, path in ipairs(cache.inputs(dir, "rust")) do
      h.set_mtime(path, 1000)
    end
    h.set_mtime(dir .. "/.flk/.nix-profile-rust.stamp", 2000)
    h.set_mtime(dir .. "/.flk/profiles/rust.nix", 3000)

    h.falsy(cache.is_fresh(dir, "rust"))
  end,

  ["is_fresh ignores inputs that do not exist"] = function()
    -- The legacy input set names files a slim project never has; a missing
    -- input must not be read as "changed".
    local dir = h.tmpdir()
    h.write(dir .. "/flake.nix", "{}")
    h.write(dir .. "/.flk/config.nix", "{}")
    h.write(dir .. "/.flk/.nix-profile-rust", "")
    h.write(dir .. "/.flk/.nix-profile-rust.stamp", "")

    h.set_mtime(dir .. "/flake.nix", 1000)
    h.set_mtime(dir .. "/.flk/config.nix", 1000)
    h.set_mtime(dir .. "/.flk/.nix-profile-rust.stamp", 2000)

    h.ok(cache.is_fresh(dir, "rust"))
  end,
}
