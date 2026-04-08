# Requirements Document: devcontainer-profiles

> **Version:** 1.2-draft
> **Date:** 2026-04-07
> **Status:** Awaiting approval

## TL;DR

A modular, public Dev Container repository for WSL2 that provides IDE parity between VS Code and JetBrains (local). Profiles are composed via Docker Compose with a shared base layer. Tooling is managed by mise. Secrets are protected with SOPS + AGE for safe public publishing. Repos live on WSL2 ext4 via bind mount for fast I/O and cross-IDE access.

---

## 1. Architecture Overview

### 1.1 Profile Strategy

Multiple `devcontainer.json` files composed via Docker Compose. Each profile extends a shared base.

| Layer     | Purpose                                      |
|-----------|----------------------------------------------|
| **Base**  | Common tools, shell (zsh + Starship), fonts, GPG, SSH, tmux |
| **Python**| Python 3.12+, uv, poetry, pip                |
| **Java**  | Corretto 11/17/21/25, Maven                  |
| **.NET**  | .NET 10 SDK (MS Feature)                     |
| **Infra** | kubectl, helm, k9s, AWS CLI                  |
| **Fullstack** | All of the above composed together       |

### 1.2 Base Image

`mcr.microsoft.com/devcontainers/base:ubuntu-24.04`

### 1.3 Container User

Non-root `vscode` user with passwordless sudo (provided by the base devcontainer image).

### 1.4 Directory Structure

```
devcontainer-profiles/
├── .devcontainer/
│   ├── base/
│   │   ├── Dockerfile
│   │   └── docker-compose.base.yml
│   ├── python/
│   │   ├── devcontainer.json
│   │   └── docker-compose.yml          # extends base
│   ├── java/
│   │   ├── devcontainer.json
│   │   └── docker-compose.yml
│   ├── dotnet/
│   │   ├── devcontainer.json
│   │   └── docker-compose.yml
│   ├── infra/
│   │   ├── devcontainer.json
│   │   └── docker-compose.yml
│   ├── fullstack/
│   │   ├── devcontainer.json
│   │   └── docker-compose.yml
│   └── volumes.yml                      # Central shared volume definitions
├── dotfiles/
│   ├── .zshrc                           # Zsh config (Starship init, mise, aliases)
│   ├── .zshenv                          # Zsh environment (PATH, exports)
│   ├── .bash_aliases                    # Shared aliases (sourced by both zsh and bash)
│   ├── .gitconfig
│   ├── .editorconfig
│   ├── .inputrc
│   ├── starship.toml
│   └── .tmux.conf                       # tmux config + TPM plugins
├── scripts/
│   ├── sync-secrets.sh                  # postCreateCommand: SOPS decrypt → SSH/GPG setup
│   ├── install-fonts.sh                 # Nerd Fonts: Hasklug, Iosevka, JetBrainsMono
│   ├── install-dotfiles.sh              # Symlinks dotfiles/ → $HOME
│   ├── install-tmux-plugins.sh          # TPM bootstrap + plugin install
│   └── validate-env.sh                  # Startup health check
├── secrets/
│   ├── ssh_config.enc.yaml              # SOPS-encrypted SSH config (internal IPs)
│   └── .sops.yaml                       # SOPS rules (which files, which AGE key)
├── templates/
│   ├── pre-commit-base.yaml             # gitleaks, shellcheck, trailing-whitespace
│   ├── pre-commit-python.yaml           # + ruff, mypy
│   ├── pre-commit-java.yaml             # + checkstyle, spotbugs
│   └── pre-commit-dotnet.yaml           # + dotnet-format
├── config/
│   ├── mise.toml                        # Global tool versions
│   ├── ssh_config.template              # Decrypted SSH config template (gitignored)
│   ├── gpg-agent.conf
│   └── .wslconfig.example               # Recommended WSL2 memory/CPU limits
├── Makefile                             # Task runner: build, rebuild, validate, encrypt
├── .editorconfig                        # Root EditorConfig for this repo
├── .gitignore
├── .pre-commit-config.yaml              # Pre-commit for this repo itself
├── .sops.yaml                           # Root SOPS config
├── LICENSE                              # MIT or Apache-2.0
├── renovate.json                        # Automated tool version updates
├── thoughts/                            # Design notes
│   └── plan/
│       └── requirements.md              # This document
└── README.md                            # GPG guide, setup, profiles, Windows Terminal fonts
```

