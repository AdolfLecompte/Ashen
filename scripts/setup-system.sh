#!/usr/bin/env bash
# ══════════════════════════════════════════
#   Ashen — System Setup
#   Installs deps, stows the configs, applies the theme.
#   Safe to re-run.
# ══════════════════════════════════════════
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DO_PACKAGES=1
DO_STOW=1
DO_SERVICES=1
ASSUME_YES=0

for arg in "$@"; do
    case "$arg" in
        --no-packages) DO_PACKAGES=0 ;;
        --no-stow)     DO_STOW=0 ;;
        --no-services) DO_SERVICES=0 ;;
        -y|--yes)      ASSUME_YES=1 ;;
        -h|--help)
            echo "usage: setup-system.sh [--no-packages] [--no-stow] [--no-services] [-y]"
            exit 0 ;;
        *) echo "unknown flag: $arg" >&2; exit 1 ;;
    esac
done

c_ok=$'\e[32m'; c_info=$'\e[36m'; c_warn=$'\e[33m'; c_err=$'\e[31m'; c_off=$'\e[0m'
say()  { echo "${c_info}→${c_off} $*"; }
ok()   { echo "${c_ok}✓${c_off} $*"; }
warn() { echo "${c_warn}!${c_off} $*"; }
die()  { echo "${c_err}✗${c_off} $*" >&2; exit 1; }

ask() {
    [[ $ASSUME_YES -eq 1 ]] && return 0
    read -rp "  $1 [Y/n] " reply
    [[ -z "$reply" || "$reply" =~ ^[YySs]$ ]]
}

# Everything the shell actually shells out to. Missing one degrades that
# feature; qt6-5compat and the Material Symbols font are hard requirements.
PKGS_OFFICIAL=(
    hyprland kitty zsh stow git base-devel
    qt6-base qt6-declarative qt6-5compat
    pipewire pipewire-pulse pipewire-alsa wireplumber
    networkmanager bluez bluez-utils udisks2 upower power-profiles-daemon
    brightnessctl lm_sensors
    wl-clipboard cliphist grim slurp wf-recorder
    hypridle mpvpaper ffmpeg
    nemo zenity fastfetch cava
    papirus-icon-theme ttf-jetbrains-mono-nerd adw-gtk3
    xdg-desktop-portal-hyprland polkit-gnome
)

# quickshell needs PAM (lock screen) and the Hyprland modules (bar).
PKGS_AUR=(
    quickshell awww matugen grimblast-git
    papirus-folders bibata-cursor-theme ttf-material-symbols-variable-git
)

SERVICES=(NetworkManager bluetooth power-profiles-daemon)

STOW_PKGS=(cava dconf fastfetch gtk hypr kitty matugen quickshell zsh)

# ── 1. Packages ───────────────────────────────────────────────────────────
if [[ $DO_PACKAGES -eq 1 ]]; then
    command -v pacman >/dev/null || die "not an Arch-based system (no pacman). Install the deps from the README by hand, then re-run with --no-packages."

    say "Installing packages from the official repos..."
    sudo pacman -S --needed --noconfirm "${PKGS_OFFICIAL[@]}" \
        || warn "pacman failed on some packages — check the list above"

    AUR_HELPER=""
    for h in paru yay pikaur trizen; do
        command -v "$h" >/dev/null && { AUR_HELPER="$h"; break; }
    done

    if [[ -n "$AUR_HELPER" ]]; then
        say "Installing AUR packages with $AUR_HELPER..."
        "$AUR_HELPER" -S --needed --noconfirm "${PKGS_AUR[@]}" \
            || warn "$AUR_HELPER failed on some packages — check the list above"
    else
        warn "No AUR helper found (paru/yay/pikaur/trizen)."
        warn "Install these by hand or the shell will not start:"
        printf '    %s\n' "${PKGS_AUR[@]}"
    fi
else
    say "Skipping packages (--no-packages)"
fi

# ── 2. XDG folders ────────────────────────────────────────────────────────
# Hardcoded in English on purpose: the scripts look for these literal names
# no matter what the system locale called the user folders.
say "Creating XDG folders..."
mkdir -p "$HOME/Pictures/Wallpapers" "$HOME/Pictures/Screenshots" "$HOME/Videos"

