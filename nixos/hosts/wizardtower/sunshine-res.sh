#!/usr/bin/env bash
# Adjusts niri output for Moonlight streaming sessions.
# On connect: set custom mode matching Mac display (3024x1964).
# On disconnect: restore native 4K mode.

OUTPUT="DP-1"
NIRI_SOCKET=$(find /run/user/1000 -maxdepth 1 -name 'niri.*.sock' -print -quit 2>/dev/null)
export NIRI_SOCKET

case "$1" in
  connect)
    niri msg output "$OUTPUT" custom-mode 3024x1964@120
    ;;
  disconnect)
    niri msg output "$OUTPUT" mode 3840x2160@143.999
    ;;
  *)
    echo "Usage: $0 {connect|disconnect}" >&2
    exit 1
    ;;
esac