---

## 2. Security & Identity

### 2.1 GPG Master Key Guide (README section)

Step-by-step commands for:
- Creating a master key with [C] (Certify) capability
- Adding [S] (Sign), [E] (Encrypt), and [A] (Authenticate) subkeys
- Exporting only subkeys (master stays offline/airgapped)
- Exporting the [A] subkey as an SSH-compatible identity file (`id_rsa_gpg`)
- Configuring `gpg-agent` with `enable-ssh-support`

### 2.2 SOPS + AGE Encryption

**Goal:** Repo is public-safe. All sensitive configs are SOPS-encrypted with AGE keys.

| Encrypted File            | Contents                           |
|---------------------------|------------------------------------|
| `secrets/ssh_config.enc.yaml` | Internal IPs, hostnames        |

**Not encrypted (public by definition):**
- GPG public keys — committed as plaintext in `config/gpg_pubkeys/` directory
- Public AGE key — committed in `.sops.yaml`

**AGE private key location:** `~/.config/sops/age/keys.txt` on the WSL2 host, mounted **read-only** into the container. Never enters the image, env vars, or logs.

**.sops.yaml rules:**
```yaml
creation_rules:
  - path_regex: secrets/.*\.enc\.yaml$
    age: "<your-AGE-public-key>"
```

### 2.3 sync-secrets.sh (postCreateCommand)

1. Check for mounted AGE key at `~/.config/sops/age/keys.txt`
2. Decrypt `secrets/ssh_config.enc.yaml` → `~/.ssh/config` (permissions 600)
3. Import GPG public keys from `config/gpg_pubkeys/`
4. Import GPG subkeys (from separately mounted/provided secret store)
5. Set GPG trust levels (ultimate for own key)
6. Export [A] subkey → `~/.ssh/id_rsa_gpg` (permissions 600)
7. Set `~/.ssh/` directory to 700
8. Start `gpg-agent` with SSH support
9. Validate: test SSH connection to each configured host

### 2.4 SSH Config (multi-host)

Decrypted template produces:

