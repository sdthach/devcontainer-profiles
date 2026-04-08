# =============================================================================
# Shared aliases — sourced by both zsh (.zshrc) and bash (.bashrc)
# =============================================================================

# --- Navigation ---
alias ..='cd ..'
alias ...='cd ../..'
alias ll='ls -alF --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'

# --- Git ---
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate -20'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'
alias gw='git worktree'
alias gwl='git worktree list'
alias lg='lazygit'

# --- Docker ---
alias d='docker'
alias dc='docker compose'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'

# --- Kubernetes ---
alias k='kubectl'
alias kx='kubectx'
alias kn='kubens'

# --- Mise ---
alias mi='mise install'
alias mu='mise use'
alias ml='mise list'

# --- Safety ---
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
