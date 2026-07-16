#!/usr/bin/env bash
# ── Ashen — wallpaper setter ─────────────────────────────────────────────
#    Handles both kinds of wallpaper behind a single entry point:
#      · still images + gif  ->  awww (its daemon animates gifs on its own)
#      · video (mp4/webm/mkv) ->  mpvpaper
#    The two cannot coexist: both draw on the background layer, so whichever
#    one is not in use gets killed first.
#
#    Dynamic palette: matugen only accepts stills, so for video/gif we hand it
#    a frame pulled with ffmpeg instead of the wallpaper itself.
# ─────────────────────────────────────────────────────────────────────────
set -uo pipefail

WALL="${1:?usage: ashen-wallpaper.sh <path>}"
[ -f "$WALL" ] || { echo "ashen-wallpaper: no such file: $WALL" >&2; exit 1; }

CACHE="$HOME/.cache"
FRAME="$CACHE/ashen_wall_frame.png"
STATE="$CACHE/ashen_wallpaper.txt"
OPT="$CACHE/ashen_wall_optimized"

lower="${WALL,,}"

is_video() {
    case "$lower" in
        *.mp4|*.webm|*.mkv|*.mov) return 0 ;;
        *) return 1 ;;
    esac
}

# matugen chokes on video and animated gif: give it a still frame instead
needs_frame() {
    case "$lower" in
        *.png|*.jpg|*.jpeg|*.webp) return 1 ;;
        *) return 0 ;;
    esac
}

# Sites like moewalls ship 4K60 clips. On a 1080p panel that decodes four times
# the pixels you can actually see and drops frames non-stop, so anything larger
# than the biggest monitor gets downscaled once and cached. The original file is
# never touched.
optimized_video() {
    local src="$1"
    local cached="$OPT/$(basename "${src%.*}")-opt.mp4"

    # Reuse the cached copy unless the source changed after it was made
    if [ -f "$cached" ] && [ "$cached" -nt "$src" ]; then
        printf '%s' "$cached"
        return
    fi

    local sw sh
    read -r sw sh <<< "$(ffprobe -v error -select_streams v:0 \
        -show_entries stream=width,height -of csv=p=0 "$src" 2>/dev/null | tr ',' ' ')"
    [ -n "${sw:-}" ] && [ -n "${sh:-}" ] || { printf '%s' "$src"; return; }

    # Largest monitor currently connected
    local mw mh
    read -r mw mh <<< "$(hyprctl monitors -j 2>/dev/null | python3 -c '
import json, sys
try:
    ms = json.load(sys.stdin)
    print(max(m["width"] for m in ms), max(m["height"] for m in ms))
except Exception:
    print(1920, 1080)
' 2>/dev/null)"
    mw="${mw:-1920}"; mh="${mh:-1080}"

    # Already fits the screen: play it as-is
    if [ "$sw" -le "$mw" ] && [ "$sh" -le "$mh" ]; then
        printf '%s' "$src"
        return
    fi

    mkdir -p "$OPT"
    notify-send -a Ashen -i video-x-generic "Wallpaper" \
        "Optimizing ${sw}x${sh} video to ${mw}x${mh}…" 2>/dev/null

    if ffmpeg -y -loglevel error -i "$src" \
        -vf "scale=${mw}:${mh}:flags=lanczos,fps=30" \
        -c:v libx264 -preset medium -crf 23 -pix_fmt yuv420p -an \
        -movflags +faststart "$cached" 2>/dev/null
    then
        notify-send -a Ashen -i video-x-generic "Wallpaper" "Video optimized" 2>/dev/null
        printf '%s' "$cached"
    else
        # Transcode failed: fall back to the original rather than showing nothing
        rm -f "$cached"
        printf '%s' "$src"
    fi
}

# Pull a still frame from a video/gif wallpaper. Two consumers need it:
# matugen (accepts stills only) and the lock screen, which can't draw a moving
# background layer. Runs regardless of colour mode, so the lock frame stays in
# sync with the wallpaper even when the dynamic palette is off.
ensure_frame() {
    needs_frame || return 0
    # 2s in, so we skip fade-ins that would sample as pure black
    ffmpeg -y -loglevel error -ss 2 -i "$WALL" -frames:v 1 "$FRAME" 2>/dev/null \
        || ffmpeg -y -loglevel error -i "$WALL" -frames:v 1 "$FRAME" 2>/dev/null
}

apply_colors() {
    [ "$(cat "$CACHE/ashen_scheme_mode.txt" 2>/dev/null)" = "dynamic" ] || return 0

    # ensure_frame already pulled the still for video/gif
    local src="$WALL"
    needs_frame && src="$FRAME"

    local type
    type="$(cat "$CACHE/ashen_dynamic_type.txt" 2>/dev/null || echo scheme-tonal-spot)"
    matugen image "$src" --mode dark --source-color-index 0 --type "$type"
}

if is_video; then
    command -v mpvpaper >/dev/null || {
        echo "ashen-wallpaper: mpvpaper not installed (paru -S mpvpaper)" >&2
        exit 1
    }

    PLAY="$(optimized_video "$WALL")"

    pkill -x mpvpaper 2>/dev/null
    awww kill 2>/dev/null
    # mpvpaper only supports the libmpv vo, so no vo= here.
    # panscan fills the screen instead of letterboxing an odd aspect ratio.
    setsid mpvpaper -o "no-audio loop hwdec=auto panscan=1.0" ALL "$PLAY" >/dev/null 2>&1 < /dev/null &
else
    pkill -x mpvpaper 2>/dev/null
    pgrep -x awww-daemon >/dev/null || { setsid awww-daemon >/dev/null 2>&1 < /dev/null & sleep 0.4; }
    awww img "$WALL" --transition-type random --transition-duration 0.6 --transition-fps 60
fi

ensure_frame
apply_colors
printf '%s' "$WALL" > "$STATE"