```
# GitHub
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_rsa_gpg

# Internal Gitea (Omni-Lab)
Host gitea.local
    HostName 192.168.1.x
    User git
    IdentityFile ~/.ssh/id_rsa_gpg

# Bitbucket
Host bitbucket.org
    HostName bitbucket.org
    User git
    IdentityFile ~/.ssh/id_rsa_gpg

# Azure DevOps (SSH)
Host ssh.dev.azure.com
    HostName ssh.dev.azure.com
    User git
    IdentityFile ~/.ssh/id_rsa_gpg
    IdentitiesOnly yes

# Defaults
Host *
    AddKeysToAgent yes
    IdentitiesOnly yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

### 2.5 Git Credential Manager (HTTPS fallback)

Azure DevOps sometimes requires HTTPS + GCM instead of SSH. Include:
- GCM installation in the Dockerfile (via Microsoft .deb package)
- Configuration in `.gitconfig` to use GCM as the credential helper
- Documentation on when SSH vs HTTPS is needed

---

## 3. Toolstack

### 3.1 mise-managed tools (config/mise.toml)

| Tool         | Versions                              | Profile   |
|-------------|---------------------------------------|-----------|
| Python       | 3.12+                                 | python    |
| uv           | latest                                | python    |
| poetry       | latest                                | python    |
| Java         | corretto-11, corretto-17, corretto-21, corretto-25 | java |
| Maven        | latest                                | java      |
| Go           | latest                                | base      |
| Node.js      | LTS                                   | base      |
| pnpm         | latest                                | base      |
| kubectl      | latest                                | infra     |
| helm         | latest                                | infra     |
| k9s          | latest                                | infra     |
| fzf          | latest                                | base      |
| zoxide       | latest                                | base      |
| starship     | latest                                | base      |
| gh           | latest (GitHub CLI — PRs, issues, Actions) | base      |
| gk           | latest (GitKraken CLI — git ops, branch, diff) | base      |
| tea          | latest (Gitea CLI)                    | base      |
| pre-commit   | latest                                | base      |
| gitleaks     | latest                                | base      |
| shellcheck   | latest                                | base      |
| shfmt        | latest (shell formatter)              | base      |
| actionlint   | latest (GitHub Actions linter)        | base      |
| yamllint     | latest (via pip)                      | base      |
| direnv       | latest                                | base      |
| cog          | latest (cocogitto — conventional commits + semver) | base |
| git-cliff    | latest (changelog generation)         | base      |
| bd           | latest (beads CLI — issue tracking for AI agents) | base |

### 3.2 Installed via Dockerfile (not mise)

| Tool             | Method                              |
|-----------------|-------------------------------------|
| git (latest)     | APT                                 |
| bash 4+          | APT (default on Ubuntu 24.04)       |
| zsh              | APT (set as container default interactive shell) |
| curl, wget, jq, unzip | APT                          |
| gpg, openssh-client | APT                              |
| tmux             | APT                                 |
| bats             | APT or git submodule (Bash Automated Testing System) |
| gum              | Binary release (Charm — interactive TUI prompts) |
| lazygit          | Binary release or APT PPA           |
| AWS CLI v2       | Official installer                  |
| GCM              | Microsoft .deb package              |
| SOPS             | Binary release                      |
| age              | APT or binary release               |
| make             | APT (build-essential)               |
| Rust (rustup)    | rustup installer (not mise, to avoid cargo conflicts) |

### 3.3 Installed via Dev Container Feature (not mise)

| Tool             | Feature                             |
|-----------------|-------------------------------------|
| .NET 10 SDK      | `ghcr.io/devcontainers/features/dotnet` |
| Docker-in-Docker | `ghcr.io/devcontainers/features/docker-in-docker` |

### 3.4 Database CLI Tools

| Tool      | Install Method | Notes                        |
|-----------|---------------|------------------------------|
| psql      | APT (`postgresql-client`) | PostgreSQL client  |
| mysql     | APT (`mysql-client`)      | MySQL/Dolt client (beads uses Dolt, which is MySQL-compatible) |
| redis-cli | APT (`redis-tools`)       | Redis client       |
| mongosh   | MongoDB APT repo          | MongoDB shell      |

---

## 4. Tiers & Governance

| Tier | Tools                                    | Purpose                    |
|------|------------------------------------------|----------------------------|
| 0    | git, bash 4+, zsh, git-worktree          | Foundational               |
| 1    | pre-commit, gitleaks, shellcheck, shfmt, actionlint, yamllint | Code quality & security |
| 2    | Language/infra tools per profile          | Development                |

### 4.1 Pre-commit Templates (templates/ folder)

| Template                     | Hooks                                      |
|-----------------------------|--------------------------------------------|
| `pre-commit-base.yaml`      | gitleaks, shellcheck, trailing-whitespace, end-of-file-fixer, check-merge-conflict, check-yaml, detect-private-key |
| `pre-commit-python.yaml`    | base + ruff, mypy                          |
| `pre-commit-java.yaml`      | base + checkstyle, spotbugs                |
| `pre-commit-dotnet.yaml`    | base + dotnet-format                       |

### 4.2 Nerd Fonts (scripts/install-fonts.sh)

- Hasklug Nerd Font
- Iosevka Nerd Font
- JetBrainsMono Nerd Font
- Install to `~/.local/share/fonts/`, run `fc-cache -fv`

### 4.3 Windows Terminal Font Guide (README section)

Document how to:
- Download Nerd Fonts `.ttf` files on Windows
- Install via Settings → Fonts
- Configure Windows Terminal `settings.json` → `profiles.defaults.font.face`
- Required for Starship glyphs and terminal icons to render

---

## 5. IDE Customizations

### 5.1 VS Code (devcontainer.json → customizations.vscode)

**Settings:**
- `terminal.integrated.fontFamily`: `"JetBrainsMono Nerd Font"`
- `terminal.integrated.defaultProfile.linux`: `"zsh"`
- `editor.fontFamily`: `"JetBrainsMono Nerd Font, Hasklug Nerd Font, monospace"`
- `editor.fontSize`: 14
- `workbench.colorTheme`: `"Dracula"`
- Starship prompt via dotfiles/.zshrc + dotfiles/starship.toml

**Extensions (free):**
- `dracula-theme.theme-dracula` (active default)
- `catppuccin.catppuccin-vsc` (installed, switchable)
- `eamodio.gitlens`
- `ms-azuretools.vscode-docker`
- `redhat.vscode-yaml`
- `esbenp.prettier-vscode`
- `streetsidesoftware.code-spell-checker`
- `sonarsource.sonarlint-vscode`
- `tamasfe.even-better-toml`
- `editorconfig.editorconfig`

**Extensions (paid/licensed):**
- `github.copilot`
- `github.copilot-chat`

### 5.2 JetBrains (devcontainer.json → customizations.jetbrains)

JetBrains runs **locally** (not via Gateway). The `customizations.jetbrains` block provides plugin/setting recommendations for parity.

**Plugins:**
- AI Assistant (bundled)
- SonarLint
- Key Promoter X
- GitToolBox
- Dracula theme (active default) / Catppuccin (installed)
- .env files support
- EditorConfig

---

## 5.3 GitKraken GUI (Host-Side)

GitKraken GUI runs on the **Windows host**, accessing repos via `\\wsl$\Ubuntu\home\<user>\repos`.

- **Role:** Visual git operations, merge conflict resolution, repo management, credential storage
- **Credential integration:** GitKraken manages its own SSH/GPG keys on the host side. For the same repos to work in both GitKraken (host) and the container, the bind-mounted `~/repos` path is shared.
- **No overlap with container tools:** GitKraken GUI handles visual git workflows; `lazygit` (container TUI) handles quick in-terminal git; `gk` CLI handles scriptable git ops; `gh` CLI handles GitHub PRs/issues/Actions. Each tool has a distinct role.

---

## 5.4 Starship Configuration (dotfiles/starship.toml)

Custom Starship prompt configuration:

```toml
"$schema" = "https://starship.rs/config-schema.json"

