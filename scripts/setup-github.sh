#!/bin/sh
# setup-github.sh — Authenticate gh, set branch protection on main, and open a PR.
# Run this after: gh auth login -h github.com -p ssh
set -e

REPO="sdthach/devcontainer-profiles"

# Check gh auth
if ! gh auth status >/dev/null 2>&1; then
  echo "Not authenticated. Running gh auth login..."
  gh auth login -h github.com -p ssh
fi

echo "==> Setting default branch to main..."
gh repo edit "$REPO" --default-branch main

echo "==> Enabling branch protection on main..."
gh api -X PUT "repos/${REPO}/branches/main/protection" \
  --input - <<'EOF'
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0,
    "dismiss_stale_reviews": true
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF

echo "==> Creating pull request..."
gh pr create \
  --repo "$REPO" \
  --base main \
  --head feat/initial-setup \
  --title "feat: initial devcontainer-profiles setup" \
  --body "## Summary

Modular Dev Container repository for WSL2 with IDE parity between VS Code and JetBrains.

### Phased commits:
1. **Phase 1** — Base layer, dotfiles, and mise config
2. **Phase 2** — GPG/SSH, SOPS+AGE secrets, validation
3. **Phase 3** — Python, Java, .NET, Infra, Fullstack profiles
4. **Phase 4** — Nerd Font and tmux plugin installers
5. **Phase 5** — Pre-commit hook templates
6. **Phase 6** — Makefile, project config, license
7. **Phase 7** — README and requirements

### Key features:
- Ubuntu 24.04 base image with mise-managed tooling
- 5 composable profiles (python, java, dotnet, infra, fullstack)
- Zsh + Starship + tmux (9 TPM plugins)
- SOPS + AGE encryption for public repo safety
- GPG subkey-based SSH and commit signing
- Docker-in-Docker (isolated daemon)
- Named volumes for cache persistence
- Makefile with 13 targets
- Pre-commit templates per language
- Dracula theme (active), Catppuccin (installed)
"

echo "==> Done! PR created."
