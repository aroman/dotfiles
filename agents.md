## Dotfiles management

This repo is managed by [rcm](https://github.com/thoughtbot/rcm). When adding new config files to be tracked:

1. Create the file at its final destination (e.g. `~/.config/ghostty/themes/MyTheme`)
2. Run `mkrc <path>` to move it into this dotfiles repo and symlink it back

Do NOT create files directly in this repo and run `rcup` — use `mkrc` instead.