format = """
[](#9A348E)\
$os\
$username\
[](bg:#DA627D fg:#9A348E)\
$directory\
[](fg:#DA627D bg:#FCA17D)\
$git_branch\
$git_status\
[](fg:#FCA17D bg:#86BBD8)\
$python\
$java\
$dotnet\
$golang\
$rust\
$nodejs\
[](fg:#86BBD8 bg:#06969A)\
$docker_context\
$kubernetes\
[](fg:#06969A bg:#33658A)\
$time\
[ ](fg:#33658A)\
"""

[os]
disabled = false
style = "bg:#9A348E fg:#FFFFFF"

[username]
show_always = true
style_user = "bg:#9A348E fg:#FFFFFF"
format = "[$user ]($style)"

[directory]
style = "bg:#DA627D fg:#FFFFFF"
format = "[ $path ]($style)"
truncation_length = 3

[git_branch]
style = "bg:#FCA17D fg:#000000"
format = "[ $symbol$branch ]($style)"

[git_status]
style = "bg:#FCA17D fg:#000000"
format = "[$all_status$ahead_behind ]($style)"

[python]
style = "bg:#86BBD8 fg:#000000"
format = "[ $symbol($version) ]($style)"

[java]
style = "bg:#86BBD8 fg:#000000"
format = "[ $symbol($version) ]($style)"