# ── 3. Portability ────────────────────────────────────────────────────────
# The repo was written on /home/adolf; point every hardcoded path at this $HOME.
if [[ "$HOME" != "/home/adolf" ]]; then
    say "Rewriting hardcoded paths for this machine ($HOME)..."
    grep -rl "/home/adolf" "$REPO_DIR" \
        --include="*.qml" --include="*.lua" --include="*.sh" \
        --include="*.txt" --include="*.jsonc" --include="*.conf" --include="*.toml" 2>/dev/null \
        | xargs -r sed -i "s|/home/adolf|$HOME|g"
fi

# ── 4. Stow ───────────────────────────────────────────────────────────────
# `scripts` is NOT stowed: the shell calls it by absolute path from ~/ashen.
if [[ $DO_STOW -eq 1 ]]; then
    if [[ "$REPO_DIR" != "$HOME/ashen" ]]; then
        warn "Repo is at $REPO_DIR, but the shell hardcodes \$HOME/ashen/scripts/."
        warn "Clone it to ~/ashen or the wallpaper picker will not work."
    fi
    if ! command -v stow >/dev/null; then
        warn "stow is not installed — skipping. Install it and re-run, or symlink by hand."
    else
        # Pre-create the GTK dirs so stow links the files inside them instead of
        # folding the whole directory into a symlink at the repo. Folded, matugen
        # would write its generated gtk.css straight into the git tree.
        mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"

        say "Symlinking configs with stow..."
        ( cd "$REPO_DIR" && stow -t "$HOME" "${STOW_PKGS[@]}" ) \
            || warn "stow reported conflicts — move the offending files aside and re-run"
    fi
else
    say "Skipping stow (--no-stow)"
fi

# ── 5. Theme ──────────────────────────────────────────────────────────────
# On Wayland, GTK apps read the theme from the settings portal, which serves
# org.gnome.desktop.interface — settings.ini alone is ignored. Nemo is a
# Cinnamon app and reads its own namespace on top. All three have to agree or
# apps render in different themes.
say "Applying GTK settings..."
for schema in org.gnome.desktop.interface org.cinnamon.desktop.interface; do
    gsettings writable "$schema" gtk-theme >/dev/null 2>&1 || continue
    gsettings set "$schema" gtk-theme 'adw-gtk3-dark'
    gsettings set "$schema" icon-theme 'Papirus-Dark'
    gsettings set "$schema" font-name 'Adwaita Sans 11'
    gsettings set "$schema" cursor-theme 'Bibata-Modern-Ice'
    gsettings set "$schema" cursor-size 24
done
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

# adw-gtk3-dark supplies the widget shapes; matugen paints them from the
# wallpaper into ~/.config/gtk-{3,4}.0/gtk.css. That file is generated, never
# committed — without a wallpaper there is nothing to derive colors from.
if [[ ! -f "$HOME/.config/gtk-3.0/gtk.css" ]]; then
    wall="$(find "$HOME/Pictures/Wallpapers" -maxdepth 1 -type f \
        \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) -print -quit 2>/dev/null)"
    if [[ -n "$wall" ]] && command -v matugen >/dev/null; then
        say "Generating the GTK palette from $(basename "$wall")..."
        matugen image "$wall" --mode dark --source-color-index 0 >/dev/null \
            && ok "GTK palette generated"
    else
        warn "No wallpaper in ~/Pictures/Wallpapers — GTK stays uncolored."
        warn "Drop one in and pick it from the shell; matugen paints GTK too."
    fi
fi

if command -v papirus-folders >/dev/null; then
    say "Applying Papirus folder colors..."
    papirus-folders -C bluegrey --theme Papirus-Dark
fi

# ── 6. Services ───────────────────────────────────────────────────────────
if [[ $DO_SERVICES -eq 1 ]]; then
    for svc in "${SERVICES[@]}"; do
        if systemctl is-enabled --quiet "$svc" 2>/dev/null; then
            ok "$svc already enabled"
        elif ask "Enable $svc?"; then
            sudo systemctl enable --now "$svc" && ok "$svc enabled"
        fi
    done
else
    say "Skipping services (--no-services)"
fi

# ── 7. Shell ──────────────────────────────────────────────────────────────
if [[ "$SHELL" != *zsh ]]; then
    warn "Your login shell is $SHELL, not zsh. Change it with: chsh -s $(command -v zsh)"
fi
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    warn "Oh My Zsh + Powerlevel10k are not installed (not packaged — see their own docs)."
fi

echo
ok "Ashen setup complete."
echo "  Log out and start the Hyprland session from your display manager or TTY."
