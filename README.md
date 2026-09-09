# flk-nvim

[flk](https://gitlab.com/pixel-racks/flk) environments for Neovim.

Enter an flk profile's development environment from inside a running Neovim
session — packages, environment variables, and everything the profile's
shellHook exports.

```vim
:Flk            " enter the default profile, or refresh the active one
:Flk docs       " switch to the docs profile
:Flk docs-rust  " a generated profile combination
:FlkOff         " restore the environment from before the first activation
```

```lua
require("flk").activate()        -- default profile, or refresh
require("flk").activate("docs")  -- switch
require("flk").deactivate()
require("flk").status()          -- active profile name, or nil
require("flk").profiles()        -- known profile names
```

## How it works

The environment is captured by running `nix develop … -c env -0` and diffing
the result against Neovim's own environment. Because nix executes the real
shellHook in a real shell, variables that flk emits from the hook — anything
added with `flk env add`, plus per-profile hook exports — arrive intact,
which parsing `nix print-dev-env --json` would miss.

nix is spawned from the full pre-activation baseline environment with
`clear_env` set, not merely with `PATH` reset, so switching profiles never
leaks a previously active profile's variables into the next one.

flk's profile cache (`.flk/.nix-profile-<name>`) is shared with the flk CLI,
so a profile warmed in your shell activates instantly here.

## Requirements

- Neovim 0.10+
- nix with flakes enabled
- An flk project (a `.flk/` directory somewhere above the current directory)

The `flk` binary itself is not required: the plugin reads `.flk/` and drives
nix directly, which matters because Neovim usually starts outside the flk
shell.

## Installation

### Nix (flake)

This repository is a flake. It exposes `packages.<system>.flk-nvim` and an
overlay that adds `pkgs.vimPlugins.flk-nvim`.

```nix
# flake.nix
inputs.flk-nvim.url = "gitlab:pixel-racks/flk-nvim";
```

With the overlay applied, config modules need no flake plumbing:

```nix
pkgs = import nixpkgs {
  inherit system;
  overlays = [flk-nvim.overlays.default];
};
```

### nixvim

```nix
{pkgs, ...}: {
  extraPlugins = [pkgs.vimPlugins.flk-nvim];

  keymaps = [
    {
      key = "<leader>na";
      action = "<cmd>Flk<cr>";
      options.desc = "flk: activate default profile (or refresh)";
    }
    {
      # No <cr>: leaves the command line open so <Tab> completes profiles.
      key = "<leader>np";
      action = ":Flk ";
      options.desc = "flk: pick a profile";
    }
    {
      key = "<leader>nd";
      action = "<cmd>FlkOff<cr>";
      options.desc = "flk: restore the pre-activation environment";
    }
  ];
}
```

Do not add `nix` to `extraPackages`. The plugin resolves `nix` from `PATH` at
runtime so the CLI matches your running daemon; bundling a second one from
nixpkgs invites client/daemon version skew. If Neovim is launched from a GUI
with a narrower `PATH` than your shell, `:Flk` reports that plainly rather
than failing obscurely.

### Other plugin managers

Point them at this repository; there is no build step and no setup call.

## Configuration

Variables never imported from the dev shell:

```lua
require("flk").ignored_variables["SHELL"] = false
```

`SHELL` is ignored by default because `nix develop` points it at nixpkgs'
non-interactive bash, which breaks `:terminal`.

See [flk.txt](doc/flk.txt) for the full reference.
