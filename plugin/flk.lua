vim.api.nvim_create_user_command("Flk", function(ctx)
  require("flk").activate(ctx.args ~= "" and ctx.args or nil)
end, {
  nargs = "?",
  desc = "Enter an flk profile environment (no argument: default, or refresh)",
  complete = function(lead)
    return require("flk").complete(lead)
  end,
})

vim.api.nvim_create_user_command("FlkOff", function()
  require("flk").deactivate()
end, {
  nargs = 0,
  desc = "Restore the environment from before the first flk activation",
})
