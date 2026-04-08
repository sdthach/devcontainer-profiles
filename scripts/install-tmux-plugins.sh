#!/bin/sh
# install-tmux-plugins.sh — Install TPM and all configured tmux plugins.
set -e

TPM_DIR="${HOME}/.tmux/plugins/tpm"

if [ -d "${TPM_DIR}" ]; then
  echo "  [skip] TPM already installed"
else
  echo "  [install] Cloning TPM..."
  git clone --depth 1 https://github.com/tmux-plugins/tpm "${TPM_DIR}"
  echo "  [done] TPM installed"
fi

# Install plugins non-interactively
if [ -x "${TPM_DIR}/bin/install_plugins" ]; then
  echo "  [install] Installing tmux plugins..."
  "${TPM_DIR}/bin/install_plugins"
  echo "  [done] Tmux plugins installed"
else
  echo "  [warn] TPM install_plugins script not found"
fi
