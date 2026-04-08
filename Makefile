.PHONY: help build rebuild validate encrypt decrypt fonts tmux lint clean volumes

SHELL := /bin/sh
PROFILE ?= python
COMPOSE_FILE := .devcontainer/$(PROFILE)/docker-compose.yml

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

volumes: ## Create external Docker volumes
	@echo "Creating external volumes..."
	@for v in devcontainer-mise-cache devcontainer-go-cache devcontainer-cargo-cache \
		devcontainer-pnpm-store devcontainer-docker-data devcontainer-pip-cache \
		devcontainer-maven-cache devcontainer-nuget-cache; do \
		docker volume create "$$v" 2>/dev/null || true; \
	done
	@echo "Done."

build: volumes ## Build the dev container (PROFILE=python|java|dotnet|infra|fullstack)
	docker compose -f $(COMPOSE_FILE) build

rebuild: volumes ## Rebuild with no cache
	docker compose -f $(COMPOSE_FILE) build --no-cache

up: volumes ## Start the dev container
	docker compose -f $(COMPOSE_FILE) up -d

down: ## Stop the dev container
	docker compose -f $(COMPOSE_FILE) down

validate: ## Run environment validation inside the container
	@scripts/validate-env.sh

encrypt: ## Encrypt secrets with SOPS
	@if [ ! -f secrets/ssh_config.enc.yaml ]; then \
		echo "No secrets/ssh_config.enc.yaml found. Create it first."; exit 1; \
	fi
	sops --encrypt --in-place secrets/ssh_config.enc.yaml

decrypt: ## Decrypt secrets with SOPS
	sops --decrypt secrets/ssh_config.enc.yaml

fonts: ## Install Nerd Fonts
	@scripts/install-fonts.sh

tmux: ## Install tmux plugins via TPM
	@scripts/install-tmux-plugins.sh

lint: ## Run pre-commit on all files
	pre-commit run --all-files

clean: ## Remove dangling images and stopped containers
	docker system prune -f
