# How to Use devcontainer-profiles

## The Concept

This repo is your **environment**, not your project. Your code lives in `~/repos` on WSL2 and is bind-mounted into the container at `/home/vscode/repos`. You pick a profile (python, java, etc.) that gives you the right tools and IDE extensions.

You do **not** need to create or mount a separate VHDX for the default setup. "WSL2 ext4" here means the normal Linux filesystem inside your Ubuntu distro, such as `~/repos`. Keep your repos there, not on `/mnt/c`, and Docker will bind-mount them into the container.

If you prefer to keep repos on a dedicated virtual disk, see [Optional: Dedicated VHDX Storage](advanced-storage-layout.md).

```
Windows
  └── JetBrains (local) → \\wsl$\Ubuntu\home\<user>\repos\<project>
  └── VS Code → Dev Container (this repo) → /home/vscode/repos/<project>
                                                   │
WSL2 ext4: ~/repos/<project> ←────────────────────┘
```

---

## First-Time Setup

### 1. Prerequisites

- WSL2 with Ubuntu 24.04
- Docker Desktop (WSL2 backend) or Docker Engine in WSL2
- VS Code with the **Dev Containers** extension (`ms-vscode-remote.remote-containers`)
- Install **JetBrainsMono Nerd Font** on Windows — download from [nerdfonts.com](https://www.nerdfonts.com/font-downloads), install the `.ttf` files (right-click → Install for all users), then set it in Windows Terminal: `"fontFace": "JetBrainsMono Nerd Font"`

### 2. Clone the repo

```bash
# Clone into WSL2 ext4 (NOT /mnt/c — performance will be poor)
mkdir -p ~/repos
cd ~/repos
git clone git@github.com:sdthach/devcontainer-profiles.git
```

That `~/repos` path is already on the distro's ext4 filesystem. No separate Windows-side disk setup is required for the normal workflow.

### 3. Create external Docker volumes

```bash
cd ~/devcontainer-profiles
make volumes
```

This creates 8 named volumes that persist tool caches (mise, go, cargo, pnpm, pip, maven, nuget, docker) across container rebuilds. Run this **once**, or whenever you reset Docker.

### 4. (Optional) Pre-build a profile

```bash
make build PROFILE=python       # or java, dotnet, infra, fullstack
```

This builds the Docker image in advance so VS Code doesn't have to wait. If you skip this, VS Code builds it on first open.

---

## Using a Profile in VS Code

### Opening the container

1. Open VS Code and install the **Dev Containers** extension if you haven't already
2. Open the `devcontainer-profiles` folder — `File → Open Folder → ~/devcontainer-profiles` (or `code ~/devcontainer-profiles` from a terminal)
3. VS Code will detect multiple profiles. Open the Command Palette (`Ctrl+Shift+P`) and run:
   ```
   Dev Containers: Reopen in Container
   ```
4. A picker appears showing all profiles — select the one you want:

   | Profile | Use for |
   |---------|---------|
   | Python Dev Container | Python services, scripts, data work |
   | Java Dev Container | JVM projects, Maven builds |
   | .NET Dev Container | C# / Rider projects |
   | Infrastructure Dev Container | Kubernetes, Helm, Terraform, AWS |
   | Full-Stack Dev Container | Projects spanning multiple runtimes |

5. VS Code builds (or reuses the pre-built image) and opens a new window inside the container. Your terminal is zsh + Starship. Your repos are at `/home/vscode/repos`.

### Working inside the container

```bash
# Your repos are bind-mounted here
ls /home/vscode/repos

# Tools are managed by mise — verify everything installed
mise doctor
validate-env.sh              # full health check

# Open a project
cd /home/vscode/repos/myproject
```

All VS Code extensions declared in the profile's `devcontainer.json` are installed automatically. The Dracula theme is active by default; Catppuccin is installed and switchable via `Ctrl+Shift+P → Color Theme`.

### Switching profiles

To switch from Python to Java (for example):

1. Close the remote window (`Remote → Close Remote Connection`)
2. `Ctrl+Shift+P → Dev Containers: Reopen in Container`
3. Select the new profile

Each profile uses the same base image and bind-mounted repos, so switching is fast after the first build.

### Rebuilding after Dockerfile changes

```bash
# From the WSL2 host (outside the container)
make rebuild PROFILE=python
# Then reopen in VS Code
```

---

## Using a Profile in JetBrains

JetBrains (IntelliJ IDEA, PyCharm, Rider) runs **locally on Windows** and accesses your project directly on WSL2 via `\\wsl$\`. This avoids network overhead and gives full IDE performance.

### Setup

#### 1. Install mise on the WSL2 host

The container has mise, but JetBrains accesses WSL2 directly — so you need mise on the host too:

```bash
curl https://mise.run | sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
source ~/.bashrc
```

#### 2. Install tools from the shared config

```bash
cp ~/devcontainer-profiles/config/mise.toml ~/.config/mise/config.toml
mise install
```

This gives JetBrains access to the **same tool versions** as the container — Go, Node, Python, Java, etc., all at `~/.local/share/mise/shims/`.

#### 3. Open your project in JetBrains

In JetBrains on Windows, use the **WSL path**:

```
\\wsl$\Ubuntu\home\<youruser>\repos\<project>
```

Or open JetBrains, click **Remote Development → WSL**, select your distro, and navigate to the project.

#### 4. Configure interpreters/SDKs

JetBrains will detect WSL2 and prompt you. Point it to the mise shim paths:

| Language | SDK / Interpreter Path (WSL2) |
|----------|-------------------------------|
| Python | `~/.local/share/mise/shims/python` |
| Java | `~/.local/share/mise/installs/java/<version>` |
| Go | `~/.local/share/mise/shims/go` |
| Node | `~/.local/share/mise/shims/node` |
| .NET | `/usr/share/dotnet/dotnet` (MS Feature installs to `/usr/share/dotnet`) |

In IntelliJ: `File → Project Structure → SDKs → + → WSL`  
In PyCharm: `Settings → Interpreter → Add → WSL`

#### JetBrains plugins

The `devcontainer.json` files include a `customizations.jetbrains` block listing recommended plugins. Install them from `Settings → Plugins`:

- **SonarLint** — code quality
- **Dracula Theme** — matches VS Code default
- **Catppuccin Theme** — switchable
- **Key Promoter X** — learn shortcuts
- **GitToolBox** — inline git blame, branch info

---

## Using a Profile in Your Own Project

Rather than always opening devcontainer-profiles, you can copy a profile into your own project so VS Code opens the container directly from there.

### Copy the profile

```bash
cd ~/repos/myproject
cp -r ~/devcontainer-profiles/.devcontainer/python .devcontainer

# Rename the compose file so VS Code finds it
mv .devcontainer/docker-compose.yml .devcontainer/docker-compose.yml
# Update the extends path to point back to the base
```

Edit `.devcontainer/docker-compose.yml` and update the `extends.file` path:

```yaml
services:
  devcontainer:
    extends:
      file: /home/vscode/devcontainer-profiles/.devcontainer/base/docker-compose.base.yml
      service: devcontainer
```

Then open `~/repos/myproject` in VS Code — `Dev Containers: Reopen in Container` will use the profile directly.

### Add project-specific setup

Edit `.devcontainer/devcontainer.json` and extend `postCreateCommand`:

```json
"postCreateCommand": "bash -c 'cd /workspaces/devcontainer-profiles && scripts/install-dotfiles.sh && scripts/sync-secrets.sh && mise install && cd /workspaces/myproject && pip install -e .[dev]'"
```

---

## Makefile Reference

Run `make help` at any time to see all targets.

```
make volumes                 Create named Docker volumes (run once)
make build PROFILE=python    Build the image for a profile
make rebuild PROFILE=python  Rebuild with --no-cache (after Dockerfile changes)
make up PROFILE=python       Start the container without VS Code
make down PROFILE=python     Stop the container
make validate                Run the environment health check script
make fonts                   Download and install Nerd Fonts
make tmux                    Install tmux plugins via TPM
make lint                    Run pre-commit on all files in this repo
make encrypt                 SOPS-encrypt secrets/ssh_config.enc.yaml
make decrypt                 SOPS-decrypt secrets/ssh_config.enc.yaml
make clean                   Prune dangling images and stopped containers
```

`PROFILE` defaults to `python`. Override it on any target: `make build PROFILE=java`.

---

## Makefile Internals

The `COMPOSE_FILE` variable resolves to `.devcontainer/<PROFILE>/docker-compose.yml`. Each profile's compose file extends the shared base:

```
.devcontainer/python/docker-compose.yml
  └── extends: .devcontainer/base/docker-compose.base.yml
        └── builds: .devcontainer/base/Dockerfile
```

So `make build PROFILE=python` is equivalent to:

```bash
docker compose -f .devcontainer/python/docker-compose.yml build
```

---

## Directory Reference

```
devcontainer-profiles/
├── .devcontainer/
│   ├── base/Dockerfile            ← The image everyone shares
│   ├── base/docker-compose.base.yml
│   ├── volumes.yml
│   ├── python/devcontainer.json   ← VS Code opens this
│   ├── python/docker-compose.yml  ← Extends base, adds pip volume
│   └── (java, dotnet, infra, fullstack — same pattern)
├── config/
│   ├── mise.toml                  ← Shared tool versions (container + WSL2 host)
│   ├── ssh_config.template        ← SSH hosts template
│   └── gpg-agent.conf
├── dotfiles/                      ← Symlinked into $HOME on container create
├── scripts/
│   ├── install-dotfiles.sh        ← Runs automatically (postCreateCommand)
│   ├── sync-secrets.sh            ← Imports GPG keys, decrypts SSH config
│   └── validate-env.sh            ← Health check (make validate)
├── templates/                     ← Copy to your project as .pre-commit-config.yaml
└── Makefile
```
