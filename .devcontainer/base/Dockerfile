# =============================================================================
# Base Dev Container — Ubuntu 24.04
# Common tools, shell (zsh + Starship), GPG, SSH, tmux, database CLIs
# =============================================================================
ARG BASE_IMAGE=mcr.microsoft.com/devcontainers/base:ubuntu-24.04
FROM ${BASE_IMAGE}

# Avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# 1. APT packages — Tier 0 (foundational) + system dependencies
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Tier 0: Foundational
    git \
    bash \
    zsh \
    # Core utilities
    curl \
    wget \
    jq \
    unzip \
    zip \
    ca-certificates \
    gnupg \
    openssh-client \
    # Build tools
    build-essential \
    # Terminal multiplexer
    tmux \
    # Testing
    bats \
    # Database CLIs
    postgresql-client \
    redis-tools \
    mysql-client \
    # Python build deps (for mise-managed Python)
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libncursesw5-dev \
    libxml2-dev \
    libxmlsec1-dev \
    libffi-dev \
    liblzma-dev \
    # direnv (system integration)
    direnv \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 2. MongoDB Shell (mongosh) — separate repo
# ---------------------------------------------------------------------------
RUN curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | \
    gpg --dearmor -o /usr/share/keyrings/mongodb-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/mongodb-archive-keyring.gpg] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/8.0 multiverse" \
    > /etc/apt/sources.list.d/mongodb-org-8.0.list && \
    apt-get update && apt-get install -y --no-install-recommends mongodb-mongosh && \
    rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 3. SOPS + AGE — secrets management
# ---------------------------------------------------------------------------
ARG SOPS_VERSION=3.9.4
ARG AGE_VERSION=1.2.1
RUN curl -fsSL "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.amd64" \
    -o /usr/local/bin/sops && chmod +x /usr/local/bin/sops && \
    curl -fsSL "https://github.com/FiloSottile/age/releases/download/v${AGE_VERSION}/age-v${AGE_VERSION}-linux-amd64.tar.gz" \
    | tar -xz -C /tmp && mv /tmp/age/age /usr/local/bin/age && mv /tmp/age/age-keygen /usr/local/bin/age-keygen \
    && rm -rf /tmp/age

# ---------------------------------------------------------------------------
# 4. lazygit — TUI git client
# ---------------------------------------------------------------------------
ARG LAZYGIT_VERSION=0.44.1
RUN curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" \
    | tar -xz -C /tmp && mv /tmp/lazygit /usr/local/bin/lazygit && chmod +x /usr/local/bin/lazygit

# ---------------------------------------------------------------------------
# 5. gum — Charm TUI prompts
# ---------------------------------------------------------------------------
ARG GUM_VERSION=0.14.5
RUN curl -fsSL "https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/gum_${GUM_VERSION}_Linux_x86_64.tar.gz" \
    | tar -xz -C /tmp && mv /tmp/gum /usr/local/bin/gum && chmod +x /usr/local/bin/gum

# ---------------------------------------------------------------------------
# 6. AWS CLI v2
# ---------------------------------------------------------------------------
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscli.zip && \
    unzip -q /tmp/awscli.zip -d /tmp && /tmp/aws/install && rm -rf /tmp/aws /tmp/awscli.zip

# ---------------------------------------------------------------------------
# 7. Git Credential Manager (GCM) — HTTPS fallback for Azure DevOps
# ---------------------------------------------------------------------------
ARG GCM_VERSION=2.6.1
RUN curl -fsSL "https://github.com/git-ecosystem/git-credential-manager/releases/download/v${GCM_VERSION}/gcm-linux_amd64.${GCM_VERSION}.deb" \
    -o /tmp/gcm.deb && dpkg -i /tmp/gcm.deb && rm /tmp/gcm.deb

# ---------------------------------------------------------------------------
# 8. mise — polyglot SDK version manager
# ---------------------------------------------------------------------------
USER vscode
RUN curl -fsSL https://mise.run | sh && \
    echo 'eval "$(/home/vscode/.local/bin/mise activate bash)"' >> /home/vscode/.bashrc
ENV PATH="/home/vscode/.local/bin:${PATH}"

# ---------------------------------------------------------------------------
# 9. Rust via rustup (not mise — avoids cargo ecosystem conflicts)
# ---------------------------------------------------------------------------
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --no-modify-path
ENV PATH="/home/vscode/.cargo/bin:${PATH}"

# ---------------------------------------------------------------------------
# 10. Set zsh as default interactive shell
# ---------------------------------------------------------------------------
USER root
RUN chsh -s /usr/bin/zsh vscode
USER vscode

# Reset for interactive use
ENV DEBIAN_FRONTEND=dialog
