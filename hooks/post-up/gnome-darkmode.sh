#!/bin/sh
# Run gsettings on the host when inside a container (distrobox/toolbox)
if [ -f /run/.containerenv ] && command -v flatpak-spawn >/dev/null 2>&1; then
  gsettings() { flatpak-spawn --host gsettings "$@"; }
fi

if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface color-scheme prefer-dark
  gsettings set org.gnome.desktop.interface accent-color blue
fi
