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
}
