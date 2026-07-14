#!/bin/bash
# ══════════════════════════════════════════
#   Ashen — System Setup Script
# ══════════════════════════════════════════

# ── Portability: replaces the repo's hardcoded paths (originally
#    written for /home/adolf) with the real $HOME of whoever is
#    running this script -- so it works on any machine/user ──
echo "-> Fixing hardcoded paths for this machine ($HOME)..."
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
grep -rl "/home/adolf" "$REPO_DIR" \
  --include="*.qml" --include="*.lua" --include="*.sh" \
  --include="*.txt" --include="*.jsonc" --include="*.conf" --include="*.toml" 2>/dev/null \
  | xargs -r sed -i "s|/home/adolf|$HOME|g"


echo "→ Applying GTK settings..."
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'
gsettings set org.gnome.desktop.interface cursor-size 24

echo "→ Applying Papirus folder colors..."
papirus-folders -C bluegrey --theme Papirus-Dark

echo "✓ System setup complete!"
