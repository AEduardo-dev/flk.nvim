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

## Configuration

Variables never imported from the dev shell:

```lua
require("flk").ignored_variables["SHELL"] = false
```

`SHELL` is ignored by default because `nix develop` points it at nixpkgs'
non-interactive bash, which breaks `:terminal`.

See [flk.txt](doc/flk.txt) for the full reference.
