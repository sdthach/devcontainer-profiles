#!/bin/sh
# install-fonts.sh — Download and install Nerd Fonts for the devcontainer.
set -e

FONT_DIR="${HOME}/.local/share/fonts"
mkdir -p "${FONT_DIR}"

NERD_FONT_VERSION="v3.3.0"
BASE_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}"

FONTS="JetBrainsMono Hasklig Iosevka"

for font in ${FONTS}; do
  if ls "${FONT_DIR}"/${font}*.ttf >/dev/null 2>&1; then
    echo "  [skip] ${font} Nerd Font already installed"
    continue
  fi
  echo "  [install] Downloading ${font} Nerd Font..."
  TMP_ZIP=$(mktemp /tmp/${font}-XXXXXX.zip)
  curl -fsSL "${BASE_URL}/${font}.zip" -o "${TMP_ZIP}"
  unzip -oqj "${TMP_ZIP}" "*.ttf" -d "${FONT_DIR}" 2>/dev/null || true
  rm -f "${TMP_ZIP}"
  echo "  [done] ${font} Nerd Font installed"
done

if command -v fc-cache >/dev/null 2>&1; then
  fc-cache -f "${FONT_DIR}"
  echo "  [done] Font cache refreshed"
fi
