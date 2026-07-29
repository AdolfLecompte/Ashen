#!/usr/bin/env bash
# ── Ashen — wallpaper index for the picker ───────────────────────────────
#    Prints every wallpaper found, one per line.
#    Videos cannot be rendered by QML's Image, so a still frame is cached in
#    ~/.cache/ashen_wall_thumbs/<name>.jpg and only regenerated when missing.
# ─────────────────────────────────────────────────────────────────────────
set -uo pipefail

# The folder is settable from Settings > Appearance; the default stays put
# so the script keeps working when run by hand with no arguments.
DIR="${1:-$HOME/Pictures/Wallpapers}"
THUMBS="$HOME/.cache/ashen_wall_thumbs"
mkdir -p "$THUMBS"

find "$DIR" -maxdepth 2 -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \
       -o -iname '*.gif' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \) \
    | sort | while IFS= read -r f; do
        case "${f,,}" in
            *.mp4|*.webm|*.mkv|*.mov)
                thumb="$THUMBS/$(basename "$f").jpg"
                if [ ! -f "$thumb" ]; then
                    ffmpeg -y -loglevel error -ss 2 -i "$f" -frames:v 1 -vf scale=360:-1 "$thumb" 2>/dev/null \
                        || ffmpeg -y -loglevel error -i "$f" -frames:v 1 -vf scale=360:-1 "$thumb" 2>/dev/null
                fi
                ;;
        esac
        printf '%s\n' "$f"
    done
