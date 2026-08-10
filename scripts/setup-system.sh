#!/usr/bin/env bash
# ══════════════════════════════════════════
#   Ashen — System Setup
#   Installs deps, stows the configs, applies the theme.
#   Safe to re-run (updates an existing install).
#
#   by Adolf — github.com/AdolfLecompte
# ══════════════════════════════════════════
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DO_PACKAGES=1
DO_STOW=1
DO_SERVICES=1
DO_PULL=1
ASSUME_YES=0

for arg in "$@"; do
    case "$arg" in
        --no-packages) DO_PACKAGES=0 ;;
        --no-stow)     DO_STOW=0 ;;
        --no-services) DO_SERVICES=0 ;;
        --no-pull)     DO_PULL=0 ;;
        -y|--yes)      ASSUME_YES=1 ;;
        -h|--help)
            echo "usage: setup-system.sh [--no-packages] [--no-stow] [--no-services] [--no-pull] [-y]"
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

# ── 0. Self-update ─────────────────────────────────────────────────────────
# The whole point of re-running: keep an EXISTING install in sync. A downstream
# user who only `git pull`s gets new QML that may need new packages -> half
# updated, broken shell. One who only re-runs setup keeps the old code. So setup
# pulls the repo itself and, if anything changed, re-execs the freshly pulled
# script -- the new package list, stow set, and logic all apply in ONE run
# (the running shell still holds the OLD script in memory, hence the re-exec).
# Skipped when the tree is dirty (protects local/uncommitted work) or --no-pull.
if [[ $DO_PULL -eq 1 ]] && command -v git >/dev/null \
   && git -C "$REPO_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    if [[ -n "$(git -C "$REPO_DIR" status --porcelain 2>/dev/null)" ]]; then
        warn "Repo has local changes — skipping self-update. Commit/stash to enable, or ignore."
    else
        before=$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null)
        say "Updating Ashen (git pull)..."
        if git -C "$REPO_DIR" pull --ff-only >/dev/null 2>&1; then
            after=$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null)
            if [[ "$before" != "$after" ]]; then
                ok "Ashen updated → re-running setup with the new version"
                exec bash "$REPO_DIR/scripts/setup-system.sh" --no-pull "$@"
            fi
            ok "Ashen already up to date"
        else
            warn "git pull failed (no network or diverged) — using the local version."
        fi
    fi
fi

# Everything the shell actually shells out to. Missing one degrades that
# feature; qt6-5compat and the Material Symbols font are hard requirements.
PKGS_OFFICIAL=(
    hyprland kitty zsh stow git base-devel
    qt6-base qt6-declarative qt6-5compat
    quickshell
    pipewire pipewire-pulse pipewire-alsa wireplumber libpulse
    networkmanager bluez bluez-utils udisks2 upower power-profiles-daemon
    brightnessctl lm_sensors pciutils
    wl-clipboard cliphist grim slurp wf-recorder
    hypridle mpvpaper ffmpeg wlsunset
    nemo zenity fastfetch cava xdg-utils libnotify
    papirus-icon-theme adw-gtk-theme
    # Fonts the QML asks for BY FAMILY NAME -- a miss renders tofu, not a fallback:
    #   "JetBrainsMono NF"        <- ttf-jetbrains-mono-nerd
    #   "Material Symbols Rounded" <- ttf-material-symbols-variable (official 'extra',
    #                                 NOT the -git: -git Conflicts With this one)
    #   "Noto Color Emoji"         <- noto-fonts-emoji (emoji in what apps send:
    #                                 notification bodies, clipboard entries)
    ttf-jetbrains-mono-nerd ttf-material-symbols-variable noto-fonts-emoji
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk polkit-gnome
)

