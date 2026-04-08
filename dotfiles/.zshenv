# =============================================================================
# .zshenv — Zsh environment (loaded for all zsh sessions, including scripts)
# =============================================================================

# XDG Base Directories
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_DATA_HOME="${HOME}/.local/share"
export XDG_CACHE_HOME="${HOME}/.cache"

# Tool paths
export PATH="${HOME}/.local/bin:${PATH}"
export PATH="${HOME}/.cargo/bin:${PATH}"
export GOPATH="${HOME}/go"
export PATH="${GOPATH}/bin:${PATH}"

# mise
if [ -f "${HOME}/.local/bin/mise" ]; then
  eval "$("${HOME}/.local/bin/mise" activate zsh --shims)"
fi

# GPG agent with SSH support
export GPG_TTY=$(tty)
if command -v gpgconf >/dev/null 2>&1; then
  export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
fi

# SOPS / AGE
export SOPS_AGE_KEY_FILE="${HOME}/.config/sops/age/keys.txt"
