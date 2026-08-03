#!/usr/bin/env bash
# ── Ashen — apply window border ──────────────────────────────────────────
# Push the matugen-derived accent to Hyprland's active window border, live
# (hyprctl) and persisted (general.lua). Reads the colour matugen wrote to
# ~/.cache/matugen_border_color.txt (its hypr_border template output).
#
# This lives here, NOT in matugen's post_hook, on purpose: matugen runs under
# Quickshell, and its post_hooks inherit an env WITHOUT
# HYPRLAND_INSTANCE_SIGNATURE, so hyprctl there fails and the whole hook aborts
# before it can even persist to general.lua. Called from ashen-wallpaper.sh and
# ashen-recolor.sh right after matugen returns, where we control the env and
# derive the signature ourselves if it is missing.
# ─────────────────────────────────────────────────────────────────────────
set -uo pipefail

CACHE="$HOME/.cache"
hex="$(cat "$CACHE/matugen_border_color.txt" 2>/dev/null)" || exit 0
[ -n "$hex" ] || exit 0

# The live config, not the checkout: with stow they are the same file, and
# without a checkout there is no other one.
GEN="$HOME/.config/hypr/conf/general.lua"
sed -i "s/active_border = { colors = {\"rgba([^)]*)\"} }/active_border = { colors = {\"rgba(${hex}ff)\"} }/" "$GEN"

# hyprctl needs the instance signature; Quickshell-spawned callers do not carry
# it, so recover it from the runtime socket dir (newest instance).
[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || \
    export HYPRLAND_INSTANCE_SIGNATURE="$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr" 2>/dev/null | head -1)"

hyprctl eval "hl.config({ general = { col = { active_border = { colors = {'rgba(${hex}ff)'} } } } })" >/dev/null 2>&1 || true
