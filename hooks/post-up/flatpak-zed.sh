#!/bin/sh
# Symlink Zed Flatpak config to the rcm-managed config
flatpak_zed="$HOME/.var/app/dev.zed.Zed/config/zed"
if [ -d "$flatpak_zed" ] && [ ! -L "$flatpak_zed" ]; then
  rm -rf "$flatpak_zed"
  ln -s "$HOME/.config/zed" "$flatpak_zed"
fi