[dotnet]
style = "bg:#86BBD8 fg:#000000"
format = "[ $symbol($version) ]($style)"

[golang]
style = "bg:#86BBD8 fg:#000000"
format = "[ $symbol($version) ]($style)"

[rust]
style = "bg:#86BBD8 fg:#000000"
format = "[ $symbol($version) ]($style)"

[nodejs]
style = "bg:#86BBD8 fg:#000000"
format = "[ $symbol($version) ]($style)"

[docker_context]
style = "bg:#06969A fg:#FFFFFF"
format = "[ $symbol$context ]($style)"

[kubernetes]
style = "bg:#06969A fg:#FFFFFF"
format = "[ $symbol$context(:$namespace) ]($style)"
disabled = false

[time]
style = "bg:#33658A fg:#FFFFFF"
format = "[ $time ]($style)"
disabled = false
time_format = "%T"
```

Features:
- Powerline-style segments with Nerd Font icons
- Language version display (Python, Java, .NET, Go, Rust, Node.js) — auto-detects per directory
- Docker context and Kubernetes cluster/namespace
- Git branch + status indicators
- Clock in the rightmost segment
- Requires a Nerd Font to render glyphs

---

## 6. Terminal: tmux

### 6.1 Configuration

- `dotfiles/.tmux.conf` with TPM (Tmux Plugin Manager) bootstrap
- `scripts/install-tmux-plugins.sh` runs TPM install non-interactively

### 6.2 Plugins (via TPM)

| Plugin                | Purpose                              |
|-----------------------|--------------------------------------|
| `tmux-plugins/tpm`    | Plugin manager                       |
| `tmux-plugins/tmux-sensible` | Standardized sane defaults    |
| `tmux-plugins/tmux-resurrect` | Persist sessions across restarts |
| `tmux-plugins/tmux-continuum` | Auto-save/restore sessions    |
| `sainnhe/tmux-fzf`    | Fuzzy-find tmux operations           |
| `noscript/tmux-mighty-scroll` | Better mouse scrolling       |
| `tmux-plugins/tmux-logging` | Session activity logging        |
| `laktak/extrakto`      | Fuzzy text selection/clipboard       |
| `thewtex/tmux-mem-cpu-load` | CPU/RAM monitoring in status bar |

---

## 7. Docker-in-Docker

- Dev Container Feature: `ghcr.io/devcontainers/features/docker-in-docker`
- Isolated Docker daemon per container (no host socket exposure)
- Docker Compose v2 included
- Named volume for Docker data persists across rebuilds

---

## 8. Storage & Volumes

### 8.1 Central Volume Configuration

All shared volumes defined in `.devcontainer/volumes.yml`, referenced by every profile's `docker-compose.yml` via `extends` or `include`.

### 8.2 Shared Named Volumes

| Volume Name                     | Mount Point              | Purpose                 | Shared Across Profiles |
|---------------------------------|--------------------------|-------------------------|------------------------|
| `devcontainer-mise-cache`       | `~/.local/share/mise`    | mise tool installs      | Yes                    |
| `devcontainer-maven-cache`      | `~/.m2`                  | Maven artifacts         | Yes (Java/Fullstack)   |
| `devcontainer-nuget-cache`      | `~/.nuget`               | NuGet packages          | Yes (.NET/Fullstack)   |
| `devcontainer-pip-cache`        | `~/.cache/pip`           | pip downloads           | Yes (Python/Fullstack) |
| `devcontainer-pnpm-cache`       | `~/.local/share/pnpm`   | pnpm store              | Yes                    |
| `devcontainer-go-cache`         | `~/go`                   | Go modules              | Yes                    |
| `devcontainer-cargo-cache`      | `~/.cargo`               | Rust crate cache        | Yes                    |
| `devcontainer-docker-data`      | `/var/lib/docker`        | DinD data               | Yes                    |

### 8.3 Repos Bind Mount

- Source: `~/repos` on WSL2 host (ext4 filesystem)
- Mount: bind mount into container at `/home/vscode/repos`
- JetBrains accesses via `\\wsl$\Ubuntu\home\<user>\repos`
- Permissions: owned by `vscode` user (UID 1000)

### 8.4 AGE Key Mount

- Source: `~/.config/sops/age/keys.txt` on WSL2 host
- Mount: read-only bind mount into container
- Never part of the Docker image or environment variables

---

## 9. Task Runner (Makefile)

Commands exposed via `make`:

| Target             | Description                                |
|--------------------|--------------------------------------------||
| `make build PROFILE=<name>` | Build a specific profile's container  |
| `make rebuild PROFILE=<name>` | Force rebuild (no cache)            |
| `make validate`    | Run validate-env.sh inside the container   |
| `make encrypt`     | SOPS encrypt changed secret files          |
| `make decrypt`     | SOPS decrypt for local editing             |
| `make fonts`       | Install Nerd Fonts inside container        |
| `make lint`        | Run pre-commit on this repo                |
| `make help`        | List all available targets                 |

---

## 10. WSL2 Configuration

### .wslconfig.example

Recommended WSL2 resource limits (to prevent Docker eating all host RAM):

```ini
[wsl2]
memory=8GB          # Adjust to your system (half of total RAM)
processors=4        # Adjust to your CPU
swap=4GB
localhostForwarding=true
```

Document: copy to `%USERPROFILE%\.wslconfig`, adjust values, `wsl --shutdown && wsl` to apply.

---

## 11. EditorConfig

Root `.editorconfig` for this repo + template for projects:

```ini
root = true

