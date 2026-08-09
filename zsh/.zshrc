# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
#
# quiet: on a fresh install the oh-my-zsh plugin load can print to the console
# (custom plugins not present yet), and the default 'verbose' mode would dump a
# "console output during initialization detected" warning above Ashen's prompt.
# quiet keeps the instant prompt clean. MUST be set before the source below.
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Ashen — punto de entrada
source ~/.config/zsh/.zshrc

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# The prompt's colours, written by matugen from the wallpaper. AFTER ~/.p10k.zsh
# on purpose: it overrides the fixed cube indices that file ships with, so the
# prompt follows the theme without this rice having to own a p10k config.
[[ ! -f ~/.cache/ashen_p10k.zsh ]] || source ~/.cache/ashen_p10k.zsh

# Ashen: 'clear' tambien recarga fastfetch
clear() {
    command clear
    fastfetch
}

# Ashen: mostrar fastfetch al abrir una terminal nueva (diferido hasta
# que el prompt este completamente listo, para que no lo pise el instant
# prompt de p10k y salga con los colores correctos)
autoload -Uz add-zsh-hook
_ashen_fastfetch_once() {
  sleep 0.3
  fastfetch
  add-zsh-hook -d precmd _ashen_fastfetch_once
}
add-zsh-hook precmd _ashen_fastfetch_once
