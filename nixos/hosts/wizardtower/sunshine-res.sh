#!/usr/bin/env bash
# Changes niri output resolution for Moonlight streaming.
# Usage: sunshine-res.sh set <width> <height> [refresh]
#        sunshine-res.sh restore

OUTPUT="DP-1"
NIRI_SOCKET=$(find /run/user/1000 -name 'niri.*.sock' -print -quit 2>/dev/null)
export NIRI_SOCKET

case "$1" in
  set)
    WIDTH="${2:?width required}"
    HEIGHT="${3:?height required}"
    REFRESH="${4:-60}"
    niri msg output "$OUTPUT" custom-mode "${WIDTH}x${HEIGHT}@${REFRESH}"
    ;;
  restore)
    # Restore native mode (highest available)
    niri msg output "$OUTPUT" mode 3840x2160@143.999
    ;;
  *)
    echo "Usage: $0 {set <w> <h> [hz]|restore}" >&2
    exit 1
    ;;
esac
