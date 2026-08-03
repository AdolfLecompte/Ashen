#!/usr/bin/env bash
# ── Ashen — restores the last wallpaper on login ─────────────────────────
#    awww-daemon does not remember anything across reboots and mpvpaper is
#    not even running yet, so Hyprland's autostart calls this instead.
# ─────────────────────────────────────────────────────────────────────────
set -uo pipefail

# Sibling scripts are resolved next to this one, so the set works from the
# checkout and from /usr/bin alike.
HERE="$(dirname "$(readlink -f "$0")")"

WALL="$(cat "$HOME/.cache/ashen_wallpaper.txt" 2>/dev/null)"
[ -n "${WALL:-}" ] && [ -f "$WALL" ] || exit 0

exec "$HERE/ashen-wallpaper.sh" "$WALL"
