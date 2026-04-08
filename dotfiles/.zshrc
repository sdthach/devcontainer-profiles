# =============================================================================
# .zshrc — Zsh interactive shell configuration
# =============================================================================

# --- History ---
HISTFILE="${HOME}/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY

# --- Key bindings ---
bindkey -e  # Emacs-style keybindings

# --- Completion ---
autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' menu select

# --- mise (full interactive activation) ---
if [ -f "${HOME}/.local/bin/mise" ]; then
  eval "$("${HOME}/.local/bin/mise" activate zsh)"
fi

# --- direnv ---
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

# --- zoxide ---
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# --- fzf ---
if command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --zsh 2>/dev/null)" || true
fi

# --- Starship prompt (must be last) ---
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# --- Shared aliases ---
if [ -f "${HOME}/.bash_aliases" ]; then
  . "${HOME}/.bash_aliases"
fi