[*]
indent_style = space
indent_size = 2
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

[*.md]
trim_trailing_whitespace = false

[*.{py,java,cs}]
indent_size = 4

[Makefile]
indent_style = tab
```

---

## 12. Automated Maintenance

### 12.1 Renovate (renovate.json)

- Auto-update mise tool versions in `config/mise.toml`
- Auto-update Docker base image tags
- Auto-update Dev Container Feature versions
- Group updates by type (tools, images, features)

### 12.2 LICENSE

MIT license (permissive, suitable for a public developer tooling repo).

---

## 13. Implementation Phases

### Phase 1: Foundation (steps 1-7)
Steps can proceed sequentially within the phase.

1. Create directory structure (`.devcontainer/`, `dotfiles/`, `scripts/`, `config/`, `templates/`, `secrets/`)
2. Write `.devcontainer/base/Dockerfile` — base image, APT packages, mise install, rustup, AWS CLI, GCM, SOPS, age, tmux, lazygit, database CLIs
3. Write `.devcontainer/volumes.yml` — central shared volume definitions
4. Write `.devcontainer/base/docker-compose.base.yml` — extends volumes.yml, repos bind mount, AGE key mount, DinD feature
5. Write `config/mise.toml` — all tool versions per the matrix above
6. Write `dotfiles/` — .zshrc, .zshenv, .bash_aliases, .gitconfig, starship.toml, .inputrc, .tmux.conf, .editorconfig
7. Write `scripts/install-dotfiles.sh` — symlink dotfiles into $HOME

> **Script convention:** All scripts in `scripts/` use `#!/bin/sh` (POSIX sh) unless bash-specific features are required, in which case `#!/usr/bin/env bash` with a comment explaining why. No scripts depend on zsh — zsh is the interactive shell only.

### Phase 2: Security & Identity (steps 8-12)
*Depends on Phase 1 completion.*

