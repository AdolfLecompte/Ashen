# Maintainer: Adolf <github.com/AdolfLecompte>
pkgname=ashen-git
_pkgname=ashen
pkgver=r1
pkgrel=1
pkgdesc="Ashen — a Hyprland + Quickshell desktop"
arch=('any')
url="https://github.com/AdolfLecompte/ashen"
license=('MIT')

# Everything the shell, the scripts and the keybinds actually invoke. A missing
# font here is not a fallback, it is tofu: the QML asks for these by family name.
depends=(
    hyprland quickshell
    qt6-base qt6-declarative qt6-5compat
    pipewire pipewire-pulse pipewire-alsa wireplumber libpulse
    networkmanager bluez bluez-utils udisks2 upower power-profiles-daemon
    brightnessctl lm_sensors pciutils
    wl-clipboard cliphist grim slurp wf-recorder
    hypridle mpvpaper ffmpeg wlsunset
    zenity fastfetch cava xdg-utils libnotify
    ttf-jetbrains-mono-nerd ttf-material-symbols-variable noto-fonts-emoji
    awww matugen
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
)
optdepends=(
    'kitty: the terminal the keybinds open, themed by matugen'
    'zsh: the shipped prompt and shell config'
    'nemo: the file manager the keybinds open'
    'grimblast-git: screenshot keybinds'
    'papirus-icon-theme: app icons in the launcher and the tray'
    'adw-gtk-theme: GTK apps that match the palette'
    'bibata-cursor-theme: the shipped cursor'
    'papirus-folders: tints the folder icons to the palette'
    'polkit-gnome: the agent that asks when something needs root'
    'btop: matugen writes it a theme'
    'qt6ct: matugen writes it a palette for Qt apps'
)
makedepends=('git')
provides=("$_pkgname")
conflicts=("$_pkgname")
source=("$_pkgname::git+$url.git")
sha256sums=('SKIP')

pkgver() {
    cd "$srcdir/$_pkgname"
    printf "r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

package() {
    cd "$srcdir/$_pkgname"

    # The shell itself. Quickshell reads /etc/xdg/quickshell, so an installed
    # Ashen runs without putting anything in the user's home.
    install -dm755 "$pkgdir/etc/xdg/quickshell"
    cp -r quickshell/.config/quickshell/ashen "$pkgdir/etc/xdg/quickshell/ashen"

    # Helper scripts, by the names the shell and the keybinds call them by.
    install -dm755 "$pkgdir/usr/bin"
    for s in scripts/ashen-*.sh; do
        install -Dm755 "$s" "$pkgdir/usr/bin/$(basename "$s")"
    done
    install -Dm755 scripts/ashen-setup "$pkgdir/usr/bin/ashen-setup"

    # The dotfiles that HAVE to live in the user's home to take effect
    # (Hyprland, kitty, zsh…). `ashen-setup` puts them there; the package only
    # ships the master copies, because a package may not write to a home.
    install -dm755 "$pkgdir/usr/share/$_pkgname/config"
    for d in cava dconf fastfetch gtk hypr kitty matugen zsh; do
        cp -r "$d" "$pkgdir/usr/share/$_pkgname/config/$d"
    done

    install -Dm644 README.md   "$pkgdir/usr/share/doc/$_pkgname/README.md"
    install -Dm644 CHANGELOG.md "$pkgdir/usr/share/doc/$_pkgname/CHANGELOG.md"
    install -Dm644 docs/DESIGN.md "$pkgdir/usr/share/doc/$_pkgname/DESIGN.md"
    install -Dm644 LICENSE     "$pkgdir/usr/share/licenses/$_pkgname/LICENSE"
}