# quickshell is in the official 'extra' repo (bundles its Hyprland module for the
# bar and the PAM service for the lock screen) -> moved to PKGS_OFFICIAL so it
# installs even without an AUR helper. Pin the STABLE build, never quickshell-git:
# the rice targets the 0.3.0 API and the -git package tracks a newer, drifting one.
# The rest are AUR-only on vanilla Arch (CachyOS ships some in its own repos, but
# the helper resolves those transparently).
PKGS_AUR=(
    awww matugen grimblast-git
    papirus-folders bibata-cursor-theme
)

SERVICES=(NetworkManager bluetooth power-profiles-daemon)

STOW_PKGS=(cava dconf fastfetch gtk hypr kitty matugen quickshell zsh)

# ── 1. Packages ───────────────────────────────────────────────────────────
if [[ $DO_PACKAGES -eq 1 ]]; then
    command -v pacman >/dev/null || die "not an Arch-based system (no pacman). Install the deps from the README by hand, then re-run with --no-packages."

    # Ashen is PipeWire-only. pipewire-pulse Conflicts With pulseaudio (it does
    # NOT Replace it), so a --noconfirm batch would abort on any machine that
    # still has the old PulseAudio daemon. Swap it out first. libpulse (the
    # client library apps link against) is left alone -- pipewire-pulse uses it.
    pulse_installed=$(pacman -Qq pulseaudio pulseaudio-alsa pulseaudio-bluetooth \
        pulseaudio-jack pulseaudio-equalizer pulseaudio-zeroconf pulseaudio-lirc \
        pulseaudio-rtp 2>/dev/null)
    if [[ -n "$pulse_installed" ]]; then
        warn "PulseAudio is installed; Ashen uses PipeWire. Removing: $pulse_installed"
        # shellcheck disable=SC2086
        sudo pacman -R --noconfirm $pulse_installed \
            || warn "Could not remove PulseAudio automatically — remove it by hand, then re-run."
    fi

    # A single `pacman -S` is one atomic transaction: if ANY package conflicts
    # (a renamed target, an AUR -git variant, or a base package like pipewire
    # that a distro like CachyOS ships as a newer -1.1 rebuild the plain repo
    # would "downgrade"), the whole batch aborts and NOTHING installs. So try
    # the fast batch first, and if it fails, fall back to installing each
    # package on its own -- the good ones still land, only the genuinely
    # conflicting ones are skipped and reported.
    install_each() {   # helper-cmd  pkg...
        local cmd="$1"; shift
        local failed=()
        local p
        for p in "$@"; do
            # shellcheck disable=SC2086
            $cmd --needed --noconfirm "$p" >/dev/null 2>&1 || failed+=("$p")
        done
        if [[ ${#failed[@]} -gt 0 ]]; then
            warn "Could not install: ${failed[*]}"
            warn "Often these are base packages already present (e.g. pipewire) that"
            warn "a local version pin blocks -- safe to ignore if the shell starts."
            warn "Install any genuine misses by hand."
        fi
    }

    say "Installing packages from the official repos..."
    if ! sudo pacman -S --needed --noconfirm "${PKGS_OFFICIAL[@]}"; then
        warn "Batch install hit a conflict -- retrying package by package so one"
        warn "bad package can't block the rest..."
        install_each "sudo pacman -S" "${PKGS_OFFICIAL[@]}"
    fi

    AUR_HELPER=""
    for h in paru yay pikaur trizen; do
        command -v "$h" >/dev/null && { AUR_HELPER="$h"; break; }
    done

    if [[ -n "$AUR_HELPER" ]]; then
        say "Installing AUR packages with $AUR_HELPER..."
        if ! "$AUR_HELPER" -S --needed --noconfirm "${PKGS_AUR[@]}"; then
            warn "Batch install hit a conflict -- retrying package by package..."
            install_each "$AUR_HELPER -S" "${PKGS_AUR[@]}"
        fi
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
# Nothing to rewrite: every path is resolved at runtime from the user's home
# (QML via Quickshell.env("HOME"), shell commands via "$HOME", the hypr/matugen
# configs via "$HOME"/"~"). The repo therefore stays clean after `git pull` on
# any machine -- no sed rewriting the working tree. If you find a literal
# /home/adolf sneaking back in, that is the bug: make it $HOME-relative instead.

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
    gsettings set "$schema" font-name 'Adwaita Sans 11'
    gsettings set "$schema" cursor-theme 'Bibata-Modern-Ice'
    gsettings set "$schema" cursor-size 24
done
# The theme name, the icon theme and the colour-scheme follow light/dark, so
# they are not written here: ashen-gtk-mode.sh owns them and Settings runs it
# again on every switch. Dark is what it reads when nothing has been chosen.
"$REPO_DIR/scripts/ashen-gtk-mode.sh" >/dev/null 2>&1 || true

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

# ── 6b. Camera access ─────────────────────────────────────────────────────
# /dev/video* is root:video rw----, so webcam access (Discord, browsers, any
# screenshare-with-cam) needs the user in the `video` group. PipeWire detects
# the device on its own, but without this the nodes are unreadable. Group
# membership only takes effect on the next login.
if id -nG "$USER" | tr ' ' '\n' | grep -qx video; then
    ok "$USER already in the video group"
else
    say "Adding $USER to the video group (webcam access)..."
    sudo usermod -aG video "$USER" \
        && ok "added to video — log out and back in for it to take effect" \
        || warn "could not add $USER to video — do it by hand: sudo usermod -aG video $USER"
fi

# ── 7. Shell ──────────────────────────────────────────────────────────────
if [[ "$SHELL" != *zsh ]]; then
    warn "Your login shell is $SHELL, not zsh. Change it with: chsh -s $(command -v zsh)"
fi

# The repo's zshrc drives everything through Oh My Zsh (ZSH=$HOME/.oh-my-zsh,
# ZSH_THEME=powerlevel10k/powerlevel10k, plugins=(git zsh-autosuggestions
# zsh-syntax-highlighting z)). None of OMZ, p10k, or the two external plugins are
# packaged into OMZ's custom dir, so clone them. git + z ship with OMZ already.
# Cloning (not the upstream install.sh) keeps it unattended and side-effect-free.
# Re-running the setup UPDATES what is already there (git pull), so an existing
# install refreshes its shell instead of being told "already present".
OMZ="$HOME/.oh-my-zsh"
clone_or_update() {   # url  dest
    if [[ -d "$2/.git" ]]; then
        git -C "$2" pull --ff-only >/dev/null 2>&1 \
            && ok "updated $(basename "$2")" \
            || warn "could not update $(basename "$2") (local changes?) — skipped."
    else
        git clone --depth=1 "$1" "$2" >/dev/null 2>&1 \
            && ok "cloned $(basename "$2")" \
            || warn "could not clone $(basename "$2") from $1 — do it by hand."
    fi
}
if ! command -v git >/dev/null; then
    warn "git missing — cannot install Oh My Zsh. Install git and re-run."
else
    clone_or_update https://github.com/ohmyzsh/ohmyzsh "$OMZ"
    clone_or_update https://github.com/romkatv/powerlevel10k         "$OMZ/custom/themes/powerlevel10k"
    clone_or_update https://github.com/zsh-users/zsh-autosuggestions "$OMZ/custom/plugins/zsh-autosuggestions"
    clone_or_update https://github.com/zsh-users/zsh-syntax-highlighting "$OMZ/custom/plugins/zsh-syntax-highlighting"

    # If the shell is running, reload it so the update takes effect without a
    # full logout. Harmless when it isn't (e.g. first install from a TTY).
    if command -v quickshell >/dev/null && pgrep -x quickshell >/dev/null; then
        say "Reloading Quickshell..."
        pkill quickshell 2>/dev/null
        setsid nohup quickshell -c ashen >/dev/null 2>&1 &
        ok "Quickshell reloaded"
    fi
fi

echo
ok "Ashen setup complete."
echo "  Log out and start the Hyprland session from your display manager or TTY."
