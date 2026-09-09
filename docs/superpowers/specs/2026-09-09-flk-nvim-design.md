# flk-nvim — flk-only Neovim environment activation

**Date:** 2026-09-09
**Status:** Approved

## Summary

Rewrite `nix-develop.nvim` as `flk-nvim`: a Neovim plugin that enters an
[flk](https://gitlab.com/pixel-racks/flk)-managed development environment from
inside a running Neovim session. The `nix shell`, `devenv`, and `riff` backends
are removed entirely. flk is the only supported backend.

## Motivation

`flk` is a `nix develop` wrapper (`flk/src/commands/activate.rs:63`), so the
existing plugin already half-works: `:NixDevelop .#rust --impure` succeeds
against an flk project. Three things make it the wrong tool anyway:

1. **`flk env` variables are silently dropped.** flk emits `envVars` and profile
   hooks *inside* the shellHook, not as JSON exports. Verified against the flk
   repo: `RUST_BACKTRACE`, `LANG`, `LC_ALL`, and `FLK_FLAKE_REF` are absent from
   the `print-dev-env` `variables` map and present only as `export` lines in
   `shellHook`. The plugin pipes the shellHook into a throwaway `bash`
   (`lua/nix-develop/init.lua:146-154`), so those exports die with that
   subprocess. Packages arrive; the environment does not.
2. **No profile awareness.** flk's default profile, its generated profile
   combinations, and its profile cache are all invisible to the plugin.
3. **Re-activation stacks `PATH`** (`init.lua:96-105`), so switching profiles
   shadows the old profile rather than replacing it.

## Approach

Let nix run the whole environment and report the result, rather than
reconstructing it in Lua:

```
nix develop --impure .#rust -c env -0
```

Verified against the flk repo: exit 0, 247 variables, including every variable
the JSON path loses. nix executes the real shellHook in the real shell, so no
part of flk's hook semantics is reimplemented in the plugin and none of it can
drift.

## Scope — removals

Deleted, not adapted:

- `lua/nix-develop/init.lua`, `plugin/nix-develop.lua`, `doc/nix-develop.txt`
- The `nix_develop`, `nix_shell`, `devenv_shell`, `riff_shell` functions
- The `:NixDevelop`, `:NixShell`, `:DevenvShell`, `:RiffShell` commands
- The `separated_variables` mechanism (`init.lua:58-61`) — it exists to splice
  `print-dev-env` PATH fragments onto the inherited PATH. `nix develop -c env`
  yields the final PATH already, so values are applied verbatim.

`ignored_variables` is kept. It is load-bearing: `nix develop` exports `SHELL`
pointing at nixpkgs' non-interactive bash, which breaks `:terminal`. flk warns
about this explicitly (`flk/src/commands/hook.rs:39-41`).

## Module layout

| File | Responsibility |
|---|---|
| `lua/flk/project.lua` | Find project root (walk up for `.flk/`), read `defaultProfile` from `.flk/config.nix`, validate profile names |
| `lua/flk/cache.lua` | Profile-cache freshness — mirrors `flk/src/commands/profile_cache.rs` |
| `lua/flk/env.lua` | Spawn nix, parse `env -0`, diff, apply, snapshot, restore |
| `lua/flk/init.lua` | Public API: `activate`, `deactivate`, `status`, `profiles`; `ignored_variables` config |
| `plugin/flk.lua` | `:Flk` / `:FlkOff` and completion |

## Command surface

```vim
:Flk            " enter the default profile, or refresh if already active
:Flk docs       " switch to the docs profile
:Flk docs-rust  " a generated profile combination
:FlkOff         " restore the pre-activation environment
```

```lua
require("flk").activate()        -- default / refresh
require("flk").activate("docs")  -- switch
require("flk").deactivate()
require("flk").status()          -- active profile, or nil
require("flk").profiles()        -- completion candidates
```

## Activation flow

Profile resolution, in order:

1. Explicit argument
2. `FLK_FLAKE_REF` when already active (the refresh case)
3. `defaultProfile` from `.flk/config.nix`

The name is validated against `^[a-zA-Z0-9_-]+$` — matching flk's
`_flk_valid_profile` — before it reaches a shell.

Then, mirroring `flk/src/commands/hook.rs:79-81`: set `FLK_ORIG_PATH` to the
current PATH if unset, and spawn nix with `PATH` forced to that baseline. This
is what makes `:Flk rust` -> `:Flk docs` drop rust's store paths instead of
shadowing them.

- **Cache fresh:** `nix develop <cache-path> -c env -0`
- **Cache stale:** `nix develop .#<profile> --impure --profile <cache-path> -c env -0`, then touch the stamp

Both run asynchronously via `vim.system()`. A cold profile takes minutes;
blocking Neovim on that is unacceptable. Notify on start, and on success or
failure.

## Applying and restoring the environment

Child `env -0` output is split on NUL into name/value pairs and diffed against
`vim.fn.environ()`. For each variable that is new or changed and not in
`ignored_variables`, record the prior value (or the absence of one) into a
session table, then set it. `:FlkOff` replays that table backwards — restoring
old values, unsetting variables that did not previously exist. This is exact,
not a PATH-only approximation.

Re-activating while active diffs against the *original* snapshot rather than the
currently-active environment, so repeated profile switches cannot accumulate
cruft.

The shellHook's banner output is discarded, since stdout carries the env dump.
`status` reports the active profile instead.

## Profile discovery

Completion candidates come from:

```
nix eval --impure --json .#devShells.<system> --apply builtins.attrNames
```

On the flk repo this returns `["default","docs","docs-rust","rust"]`, including
flk's generated combinations — which listing `.flk/profiles/` would miss.
Evaluated once per session and cached in memory, since completion must feel
instant.

## Profile cache

Freshness mirrors `flk/src/commands/profile_cache.rs`: the cache at
`.flk/.nix-profile-<p>` is fresh when it and its `.stamp` both exist and no
watched input is newer than the stamp. Watched inputs for the slim layout
(`.flk/config.nix` present) are `flake.nix`, `flake.lock`, `.flk/config.nix`,
`.flk/pins.nix`, plus `.flk/profiles/<p>.nix`; the legacy layout watches
`flake.nix`, `flake.lock`, `.flk/default.nix`, `.flk/pins.nix`,
`.flk/overlays.nix`, plus the profile file.

Sharing the cache with the flk CLI means a profile warmed in the shell activates
instantly in Neovim, and vice versa.

## Errors and edge cases

- No `.flk/` found walking up -> clear "not an flk project" message, no nix invocation
- Nix exits non-zero -> surface the last lines of stderr, not a bare exit code (the
  current `check()` at `init.lua:63-89` reports only the code, which is not enough
  to debug a broken profile)
- Invalid profile name -> rejected before spawning
- Empty or malformed `env -0` output -> treated as failure; environment left untouched
- `:FlkOff` with nothing active -> no-op with a notification

## Testing

Unit tests under headless Neovim, covering the logic that needs no nix:

- `env -0` parsing, including values containing `=` and newlines
- Diff/apply/restore round trip, including the re-activation case
- Cache freshness against fixture mtimes, both layouts
- Profile-name validation, including rejection of path separators
- `defaultProfile` extraction from `.flk/config.nix`

Cache freshness and env restore carry the real risk and get the most cases. One
optional integration test, skipped unless a real flk project is present.

## Docs

`gen-docs` is repointed at `lua/flk/init.lua` and emits `doc/flk.txt`.
`doc/nix-develop.txt` is removed. README is rewritten around the flk workflow.

## Assumptions

- **Neovim 0.10+**, for `vim.system()`.
- `defaultProfile` is read from `.flk/config.nix` with a Lua pattern rather than
  a nix eval. The file is flk-generated and simple (`defaultProfile = "rust";`).
  A hand-edited config with unusual formatting would defeat the pattern; the
  fallback is `nix eval --raw .#defaultShell.<system>`, at the cost of a slow path.

## Out of scope

- **nixvim packaging.** The user consumes this plugin through a nixvim setup.
  That is a separate piece of work, to be designed after the implementation
  lands and can be exercised.
- Custom `flk cmd` entries materialized as shell *functions* rather than
  `writeShellScriptBin` packages cannot cross into Neovim. Nothing can fix this;
  Neovim is not a shell. Commands on `PATH` work normally.
- direnv integration. flk's hook prefers `direnv reload` when an `.envrc` is
  present; the plugin always drives nix directly.