8. Write `config/ssh_config.template` — multi-host SSH config
9. Write `config/gpg-agent.conf` — GPG agent with SSH support
10. Write `.sops.yaml` + `secrets/` — SOPS rules, encrypt SSH config; add `config/gpg_pubkeys/` for plaintext public keys
11. Write `scripts/sync-secrets.sh` — SOPS decrypt, GPG import, SSH setup, permission hardening
12. Write `scripts/validate-env.sh` — health check (tools, SSH, GPG, Docker)

### Phase 3: Profiles (steps 13-17)
*Depends on Phase 1. Each profile is independent — can be built in parallel.*

13. `.devcontainer/python/` — devcontainer.json + docker-compose.yml
14. `.devcontainer/java/` — devcontainer.json + docker-compose.yml
15. `.devcontainer/dotnet/` — devcontainer.json + docker-compose.yml
16. `.devcontainer/infra/` — devcontainer.json + docker-compose.yml
17. `.devcontainer/fullstack/` — devcontainer.json + docker-compose.yml (composes all)

### Phase 4: Shell & Terminal (steps 18-19)
*Parallel with Phase 3. Depends on Phase 1.*

18. Write `scripts/install-fonts.sh` — Nerd Fonts installer
19. Write `scripts/install-tmux-plugins.sh` — TPM bootstrap + non-interactive plugin install

### Phase 5: IDE & Templates (steps 20-22)
*Depends on Phase 3 (profile devcontainer.json files exist).*

20. Configure VS Code settings + extensions in each profile's devcontainer.json
21. Configure JetBrains plugin block in each profile's devcontainer.json
22. Write `templates/` — pre-commit config templates per stack

### Phase 6: Project Scaffolding (steps 23-27)
*Parallel with Phase 5.*

23. Write `Makefile` — build, rebuild, validate, encrypt, decrypt, fonts, lint, help
24. Write `.editorconfig` (root)
25. Write `.pre-commit-config.yaml` (for this repo)
26. Write `renovate.json`
27. Write `LICENSE` (MIT)

### Phase 7: Documentation (step 28)
*Depends on all previous phases.*

28. Write `README.md`:
    - GPG master key creation guide ([C][S][E][A] subkeys)
    - SOPS + AGE setup instructions
    - Profile selection and usage
    - Windows Terminal Nerd Font installation
    - .wslconfig recommendations
    - Architecture diagram (Mermaid)
    - Troubleshooting section

---

## 14. Verification

| #  | Check                                                  | Method                          |
|----|--------------------------------------------------------|---------------------------------|
| 1  | Base Dockerfile builds                                 | `make build PROFILE=base`       |
| 2  | Each profile container starts in VS Code               | Open folder → Reopen in Container |
| 3  | `validate-env.sh` passes                               | All mise tools resolve, SSH/GPG/Docker OK |
| 4  | `ssh -T git@github.com` works inside container         | Manual test                     |
| 5  | `docker run hello-world` works (DinD)                  | Manual test                     |
| 6  | VS Code extensions auto-install                        | Open profile → check Extensions panel |
| 7  | Starship prompt renders correctly                      | Visual check in terminal        |
| 8  | Nerd Font glyphs display in Windows Terminal            | Visual check                    |
| 9  | tmux starts with plugins loaded                        | `tmux` → verify status bar      |
| 10 | `pre-commit run --all-files` passes on this repo       | `make lint`                     |
| 11 | SOPS encrypt/decrypt round-trips correctly             | `make encrypt` → `make decrypt` |
| 12 | Repos bind mount is readable/writable                  | `ls ~/repos` inside container   |
| 13 | Named volumes persist across container rebuild          | Rebuild → check ~/.m2 etc.     |
| 14 | lazygit launches inside container                      | `lazygit` in terminal           |
| 15 | JetBrains can open repos via `\\wsl$\` path            | Manual test on host             |

---

## 15. Decisions Log

| Decision                         | Rationale                                              |
|----------------------------------|--------------------------------------------------------|
| Bash + Starship (not Zsh)        | ~~Lighter, POSIX-compatible, user preference~~ **Superseded → Zsh + Starship** |
| Zsh + Starship (interactive default) | Forest uses zsh as primary; consistent across projects. All scripts remain POSIX-compliant (`#!/bin/sh`). Bash still installed as fallback. |
| DinD over socket mount           | Isolated daemon, no host Docker exposure               |
| Dotfiles in-repo                 | Versioned together, symlinked at postCreate            |
| JetBrains local (no Gateway)     | User runs JetBrains locally, just needs SDK parity     |
| GPG subkey import (not forwarding)| User preference for importing into container           |
| .NET via MS Feature (not mise)   | Better IDE integration; mise still used for everything else |
| Rust via rustup (not mise)       | Avoids conflicts with cargo ecosystem expectations     |
| lazygit (replaced git-cola)      | TUI works headless; git-cola needs X11                 |
| GitKraken GUI on host            | Visual git/merge UI; gk CLI for scriptable ops; gh for PRs; lazygit for quick TUI — no overlapping roles |
| Makefile over Taskfile           | Ubiquitous, no extra binary, simpler for shell-based tasks |
| GPG pubkeys plaintext (not SOPS) | Public keys are public by definition; encrypting adds complexity for zero security gain |
| WSL2 ext4 bind mount for repos   | Fast I/O + JetBrains host access via \\wsl$\           |
| SOPS + AGE (not GPG for SOPS)    | Simpler key management, no GPG keyring dependency for SOPS |
| AGE key host-mounted read-only   | Never in image/env/logs; most secure approach           |
| Dracula theme active (Catppuccin installed) | User preference; both available for switching |
| Central volumes.yml              | Single source of truth, no duplication across profiles  |
| MIT license                      | Public repo, permissive, standard for dev tooling      |

