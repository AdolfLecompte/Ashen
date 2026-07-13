# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Ashen — punto de entrada
source ~/.config/zsh/.zshrc

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

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
