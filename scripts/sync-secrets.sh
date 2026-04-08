#!/bin/sh
# =============================================================================
# sync-secrets.sh — postCreateCommand: decrypt secrets, configure GPG/SSH
# POSIX-compliant (#!/bin/sh)
# =============================================================================
set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SECRETS_DIR="${REPO_ROOT}/secrets"
CONFIG_DIR="${REPO_ROOT}/config"

log() {
  printf '[sync-secrets] %s\n' "$1"
}

warn() {
  printf '[sync-secrets] WARNING: %s\n' "$1" >&2
}

# ---------------------------------------------------------------------------
# 1. Check for AGE key
# ---------------------------------------------------------------------------
AGE_KEY_FILE="${HOME}/.config/sops/age/keys.txt"
if [ ! -f "${AGE_KEY_FILE}" ]; then
  warn "AGE key not found at ${AGE_KEY_FILE}"
  warn "Secrets will not be decrypted. Mount your AGE key file read-only."
  warn "Falling back to template SSH config (no internal IPs)."
  SOPS_AVAILABLE=false
else
  SOPS_AVAILABLE=true
  export SOPS_AGE_KEY_FILE="${AGE_KEY_FILE}"
  log "AGE key found."
fi

# ---------------------------------------------------------------------------
# 2. Set up ~/.ssh directory
# ---------------------------------------------------------------------------
mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"

# ---------------------------------------------------------------------------
# 3. Decrypt SSH config (or fall back to template)
# ---------------------------------------------------------------------------
if [ "${SOPS_AVAILABLE}" = true ] && [ -f "${SECRETS_DIR}/ssh_config.enc.yaml" ]; then
  if sops --decrypt "${SECRETS_DIR}/ssh_config.enc.yaml" > "${HOME}/.ssh/config" 2>/dev/null; then
    log "SSH config decrypted successfully."
  else
    warn "SOPS decryption failed. Falling back to template."
    cp "${CONFIG_DIR}/ssh_config.template" "${HOME}/.ssh/config"
  fi
else
  log "Using template SSH config (no SOPS decryption)."
  cp "${CONFIG_DIR}/ssh_config.template" "${HOME}/.ssh/config"
fi
chmod 600 "${HOME}/.ssh/config"

# ---------------------------------------------------------------------------
# 4. Import GPG public keys
# ---------------------------------------------------------------------------
PUBKEY_DIR="${CONFIG_DIR}/gpg_pubkeys"
if [ -d "${PUBKEY_DIR}" ]; then
  for keyfile in "${PUBKEY_DIR}"/*.asc; do
    [ -f "$keyfile" ] || continue
    gpg --import "$keyfile" 2>/dev/null && \
      log "Imported GPG public key: $(basename "$keyfile")" || \
      warn "Failed to import: $(basename "$keyfile")"
  done
fi

# ---------------------------------------------------------------------------
# 5. Configure GPG agent
# ---------------------------------------------------------------------------
mkdir -p "${HOME}/.gnupg"
chmod 700 "${HOME}/.gnupg"
cp "${CONFIG_DIR}/gpg-agent.conf" "${HOME}/.gnupg/gpg-agent.conf"
chmod 600 "${HOME}/.gnupg/gpg-agent.conf"

# Restart gpg-agent with SSH support
gpgconf --kill gpg-agent 2>/dev/null || true
gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true
log "GPG agent configured with SSH support."

# ---------------------------------------------------------------------------
# 6. Export [A] subkey as SSH identity (if GPG key is available)
# ---------------------------------------------------------------------------
if gpg --list-keys --with-colons 2>/dev/null | grep -q '^pub:'; then
  # Get the authentication subkey keygrip
  AUTH_KEYGRIP=$(gpg --list-keys --with-keygrip --with-colons 2>/dev/null | \
    awk -F: '/^sub:.*a[^:]*:/{getline; if ($1=="grp") print $10}' | head -1)
  if [ -n "${AUTH_KEYGRIP}" ]; then
    echo "${AUTH_KEYGRIP}" > "${HOME}/.gnupg/sshcontrol"
    chmod 600 "${HOME}/.gnupg/sshcontrol"
    # Export SSH public key
    gpg --export-ssh-key "$(gpg --list-keys --with-colons 2>/dev/null | \
      awk -F: '/^pub:/{print $5}' | head -1)" > "${HOME}/.ssh/id_rsa_gpg.pub" 2>/dev/null || true
    log "Authentication subkey registered for SSH."
  else
    warn "No [A] (authentication) subkey found. SSH via GPG not configured."
  fi
else
  warn "No GPG keys found. Import your subkeys to enable GPG-based SSH."
  log "Run: gpg --import <your-subkeys-file>"
fi

# ---------------------------------------------------------------------------
# 7. Validate connectivity (non-blocking)
# ---------------------------------------------------------------------------
log "Sync complete. Run 'scripts/validate-env.sh' to verify connectivity."
