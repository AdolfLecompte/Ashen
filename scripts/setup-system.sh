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
    sddm papirus-icon-theme ttf-jetbrains-mono-nerd
    xdg-desktop-portal-hyprland polkit-gnome
)

# quickshell needs PAM (lock screen) and the Hyprland modules (bar).
PKGS_AUR=(
    quickshell awww matugen grimblast-git
    papirus-folders bibata-cursor-theme ttf-material-symbols-variable-git
)

SERVICES=(NetworkManager bluetooth power-profiles-daemon)

STOW_PKGS=(cava dconf fastfetch gtk hypr kitty matugen quickshell sddm zsh)

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
        say "Symlinking configs with stow..."
        ( cd "$REPO_DIR" && stow -t "$HOME" "${STOW_PKGS[@]}" ) \
            || warn "stow reported conflicts — move the offending files aside and re-run"
    fi
else
    say "Skipping stow (--no-stow)"
fi

# ── 5. Theme ──────────────────────────────────────────────────────────────
say "Applying GTK settings..."
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'
gsettings set org.gnome.desktop.interface cursor-size 24

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

    # SDDM last and separately: enabling a display manager changes how the
    # machine boots, so it never happens without an explicit yes.
    if systemctl is-enabled --quiet sddm 2>/dev/null; then
        ok "sddm already enabled"
    elif ask "Enable sddm? (this changes what starts at boot)"; then
        sudo systemctl enable sddm && ok "sddm enabled — reboot to use it"
    fi
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
echo "  Log out and log back in through SDDM, picking the Hyprland session."
