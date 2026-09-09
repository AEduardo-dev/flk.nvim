{
  lib,
  vimUtils,
  nix,
}:
vimUtils.buildVimPlugin {
  pname = "flk-nvim";
  version = "0.1.0";

  src = builtins.path {
    path = ./.;
    name = "flk-nvim-source";
    # Only what Neovim needs at runtime; tests and design docs are not part
    # of the plugin.
    filter = path: type: let
      base = baseNameOf path;
    in
      !(builtins.elem base [
        "tests"
        "docs"
        "flake.nix"
        "flake.lock"
        "package.nix"
        "gen-docs"
        ".git"
      ]);
  };

  # `nix` is resolved from the user's PATH at runtime rather than baked in,
  # so the CLI always matches the running daemon. Declared here only so the
  # dependency is discoverable.
  passthru.runtimeDependency = nix;

  meta = {
    description = "flk environments for Neovim";
    homepage = "https://gitlab.com/pixel-racks/flk-nvim";
    license = lib.licenses.mpl20;
    maintainers = [];
  };
}
