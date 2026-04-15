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

See `nixos/modules/home.nix` for the ghostty instance of this pattern (added
to make the GStreamer-backed audio bell stop aborting the process).
