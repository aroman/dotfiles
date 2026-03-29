#!/usr/bin/env bash
# Adjusts niri output scale for Moonlight streaming sessions.
# On connect: scale up so the desktop matches the client's logical size.
# On disconnect: restore the native scale.

OUTPUT="DP-1"
NIRI_SOCKET=$(find /run/user/1000 -name 'niri.*.sock' -print -quit 2>/dev/null)
export NIRI_SOCKET

case "$1" in
  connect)
    # Scale 2.0 → 1920x1080 logical on 4K, close to Mac's ~1512x982
    niri msg output "$OUTPUT" scale 2.0
    ;;
  disconnect)
    niri msg output "$OUTPUT" scale 1.5
    ;;
  *)
    echo "Usage: $0 {connect|disconnect}" >&2
    exit 1
    ;;
esac
