#!/bin/sh
# =============================================================================
# install-dotfiles.sh — Symlink dotfiles into $HOME
# POSIX-compliant (#!/bin/sh)
# =============================================================================
set -e

DOTFILES_DIR="$(cd "$(dirname "$0")/../dotfiles" && pwd)"
HOME_DIR="${HOME}"

log() {
  printf '[dotfiles] %s\n' "$1"
}

link_file() {
  src="$1"
  dest="$2"
  if [ -L "$dest" ]; then
    rm "$dest"
  elif [ -f "$dest" ]; then
    mv "$dest" "${dest}.bak"
    log "Backed up existing $dest → ${dest}.bak"
  fi
  ln -s "$src" "$dest"
  log "Linked $src → $dest"
}

# --- Symlink each dotfile ---
for file in .zshrc .zshenv .bash_aliases .gitconfig .inputrc .editorconfig .tmux.conf; do
  if [ -f "${DOTFILES_DIR}/${file}" ]; then
    link_file "${DOTFILES_DIR}/${file}" "${HOME_DIR}/${file}"
  fi
done

# --- Starship config ---
mkdir -p "${HOME_DIR}/.config"
link_file "${DOTFILES_DIR}/starship.toml" "${HOME_DIR}/.config/starship.toml"

log "Dotfiles installation complete."
