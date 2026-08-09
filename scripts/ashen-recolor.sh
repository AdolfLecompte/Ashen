#!/usr/bin/env bash
# ── Ashen — recolour ─────────────────────────────────────────────────────
# Re-run matugen from the wallpaper currently on screen, using the saved
# dynamic style. The theme panel calls this when the user picks Dynamic or a
# new dynamic style, so the palette updates without re-selecting the wallpaper.
#
# Acts only in dynamic mode. gif/video have no still matugen can sample, so it
# feeds the frame ashen-wallpaper.sh cached instead of the wallpaper itself.
# ─────────────────────────────────────────────────────────────────────────
set -uo pipefail

# Sibling scripts are resolved next to this one, so the set works from the
# checkout and from /usr/bin alike.
HERE="$(dirname "$(readlink -f "$0")")"

CACHE="$HOME/.cache"
[ "$(cat "$CACHE/ashen_scheme_mode.txt" 2>/dev/null)" = "dynamic" ] || exit 0

WALL="$(cat "$CACHE/ashen_wallpaper.txt" 2>/dev/null)"
[ -n "$WALL" ] || exit 0

src="$WALL"
case "${WALL,,}" in
    *.png|*.jpg|*.jpeg|*.webp) : ;;
    *) src="$CACHE/ashen_wall_frame.png" ;;
esac
[ -f "$src" ] || exit 0

type="$(cat "$CACHE/ashen_dynamic_type.txt" 2>/dev/null || echo scheme-tonal-spot)"
# Light or dark, chosen in Settings > Appearance. Dark unless told otherwise.
mode="$(cat "$HOME/.cache/ashen_theme_mode.txt" 2>/dev/null)"
[ "$mode" = "light" ] || mode="dark"
matugen image "$src" --mode "$mode" --source-color-index 0 --type "$type"
# Order matters: the accent has to be resolved and substituted into what matugen
# just wrote before anything reads those files, the border included.
"$HERE/ashen-accent.sh"
exec "$HERE/ashen-apply-border.sh"
