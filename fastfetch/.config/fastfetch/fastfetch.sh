#!/bin/bash
# Ashen — fastfetch. Runs when a new terminal opens and on every `clear`
# (see the precmd hook in ~/.zshrc).
exec fastfetch --config "$HOME/.config/fastfetch/config.jsonc"
