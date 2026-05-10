# devcontainer-profiles

A modular Dev Container repository for WSL2 with IDE parity between VS Code and JetBrains (local). Profiles compose via Docker Compose over a shared base. Tooling managed by [mise](https://mise.jdx.dev). Secrets protected with SOPS + AGE.

## Quick Start

You do **not** need to create or mount a separate VHDX for the default setup. In this repo, "WSL2 ext4" simply means the normal Linux filesystem inside your Ubuntu distro, such as `~/repos`. Keep your repos there, not on `/mnt/c`, and this repo will bind-mount them into the container.

If you want a dedicated virtual disk for repo storage, see [Optional: Dedicated VHDX Storage](docs/advanced-storage-layout.md).

```bash
# 1. Clone into your WSL2 ext4 filesystem
cd ~/repos
git clone <this-repo> devcontainer-profiles

# 2. Create external Docker volumes
make volumes

# 3. Open a profile in VS Code
code .devcontainer/python    # or java, dotnet, infra, fullstack
# Then: Ctrl+Shift+P → "Dev Containers: Reopen in Container"
```

## Profiles

| Profile | Languages / Tools | Cache Volumes |
|---------|-------------------|---------------|
| **python** | Python 3.12, uv, poetry, ruff | pip |
| **java** | Corretto 11/17/21/25, Maven | maven |
| **dotnet** | .NET 10 SDK (MS Feature) | nuget |
| **infra** | kubectl, helm, k9s, AWS CLI, Terraform | — |
| **fullstack** | All of the above | pip, maven, nuget |

Every profile extends the base layer which includes: git, zsh + Starship, tmux, fzf, zoxide, lazygit, Docker-in-Docker, GPG/SSH, database CLIs (psql, mysql, redis-cli, mongosh), and more.

## Architecture

```
.devcontainer/
├── base/                  # Shared Dockerfile + docker-compose.base.yml
│   ├── Dockerfile         # Ubuntu 24.04, APT packages, mise, rustup, CLI tools
│   └── docker-compose.base.yml
├── volumes.yml            # Central named volume definitions
├── python/                # Profile: devcontainer.json + docker-compose.yml
├── java/
├── dotnet/
├── infra/
└── fullstack/
```

Each profile's `docker-compose.yml` extends `base/docker-compose.base.yml` and adds profile-specific cache volumes. Each `devcontainer.json` declares VS Code extensions, settings, JetBrains plugins, and the DinD feature.

## Prerequisites

- **WSL2** with Ubuntu (repos on ext4, not `/mnt/c`)
- **Docker Desktop** or Docker Engine in WSL2
- **VS Code** with the Dev Containers extension
- **AGE key** at `~/.config/sops/age/keys.txt` (for secret decryption)

### Windows Terminal Fonts

Install [Nerd Fonts](https://www.nerdfonts.com/) on Windows for Starship/tmux icons:

1. Download **JetBrainsMono Nerd Font** from [nerdfonts.com/font-downloads](https://www.nerdfonts.com/font-downloads)
2. Install the `.ttf` files on Windows (right-click → Install for all users)
3. Set `"fontFace": "JetBrainsMono Nerd Font"` in your Windows Terminal profile

Inside the container, run `make fonts` to install fonts for GUI applications.

### Recommended .wslconfig

Copy `config/.wslconfig.example` to `%USERPROFILE%\.wslconfig` on Windows and adjust memory/CPU limits to your machine.

## GPG Setup Guide

### 1. Create a Master Key (do once, keep offline)

```bash
gpg --full-generate-key
# Select: RSA (sign only), 4096 bits, no expiry (or your preference)
# Note the key ID: ABCD1234ABCD1234
```

### 2. Add Subkeys

```bash
gpg --edit-key ABCD1234ABCD1234
# addkey → RSA (sign only) → 4096       [S] Sign
# addkey → RSA (encrypt only) → 4096    [E] Encrypt
# addkey → RSA (auth only) → 4096       [A] Authenticate
# save
```

### 3. Export Subkeys Only

```bash
# Export secret subkeys (master key stays offline)
gpg --armor --export-secret-subkeys ABCD1234ABCD1234 > subkeys.asc

# Export public key
gpg --armor --export ABCD1234ABCD1234 > config/gpg_pubkeys/yourname.asc
```

### 4. Import Into the Container

The `sync-secrets.sh` script (run by `postCreateCommand`) handles:
- Importing public keys from `config/gpg_pubkeys/*.asc`
- Configuring `gpg-agent` with SSH support
- Exporting the [A] subkey for SSH authentication

For subkey import, mount or copy your `subkeys.asc` into the container and run:
```bash
gpg --import subkeys.asc
echo "ABCD1234ABCD1234:6:" | gpg --import-ownertrust
```

### 5. Configure Git Signing

Edit `dotfiles/.gitconfig` and set:
```ini
[user]
    signingkey = ABCD1234ABCD1234
```

## SOPS + AGE Encryption

### Initial Setup

```bash
# Generate an AGE keypair (do once)
age-keygen -o ~/.config/sops/age/keys.txt

# Copy the public key from the output and add it to .sops.yaml
```

### Encrypt/Decrypt

```bash
# Encrypt secrets
make encrypt

# Decrypt secrets (requires AGE key mounted)
make decrypt
```

The AGE private key lives on your WSL2 host at `~/.config/sops/age/keys.txt` and is mounted **read-only** into the container. It never enters the image, environment variables, or logs.

## Makefile Targets

```
make help       Show all targets
make volumes    Create external Docker volumes
make build      Build the dev container (PROFILE=python)
make rebuild    Rebuild with no cache
make up         Start the dev container
make down       Stop the dev container
make validate   Run environment health check
make encrypt    Encrypt secrets with SOPS
make decrypt    Decrypt secrets with SOPS
make fonts      Install Nerd Fonts in container
make tmux       Install tmux plugins via TPM
make lint       Run pre-commit on all files
make clean      Remove dangling images/containers
```

Set `PROFILE` to choose which profile to build: `make build PROFILE=java`

## Dotfiles

All dotfiles are symlinked from `dotfiles/` into `$HOME` by `scripts/install-dotfiles.sh`. Changes to dotfiles are immediately reflected in the container without rebuilding.

| File | Purpose |
|------|---------|
| `.zshrc` | Zsh config: Starship, mise, direnv, fzf, zoxide |
| `.zshenv` | Environment: PATH, XDG dirs, GPG/SSH |
| `.bash_aliases` | Shared aliases (git, docker, k8s, navigation) |
| `.gitconfig` | Git defaults, GPG signing, worktree aliases |
| `starship.toml` | Prompt: Powerline segments with Nerd Font icons |
| `.tmux.conf` | tmux: mouse, plugins (9 via TPM), continuum |
| `.editorconfig` | Editor defaults: spaces, LF, UTF-8 |
| `.inputrc` | Readline: case-insensitive, colored stats |

## Pre-commit Templates

Copy a template from `templates/` to your project as `.pre-commit-config.yaml`:

| Template | Hooks |
|----------|-------|
| `pre-commit-base.yaml` | trailing-whitespace, gitleaks, shellcheck, shfmt, yamllint |
| `pre-commit-python.yaml` | + ruff, mypy |
| `pre-commit-java.yaml` | + google-java-format, PMD |
| `pre-commit-dotnet.yaml` | + dotnet format |

## JetBrains (Local)

JetBrains IDEs run locally on Windows, not via Gateway. SDK paths are available because repos live on WSL2 ext4 (`\\wsl$\Ubuntu\home\<user>\repos`). The `devcontainer.json` files include JetBrains plugin recommendations (SonarLint, Dracula, Catppuccin, Key Promoter X, GitToolBox).

## Tool Management

[mise](https://mise.jdx.dev) manages tool versions via `config/mise.toml`. After container creation, `mise install` installs all tools. Key tools:

- **Languages:** Go, Node (LTS), Python 3.12, Java (Corretto 11/17/21/25)
- **Package managers:** pnpm, uv, poetry, Maven
- **CLI:** gh, tea, fzf, zoxide, starship, lazygit, gum, direnv
- **Linting:** pre-commit, gitleaks, shellcheck, shfmt, actionlint, yamllint
- **Versioning:** cocogitto (cog), git-cliff
- **Infra:** kubectl, helm, k9s
- **Rust:** Managed via rustup (not mise) to avoid conflicts

## Troubleshooting

### Starship/tmux icons look broken
Install Nerd Fonts on your **Windows host** (not just in the container). See [Windows Terminal Fonts](#windows-terminal-fonts).

### GPG agent not forwarding SSH
```bash
# Restart gpg-agent
gpgconf --kill gpg-agent
gpg-connect-agent /bye
ssh-add -L  # Should show your GPG [A] subkey
```

### Docker-in-Docker not working
The DinD feature runs an isolated Docker daemon inside the container. If it fails:
```bash
# Check DinD daemon
docker info
# If "Cannot connect", the feature may not have started
sudo dockerd &
```

### mise tools not found
```bash
# Verify mise is activated
mise doctor
# Reinstall tools
mise install
```

### Volume permissions
If you see permission errors on cache volumes:
```bash
# Fix ownership (run inside container)
sudo chown -R vscode:vscode ~/.cache ~/.m2 ~/.nuget
```

## License

[Apache License 2.0](LICENSE)

This repository does not currently include a separate NOTICE file.