---

## 16. Project Compatibility Validation

The toolstack has been validated against two real projects:

### 16.1 forest (`wt` — Git Worktree Lifecycle Manager)

| Requirement | Covered By |
|------------|------------|
| bash ≥4.0 | APT (Ubuntu 24.04 ships bash 5.2) |
| zsh (primary shell for forest) | APT |
| python3 (scripts, yamllint) | mise (Python 3.12+) |
| bats (Bash Automated Testing System) | APT / git submodule |
| shfmt (shell formatting) | mise |
| shellcheck (shell linting) | mise |
| gitleaks (secrets scanning) | mise |
| actionlint (GitHub Actions linting) | mise |
| yamllint (YAML linting) | pip (via Python) |
| gum (Charm — interactive TUI prompts) | Binary release |
| direnv (per-directory env vars) | mise |
| cocogitto/cog (conventional commits) | mise |
| git-cliff (changelog generation) | mise |
| gh (GitHub CLI) | mise |
| fzf (fuzzy finder) | mise |
| tmux (terminal multiplexer) | APT |
| mise (SDK version manager) | Dockerfile |
| pre-commit | mise |
| make | APT |

### 16.2 beads (`bd` — Distributed Issue Tracker, used as CLI tool)

| Requirement | Covered By |
|------------|------------|
| Go (if ever contributing) | mise |
| bd CLI (installed as tool) | mise |
| mysql CLI (Dolt is MySQL-compatible) | APT (`mysql-client`) |
| Node.js + pnpm (npm package / Docusaurus) | mise |
| Python (PyPI package, MCP server) | mise |
| git | APT |

**Note:** beads has its own `.devcontainer/` (Go-based). When contributing to beads directly, use its native devcontainer. The `bd` CLI is installed in our devcontainer as a *consumer* tool.

---

## 17. Out of Scope (Explicit Exclusions)

- JetBrains Gateway / remote development
- GPG agent forwarding from host
- git-cola / GUI apps requiring X11
- Private secrets stored in this repo (only SOPS-encrypted SSH config with internal IPs)
- CI/CD pipelines for projects built inside the container (this repo is the dev environment, not the project)
- VPN / proxy configuration (environment-specific)
- GitKraken GUI installation (runs on host, not in container)
