# ══════════════════════════════════════════
#   Ashen — Zsh Config
# ══════════════════════════════════════════

export ZSH="$HOME/.oh-my-zsh"

# Tema desactivado porque usamos Starship
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    z
)

source $ZSH/oh-my-zsh.sh

# Starship prompt

# Aliases
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias grep='grep --color=auto'
alias hyprconf='cd ~/.config/hypr'
alias ashen='cd ~/ashen'
alias gs='git status'
alias ga='git add .'
alias gc='git commit -m'
alias gp='git push'

# Powerlevel10k
[[ -f ~/.config/zsh/.p10k.zsh ]] && source ~/.config/zsh/.p10k.zsh
export PATH="$HOME/.local/bin:$PATH"

