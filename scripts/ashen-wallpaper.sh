#!/usr/bin/env bash
# ── Ashen — wallpaper setter ──────────  by Adolf — github.com/AdolfLecompte ──
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

# Sibling scripts are resolved next to this one, so the set works from the
# checkout and from /usr/bin alike.
HERE="$(dirname "$(readlink -f "$0")")"

WALL="${1:?usage: ashen-wallpaper.sh <path>}"
[ -f "$WALL" ] || { echo "ashen-wallpaper: no such file: $WALL" >&2; exit 1; }

CACHE="$HOME/.cache"
FRAME="$CACHE/ashen_wall_frame.png"
FRAMES="$CACHE/ashen_frames"
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

# Deterministic per-wallpaper frame path. basename keeps it legible; a cksum of
# the full path disambiguates same-named files living in different folders.
frame_for() {
    local src="$1"
    printf '%s/%s-%s.png' "$FRAMES" \
        "$(basename "${src%.*}")" \
        "$(printf '%s' "$src" | cksum | cut -d' ' -f1)"
}

# Pull a still frame from a video/gif wallpaper. Three consumers need it: the
# video bridge below, matugen (accepts stills only) and the lock screen, which
# can't draw a moving background layer. Runs regardless of colour mode, so the
# lock frame stays in sync with the wallpaper even when the dynamic palette is
# off.
#
# The extracted still is cached permanently, keyed to the wallpaper, so a
# re-switch to a clip used before skips ffmpeg entirely and the bridge can paint
# with no decode latency. The shared ashen_wall_frame.png stays the single path
# lock+matugen read: we just refresh it from the persistent cache each switch.
ensure_frame() {
    needs_frame || return 0
    local persist
    persist="$(frame_for "$WALL")"

    # Regenerate only when missing or older than the source file
    if [ ! -f "$persist" ] || [ "$WALL" -nt "$persist" ]; then
        mkdir -p "$FRAMES"
        # 2s in, so we skip fade-ins that would sample as pure black
        ffmpeg -y -loglevel error -ss 2 -i "$WALL" -frames:v 1 "$persist" 2>/dev/null \
            || ffmpeg -y -loglevel error -i "$WALL" -frames:v 1 "$persist" 2>/dev/null
    fi

    [ -f "$persist" ] && cp -f "$persist" "$FRAME"
}

# Every visible transition awww ships except the plain fade -- one is rolled at
# random per switch. awww's own 'random' can't be filtered, so we curate here.
# Edit this list to add/drop effects.
TRANSITIONS=(left right top bottom wipe wave grow center any outer)

# Paint a still on the awww layer: start the daemon if needed, then hand awww a
# random transition from the pool above.
paint() {
    pgrep -x awww-daemon >/dev/null || { setsid awww-daemon >/dev/null 2>&1 < /dev/null & sleep 0.4; }
    local t="${TRANSITIONS[RANDOM % ${#TRANSITIONS[@]}]}"
    awww img "$1" --transition-type "$t" --transition-duration 0.6 --transition-fps 60 2>/dev/null
}

apply_colors() {
    [ "$(cat "$CACHE/ashen_scheme_mode.txt" 2>/dev/null)" = "dynamic" ] || return 0

    # ensure_frame already pulled the still for video/gif
    local src="$WALL"
    needs_frame && src="$FRAME"

    local type
    type="$(cat "$CACHE/ashen_dynamic_type.txt" 2>/dev/null || echo scheme-tonal-spot)"
    # Light or dark, chosen in Settings > Appearance. Dark unless told otherwise.
    mode="$(cat "$HOME/.cache/ashen_theme_mode.txt" 2>/dev/null)"
    [ "$mode" = "light" ] || mode="dark"
    matugen image "$src" --mode "$mode" --source-color-index 0 --type "$type"
    # Order matters: the accent has to be resolved and substituted into what
    # matugen just wrote before anything reads those files, the border included.
    "$HERE/ashen-accent.sh"
    "$HERE/ashen-apply-border.sh"
}

# Pull the target still up-front: the video branch paints it as a bridge, and
# both matugen and the lock screen need it regardless of colour mode.
ensure_frame

if is_video; then
    command -v mpvpaper >/dev/null || {
        echo "ashen-wallpaper: mpvpaper not installed (paru -S mpvpaper)" >&2
        exit 1
    }

    PLAY="$(optimized_video "$WALL")"

    # Bridge the gap while mpvpaper spins up libmpv (~1s): paint the still frame
    # first -- over whatever is currently showing -- then start the video on top
    # of it, so the empty Hyprland background never flashes through. The frame is
    # a still of this very clip, so the hand-off from still to motion is seamless.
    [ -f "$FRAME" ] && paint "$FRAME"
    pkill -x mpvpaper 2>/dev/null
    # mpvpaper only supports the libmpv vo, so no vo= here.
    # panscan fills the screen instead of letterboxing an odd aspect ratio.
    setsid mpvpaper -o "no-audio loop hwdec=auto panscan=1.0" ALL "$PLAY" >/dev/null 2>&1 < /dev/null &
    # Leave the awww daemon alive holding the bridge frame under the opaque
    # mpvpaper surface -- it costs nothing (a static layer the compositor skips)
    # and it means a later switch to a still can paint on an already-running
    # daemon and reveal it without a restart gap. See the still branch below.
else
    # Paint the new still on the awww layer *before* removing the video. mpvpaper
    # sits above awww, so the swap stays hidden until awww has committed its
    # frame underneath; only then do we kill mpvpaper, revealing the still with
    # no window where Hyprland's empty background could flash through. The short
    # settle gives awww time to buffer its first frame before the reveal.
    paint "$WALL"
    sleep 0.3
    pkill -x mpvpaper 2>/dev/null
fi

apply_colors
printf '%s' "$WALL" > "$STATE"
