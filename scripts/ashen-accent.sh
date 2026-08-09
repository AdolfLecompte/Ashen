#!/usr/bin/env bash
# ── Ashen — resolve the accent, then hand it to the apps ─────────────────
# The shell does not always wear matugen's `primary`. On a light palette that
# tone can sit too close to the surface behind it, so services/Colors.qml falls
# back to the container tone when it clears WCAG 4.5:1 and `primary` does not.
# Anything themed outside the shell used `primary` flat and drifted a tone away
# from the bar on exactly those wallpapers.
#
# So the decision is made ONCE, here, and everyone reads the result: the
# templates matugen writes carry __ASHEN_ACCENT__ placeholders instead of a
# colour, and this substitutes them right after matugen returns.
#
# Dark mode has no container fallback (the shell's guard only fires on the light
# face), so there the answer is always `primary` and nothing changes.
#
# Runs from ashen-wallpaper.sh and ashen-recolor.sh, between matugen and
# ashen-apply-border.sh -- never from a matugen post_hook, which fires before
# the other templates are written. The kitty and portal-gtk reloads live at the
# bottom of this file for the same reason: they have to see the substituted
# files, not the ones matugen just left with placeholders in them.
# ─────────────────────────────────────────────────────────────────────────
set -uo pipefail

CACHE="$HOME/.cache"
SRC="$CACHE/ashen_accent.json"
[ -f "$SRC" ] || exit 0

mode="$(cat "$CACHE/ashen_theme_mode.txt" 2>/dev/null)"
[ "$mode" = "light" ] || mode="dark"

# Same relative luminance and WCAG ratio as Colors.lum / Colors.contrast in
# services/Colors.qml -- if one of the two changes, the other has to follow.
# gawk, for strtonum; it is what `awk` is on Arch.
read -r ACCENT ON_ACCENT ACCENT2 ON_ACCENT2 < <(awk -v mode="$mode" '
    function chan(v,   c) { c = v / 255; return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ^ 2.4 }
    function lum(hex,   r, g, b) {
        gsub(/^#/, "", hex)
        r = strtonum("0x" substr(hex, 1, 2))
        g = strtonum("0x" substr(hex, 3, 2))
        b = strtonum("0x" substr(hex, 5, 2))
        return 0.2126 * chan(r) + 0.7152 * chan(g) + 0.0722 * chan(b)
    }
    function ratio(a, b,   la, lb) {
        la = lum(a); lb = lum(b)
        return (la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05))
    }
    # Flat one-level JSON, one "key": "value" per line.
    match($0, /"[a-zA-Z0-9]+"[ \t]*:[ \t]*"#[0-9a-fA-F]+"/) {
        split($0, p, "\"")
        v[p[2]] = p[4]
    }
    END {
        a  = v["accent"];  oa  = v["onAccent"]
        b  = v["accent2"]; ob  = v["onAccent2"]
        if (mode == "light") {
            if (v["accentAlt"]  != "" && ratio(v["accentAlt"],  v["surface"]) >= 4.5) { a = v["accentAlt"];  oa = v["onAccentAlt"] }
            if (v["accent2Alt"] != "" && ratio(v["accent2Alt"], v["surface"]) >= 4.5) { b = v["accent2Alt"]; ob = v["onAccent2Alt"] }
        }
        print a, oa, b, ob
    }
' "$SRC")

[ -n "${ACCENT:-}" ] || exit 0

# The window border wants it without the hash; ashen-apply-border.sh reads this.
printf %s "${ACCENT#\#}" > "$CACHE/ashen_accent.txt"

# Every file matugen just wrote that carries a placeholder. A missing one is not
# an error: not every machine has qt5ct or btop installed.
for f in \
    "$HOME/.config/kitty/ashen-colors.conf" \
    "$HOME/.config/gtk-3.0/gtk.css" \
    "$HOME/.config/gtk-4.0/gtk.css" \
    "$HOME/.config/btop/themes/ashen.theme" \
    "$HOME/.config/qt5ct/colors/ashen.conf" \
    "$HOME/.config/qt6ct/colors/ashen.conf" \
    "$CACHE/ashen_p10k.zsh"
do
    [ -f "$f" ] || continue
    sed -i \
        -e "s/__ASHEN_ON_ACCENT2__/$ON_ACCENT2/g" \
        -e "s/__ASHEN_ON_ACCENT__/$ON_ACCENT/g" \
        -e "s/__ASHEN_ACCENT2__/$ACCENT2/g" \
        -e "s/__ASHEN_ACCENT__/$ACCENT/g" \
        "$f"
done

# Live reloads, moved out of matugen's post_hooks so they see the substituted
# files. kitty appends -<pid> to its listen socket; the GTK portal caches
# gtk.css for the life of the process and is D-Bus activated, so restarting it
# is enough for the next dialog to read the fresh file.
for s in /tmp/kitty-ashen.sock-*; do
    [ -S "$s" ] && kitten @ --to "unix:$s" set-colors --all --configured \
        "$HOME/.config/kitty/ashen-colors.conf" >/dev/null 2>&1
done
systemctl --user restart xdg-desktop-portal-gtk.service >/dev/null 2>&1 || true
exit 0
