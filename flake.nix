{
  description = "flk environments for Neovim";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
    forAllSystems = f:
      nixpkgs.lib.genAttrs systems (system:
        f nixpkgs.legacyPackages.${system});
  in {
    overlays.default = final: prev: {
      vimPlugins =
        prev.vimPlugins
        // {
          flk-nvim = final.callPackage ./package.nix {};
        };
    };

    packages = forAllSystems (pkgs: rec {
      flk-nvim = pkgs.callPackage ./package.nix {};
      default = flk-nvim;
    });

    checks = forAllSystems (pkgs: {
      tests = pkgs.runCommand "flk-nvim-tests" {
        nativeBuildInputs = [pkgs.neovim];
      } ''
        cp -r ${./.}/. .
        chmod -R +w .
        # The suite writes temp fixtures and needs a writable HOME.
        export HOME=$TMPDIR
        nvim --headless -l tests/run.lua
        touch $out
      '';
    });

    formatter = forAllSystems (pkgs: pkgs.alejandra);
  };
}
