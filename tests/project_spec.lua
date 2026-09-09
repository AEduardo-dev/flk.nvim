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
}
