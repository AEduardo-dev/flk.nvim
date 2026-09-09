local h = dofile("tests/helpers.lua")
local project = require("flk.project")

return {
  ["is_valid_profile accepts ordinary names"] = function()
    h.ok(project.is_valid_profile("rust"))
    h.ok(project.is_valid_profile("docs-rust"))
    h.ok(project.is_valid_profile("my_profile"))
    h.ok(project.is_valid_profile("py3"))
  end,

  ["is_valid_profile rejects path traversal"] = function()
    h.falsy(project.is_valid_profile("../etc/passwd"))
    h.falsy(project.is_valid_profile("a/b"))
    h.falsy(project.is_valid_profile(".."))
  end,

  ["is_valid_profile rejects shell metacharacters"] = function()
    h.falsy(project.is_valid_profile("rust; rm -rf /"))
    h.falsy(project.is_valid_profile("$(whoami)"))
    h.falsy(project.is_valid_profile("a b"))
  end,

  ["is_valid_profile rejects empty and non-strings"] = function()
    h.falsy(project.is_valid_profile(""))
    h.falsy(project.is_valid_profile(nil))
    h.falsy(project.is_valid_profile(42))
  end,

  ["find_root finds .flk in the starting directory"] = function()
    local dir = h.tmpdir()
    vim.fn.mkdir(dir .. "/.flk", "p")
    h.eq(project.find_root(dir), vim.fn.resolve(dir))
  end,

  ["find_root walks upward"] = function()
    local dir = h.tmpdir()
    vim.fn.mkdir(dir .. "/.flk", "p")
    vim.fn.mkdir(dir .. "/src/deep", "p")
    h.eq(project.find_root(dir .. "/src/deep"), vim.fn.resolve(dir))
  end,

  ["find_root returns nil outside a project"] = function()
    local dir = h.tmpdir()
    vim.fn.mkdir(dir .. "/src", "p")
    h.falsy(project.find_root(dir .. "/src"))
  end,

  ["find_root ignores a .flk file that is not a directory"] = function()
    local dir = h.tmpdir()
    h.write(dir .. "/.flk", "not a directory")
    h.falsy(project.find_root(dir))
  end,

  ["default_profile reads defaultProfile from config.nix"] = function()
    local dir = h.tmpdir()
    h.write(
      dir .. "/.flk/config.nix",
      '{\n  defaultProfile = "rust";\n  maxCombinations = 3;\n}\n'
    )
    h.eq(project.default_profile(dir), "rust")
  end,

  ["default_profile tolerates loose formatting"] = function()
    local dir = h.tmpdir()
    h.write(dir .. "/.flk/config.nix", '{ defaultProfile="docs-rust" ; }')
    h.eq(project.default_profile(dir), "docs-rust")
  end,

  ["default_profile returns nil when unset"] = function()
    local dir = h.tmpdir()
    h.write(dir .. "/.flk/config.nix", "{\n  maxCombinations = 3;\n}\n")
    h.falsy(project.default_profile(dir))
  end,

  ["default_profile returns nil when config.nix is absent"] = function()
    local dir = h.tmpdir()
    vim.fn.mkdir(dir .. "/.flk", "p")
    h.falsy(project.default_profile(dir))
  end,

  ["default_profile rejects an invalid name in config"] = function()
    local dir = h.tmpdir()
    h.write(dir .. "/.flk/config.nix", '{ defaultProfile = "../evil"; }')
    h.falsy(project.default_profile(dir))
  end,

  ["profile_files lists profile names without the extension"] = function()
    local dir = h.tmpdir()
    h.write(dir .. "/.flk/profiles/rust.nix", "{}")
    h.write(dir .. "/.flk/profiles/docs.nix", "{}")
    h.write(dir .. "/.flk/profiles/README.md", "ignored")
    local names = project.profile_files(dir)
    table.sort(names)
    h.same(names, { "docs", "rust" })
  end,

  ["profile_files returns an empty list when there is no profiles dir"] =
    function()
      local dir = h.tmpdir()
      vim.fn.mkdir(dir .. "/.flk", "p")
      h.same(project.profile_files(dir), {})
    end,
}
