#!/usr/bin/env bash
# ── Ashen — folders in the accent ──  by Adolf — github.com/AdolfLecompte ──
#    papirus-folders can only pick from the colours Papirus ships. This builds a
#    theme that inherits Papirus and overrides ONLY the folder icons, painted
#    with the accent the rest of the rice is using -- so the file manager
#    follows the wallpaper like everything else.
#
#    Cheap by design: it copies the folder icons that are actually in use (the
#    plain `folder*.svg` names, which Papirus keeps as symlinks into whichever
#    colour variant is active) and rewrites two hex values in each. Everything
#    else falls through to Papirus by inheritance.
# ─────────────────────────────────────────────────────────────────────────
set -uo pipefail

# The folders ARE the accent folders -- there is no switch any more, so the
# default is to build them and wear them. `--off` is still here as the way back
# to plain Papirus for anyone who wants it.
APPLY=1
for a in "$@"; do
    case "$a" in
        --apply) APPLY=1 ;;
        --off)   APPLY=-1 ;;
        -h|--help)
            echo "usage: ashen-folders.sh [--apply|--off]"
            echo "  --apply  rebuild and wear the theme"
            echo "  --off    go back to plain Papirus"
            exit 0 ;;
        *) echo "ashen-folders.sh: unknown option: $a" >&2; exit 2 ;;
    esac
done

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}"
DEST="${XDG_DATA_HOME:-$HOME/.local/share}/icons/Ashen-Papirus"
SIZES="16x16 22x22 24x24 32x32 48x48 64x64 96x96"

say()  { printf '\033[1;35m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }

# ── What to paint with ────────────────────────────────────────────────────
# The accent is decided once, by ashen-accent.sh, and everyone reads its answer.
accent="$(cat "$CACHE/ashen_accent.txt" 2>/dev/null)"
accent="${accent#\#}"
case "$accent" in
    [0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]) ;;
    *) warn "no usable accent in $CACHE/ashen_accent.txt — nothing to paint with"; exit 0 ;;
esac

mode="$(cat "$CACHE/ashen_theme_mode.txt" 2>/dev/null)"
[ "$mode" = "light" ] || mode="dark"
if [ "$mode" = "light" ]; then
    SRC=/usr/share/icons/Papirus
    INHERITS="Papirus,hicolor"
else
    SRC=/usr/share/icons/Papirus-Dark
    INHERITS="Papirus-Dark,Papirus,hicolor"
fi
[ -d "$SRC" ] || { warn "$SRC is not installed — install papirus-icon-theme"; exit 0; }

# A folder is drawn in four tones: the body in front, the flap behind it, the
# sheet of paper inside, and the little emblem stamped on the body. The accent
# takes the body; the other three are decided by how light that accent is,
# because a light mode accent is a DARK colour and the emblem Papirus ships is
# darker still -- dark on dark is a folder with a smudge on it.
#
# Same relative luminance as Colors.lum in services/Colors.qml.
tone() {
    awk -v hex="$1" -v f="$2" 'BEGIN {
        r = strtonum("0x" substr(hex,1,2)); g = strtonum("0x" substr(hex,3,2)); b = strtonum("0x" substr(hex,5,2))
        if (f < 0) { r = r + (255 - r) * -f; g = g + (255 - g) * -f; b = b + (255 - b) * -f }
        else       { r = r * (1 - f); g = g * (1 - f); b = b * (1 - f) }
        printf "%02x%02x%02x", int(r), int(g), int(b)
    }'
}
is_light() {
    awk -v hex="$1" 'function chan(v,  c) { c = v / 255; return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ^ 2.4 }
        BEGIN {
            l = 0.2126 * chan(strtonum("0x" substr(hex,1,2))) \
              + 0.7152 * chan(strtonum("0x" substr(hex,3,2))) \
              + 0.0722 * chan(strtonum("0x" substr(hex,5,2)))
            print (l > 0.35) ? "yes" : "no"
        }'
}

front="$accent"
if [ "$(is_light "$accent")" = "yes" ]; then
    back="$(tone "$accent" 0.28)"      # fold: the accent walked towards black
    sheet="eceff4"                     # paper stays paper
    stamp="3b4253"                     # Papirus' own dark emblem reads fine
else
    back="$(tone "$accent" -0.22)"     # fold: walked towards white instead
    sheet="$(tone "$accent" -0.72)"
    stamp="$(tone "$accent" -0.82)"    # a light emblem, or it disappears
fi

