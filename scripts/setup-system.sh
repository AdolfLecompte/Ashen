#!/bin/bash
# ══════════════════════════════════════════
#   Ashen — System Setup Script
# ══════════════════════════════════════════

echo "→ Applying GTK settings..."
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'
gsettings set org.gnome.desktop.interface cursor-size 24

echo "→ Applying Papirus folder colors..."
papirus-folders -C bluegrey --theme Papirus-Dark

echo "✓ System setup complete!"
