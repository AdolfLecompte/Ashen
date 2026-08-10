#!/usr/bin/env bash
# ── Ashen — put the GTK identity where the portal can see it ──  by Adolf ──
#    github.com/AdolfLecompte
#
#    Light and dark are not just a palette: GTK apps also pick a THEME
#    (adw-gtk3 vs adw-gtk3-dark) and a colour-scheme preference, and those were
#    written once at install time and never again. Switching Ashen to light left
#    our colours light and adw-gtk3-dark still serving its own dark tones for
#    everything we do not override -- a half-turned interface.
#
#    On Wayland the settings portal is the authority, and it serves
#    org.gnome.desktop.interface. Nemo is Cinnamon, so it reads
#    org.cinnamon.desktop.interface instead: both get written.
# ─────────────────────────────────────────────────────────────────────────
set -uo pipefail

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}"

mode="$(cat "$CACHE/ashen_theme_mode.txt" 2>/dev/null)"
[ "$mode" = "light" ] || mode="dark"

if [ "$mode" = "light" ]; then
    theme="adw-gtk3"
    scheme="prefer-light"
    icons="Papirus"
else
    theme="adw-gtk3-dark"
    scheme="prefer-dark"
    icons="Papirus-Dark"
fi

command -v gsettings >/dev/null || exit 0

# The accent folders are their own theme and follow the mode by themselves
# (ashen-folders.sh rebuilds them); leave that choice alone.
current_icons="$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")"
[ "$current_icons" = "Ashen-Papirus" ] && icons="Ashen-Papirus"

for schema in org.gnome.desktop.interface org.cinnamon.desktop.interface; do
    gsettings writable "$schema" gtk-theme >/dev/null 2>&1 || continue
    gsettings set "$schema" gtk-theme "$theme"
    gsettings set "$schema" icon-theme "$icons"
done
gsettings set org.gnome.desktop.interface color-scheme "$scheme" 2>/dev/null

# The portal caches what it served: a GTK app that is already up keeps the old
# answer until this comes back.
systemctl --user restart xdg-desktop-portal-gtk.service >/dev/null 2>&1 || true
