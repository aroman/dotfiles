## Dotfiles management

This repo is managed by [rcm](https://github.com/thoughtbot/rcm). When adding new config files to be tracked:

1. Create the file at its final destination (e.g. `~/.config/ghostty/themes/MyTheme`)
2. Run `mkrc <path>` to move it into this dotfiles repo and symlink it back

Do NOT create files directly in this repo and run `rcup` — use `mkrc` instead.

## NixOS: wrapping GUI apps with `symlinkJoin`

When using `symlinkJoin` + `makeWrapper` to add env vars to a nixpkgs GUI app
without rebuilding it, check whether the package's `.desktop` file hardcodes
an absolute `/nix/store/<hash>/bin/...` path in `Exec=` / `TryExec=`. Many
do (ghostty does). If so, the wrapper binary on `PATH` is bypassed by every
XDG launcher (vicinae, xdg-terminal-exec, niri, fuzzel) because they invoke
the absolute path from the desktop file literally — they don't do a `PATH`
lookup when `Exec=` is absolute.

The fix is to `rm` the symlinked `.desktop` file in the wrapper derivation's
`postBuild` and write a rewritten copy:

```nix
postBuild = ''
  rm $out/bin/foo
  makeWrapper ${pkg}/bin/foo $out/bin/foo --prefix SOME_VAR : "..."

  rm $out/share/applications/com.example.foo.desktop
  substitute \
    ${pkg}/share/applications/com.example.foo.desktop \
    $out/share/applications/com.example.foo.desktop \
    --replace-fail "${pkg}/bin/foo" "$out/bin/foo"
'';
```

## NixOS: desktop update validation

- Use `bake` (Fish) or `nh os switch --show-activation-logs` for normal
  deployments. NH activates first and updates the boot default only after
  successful activation; `nixos-rebuild switch` updates boot entries first.
- Keep the desktop graphics compatibility check in `system.checks`. Cached
  GUI apps use their own libc and must be able to load the selected system
  EGL/GLX/Vulkan drivers; a successful package build alone does not prove this.
- Do not manually symlink Home Manager-owned user units into `~/.config/systemd`.
  Declare them in Home Manager and activate the configuration.
- Treat a failed activation as a failed deployment. Check both system and user
  failed units and launch Ghostty and Vicinae after desktop updates. Do not
  report success or leave a failed generation as the boot default; restore the
  previous working generation if the failure cannot be resolved immediately.