# ── What to repaint ───────────────────────────────────────────────────────
# The two blues to swap are read from the source theme itself rather than
# hardcoded: papirus-folders may have pointed the plain names at any of its
# colour variants, and each variant has its own pair.
probe="$SRC/64x64/places/folder.svg"
[ -f "$probe" ] || { warn "no folder.svg in $SRC — is this a Papirus install?"; exit 0; }
src_back="$(sed -n 's/.*style="fill:#\([0-9a-fA-F]\{6\}\)".*d="M 4,4.*/\1/p' "$probe" | head -1)"
src_front="$(grep -oE 'fill:#[0-9a-fA-F]{6}" width="56"' "$probe" | head -1 | sed 's/fill:#//;s/".*//')"
# Fall back to the pair Papirus has shipped since it went Nordic.
[ -n "$src_back" ]  || src_back="5e81ac"
[ -n "$src_front" ] || src_front="81a1c1"
# The sheet and the emblem are the same in every variant Papirus ships.
src_sheet="eceff4"
src_stamp="3b4253"

say "Folders: #$src_front/#$src_back -> #$front/#$back ($mode)"

# The old icons go, the DIRECTORY stays: GTK watches the theme's folders and
# reloads when they change, and a watch on a directory that was deleted and
# recreated is a watch on nothing.
rm -f "$DEST"/*/places/*.svg 2>/dev/null
dirs=""
for size in $SIZES; do
    places="$SRC/$size/places"
    [ -d "$places" ] || continue
    # Only the names in use: Papirus keeps `folder-x.svg` as a symlink into the
    # active colour variant, and the 2000-odd variant files are dead weight.
    # `user-*` comes along because Home, Desktop and the XDG folders are drawn
    # in the same two tones and would otherwise stay blue next to the rest.
    list="$(find "$places" -maxdepth 1 \( -name 'folder*.svg' -o -name 'user-*.svg' \) -type l 2>/dev/null)"
    [ -n "$list" ] || continue

    mkdir -p "$DEST/$size/places"
    n=0
    while IFS= read -r icon; do
        [ -n "$icon" ] || continue
        sed -e "s/#$src_front/#$front/gI" \
            -e "s/#$src_back/#$back/gI" \
            -e "s/#$src_sheet/#$sheet/gI" \
            -e "s/#$src_stamp/#$stamp/gI" \
            "$icon" > "$DEST/$size/places/$(basename "$icon")" 2>/dev/null && n=$((n + 1))
    done <<EOF
$list
EOF
    dirs="$dirs$size/places,"
    say "  $size — $n icons"
done

[ -n "$dirs" ] || { warn "no folder icons found in $SRC"; exit 0; }

# ── The theme index ───────────────────────────────────────────────────────
{
    printf '[Icon Theme]\n'
    printf 'Name=Ashen-Papirus\n'
    printf 'Comment=Papirus, with the folders in Ashen'"'"'s accent\n'
    printf 'Inherits=%s\n' "$INHERITS"
    printf 'Directories=%s\n\n' "${dirs%,}"
    for size in $SIZES; do
        [ -d "$DEST/$size/places" ] || continue
        px="${size%%x*}"
        printf '[%s]\nSize=%s\nContext=Places\nType=Fixed\n\n' "$size/places" "$px"
    done
} > "$DEST/index.theme"

# ── Wear it ───────────────────────────────────────────────────────────────
# Running apps cache the theme by name, so a rewrite under the same name is not
# noticed. Bouncing the setting is what makes them look again.
plain="$([ "$mode" = light ] && echo Papirus || echo Papirus-Dark)"
wanted="Ashen-Papirus"
[ "$APPLY" -eq -1 ] && wanted="$plain"

current=""
command -v gsettings >/dev/null && \
    current="$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")"

if command -v gsettings >/dev/null && [ "$current" != "$wanted" ]; then
    for schema in org.gnome.desktop.interface org.cinnamon.desktop.interface; do
        gsettings writable "$schema" icon-theme >/dev/null 2>&1 || continue
        gsettings set "$schema" icon-theme "$wanted"
    done
fi

# Nudging index.theme is what tells a running app to look again. The old way --
# switching to plain Papirus and back -- did work, but you SAW it: every folder
# on screen flicked to its Papirus blue for a frame.
touch "$DEST/index.theme"

# Deliberately NOT written into ~/.config/gtk-3.0/settings.ini: that file is a
# stow symlink into the repo, so editing it would dirty the working tree on
# every wallpaper change. On Wayland the apps read the icon theme from the
# settings portal, which is what gsettings just told.

say "Folders painted. Theme at $DEST"
