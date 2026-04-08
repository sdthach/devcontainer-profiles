#!/bin/sh
# =============================================================================
# validate-env.sh — Startup health check for devcontainer
# POSIX-compliant (#!/bin/sh)
# =============================================================================
set -e

PASS=0
FAIL=0
WARN=0

pass() {
  PASS=$((PASS + 1))
  printf '  \033[32m✓\033[0m %s\n' "$1"
}

fail() {
  FAIL=$((FAIL + 1))
  printf '  \033[31m✗\033[0m %s\n' "$1"
}

warn() {
  WARN=$((WARN + 1))
  printf '  \033[33m!\033[0m %s\n' "$1"
}

check_cmd() {
  if command -v "$1" >/dev/null 2>&1; then
    pass "$1 found: $($1 --version 2>/dev/null | head -1 || echo 'ok')"
  else
    fail "$1 not found"
  fi
}

printf '\n\033[1m=== Dev Container Health Check ===\033[0m\n\n'

# ---------------------------------------------------------------------------
# 1. Tier 0 — Foundational
# ---------------------------------------------------------------------------
printf '\033[1m[Tier 0] Foundational\033[0m\n'
check_cmd git
check_cmd bash
check_cmd zsh
check_cmd make

# ---------------------------------------------------------------------------
# 2. Tier 1 — Code quality & security
# ---------------------------------------------------------------------------
printf '\n\033[1m[Tier 1] Code Quality & Security\033[0m\n'
check_cmd pre-commit
check_cmd gitleaks
check_cmd shellcheck
check_cmd shfmt
check_cmd actionlint

# ---------------------------------------------------------------------------
# 3. Core tools
# ---------------------------------------------------------------------------
printf '\n\033[1m[Core] Tools\033[0m\n'
check_cmd mise
check_cmd starship
check_cmd fzf
check_cmd zoxide
check_cmd tmux
check_cmd lazygit
check_cmd direnv
check_cmd gh
check_cmd gum
check_cmd sops
check_cmd age

# ---------------------------------------------------------------------------
# 4. Language runtimes
# ---------------------------------------------------------------------------
printf '\n\033[1m[Languages] Runtimes\033[0m\n'
check_cmd python3
check_cmd node
check_cmd go
check_cmd rustc
check_cmd cargo
check_cmd java
check_cmd mvn
check_cmd dotnet

# ---------------------------------------------------------------------------
# 5. Infrastructure
# ---------------------------------------------------------------------------
printf '\n\033[1m[Infra] Tools\033[0m\n'
check_cmd kubectl
check_cmd helm
check_cmd k9s
check_cmd aws
check_cmd docker

# ---------------------------------------------------------------------------
# 6. Database CLIs
# ---------------------------------------------------------------------------
printf '\n\033[1m[Database] CLIs\033[0m\n'
check_cmd psql
check_cmd mysql
check_cmd redis-cli
check_cmd mongosh

# ---------------------------------------------------------------------------
# 7. SSH / GPG
# ---------------------------------------------------------------------------
printf '\n\033[1m[Security] SSH & GPG\033[0m\n'

if [ -f "${HOME}/.ssh/config" ]; then
  pass "SSH config exists"
else
  fail "SSH config missing (run sync-secrets.sh)"
fi

if [ -d "${HOME}/.ssh" ]; then
  perms=$(stat -c "%a" "${HOME}/.ssh" 2>/dev/null || true)
  if [ "$perms" = "700" ]; then
    pass "~/.ssh permissions: 700"
  else
    warn "~/.ssh permissions: ${perms} (expected 700)"
  fi
fi

if gpg --list-keys --with-colons 2>/dev/null | grep -q '^pub:'; then
  pass "GPG key imported"
  if gpg --list-keys --with-colons 2>/dev/null | grep -q ':a[^:]*:'; then
    pass "GPG [A] (authentication) subkey found"
  else
    warn "No [A] subkey — SSH via GPG not available"
  fi
else
  warn "No GPG keys imported (import your subkeys)"
fi

if [ -f "${HOME}/.config/sops/age/keys.txt" ]; then
  pass "AGE key mounted"
else
  warn "AGE key not found (mount ~/.config/sops/age/keys.txt)"
fi

# ---------------------------------------------------------------------------
# 8. Docker-in-Docker
# ---------------------------------------------------------------------------
printf '\n\033[1m[Docker] Docker-in-Docker\033[0m\n'
if docker info >/dev/null 2>&1; then
  pass "Docker daemon running"
else
  warn "Docker daemon not running (DinD may need a moment to start)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n\033[1m=== Summary ===\033[0m\n'
printf '  Passed: %d | Failed: %d | Warnings: %d\n\n' "$PASS" "$FAIL" "$WARN"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
