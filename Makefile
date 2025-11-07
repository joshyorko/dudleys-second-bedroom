# Makefile for common Dagger operations
# Universal Blue OS - Dudley's Second Bedroom

.PHONY: help validate build test publish iso qcow2 pipeline clean

# Configuration
IMAGE_NAME := dudleys-second-bedroom
REGISTRY := ghcr.io
REPOSITORY := joshyorko/dudleys-second-bedroom
TAG := latest
GIT_COMMIT := $(shell git rev-parse --short HEAD)

help: ## Show this help message
	@echo "Dagger Build Commands for Universal Blue OS"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

validate: ## Validate build configuration
	@echo "🔍 Validating configuration..."
	@dagger call validate --source=.

build: ## Build container image
	@echo "🔨 Building image..."
	@dagger call build \
		--source=. \
		--image-name=$(IMAGE_NAME) \
		--tag=$(TAG) \
		--git-commit=$(GIT_COMMIT)

test: build ## Run tests on built image
	@echo "🧪 Running tests..."
	@IMAGE=$$(dagger call build --source=. --git-commit=$(GIT_COMMIT)) && \
	dagger call test --image=$$IMAGE

publish: build ## Publish image to registry
	@echo "📦 Publishing to $(REGISTRY)/$(REPOSITORY):$(TAG)..."
	@test -n "$(GITHUB_TOKEN)" || (echo "Error: GITHUB_TOKEN not set" && exit 1)
	@IMAGE=$$(dagger call build --source=. --git-commit=$(GIT_COMMIT)) && \
	dagger call publish \
		--image=$$IMAGE \
		--registry=$(REGISTRY) \
		--repository=$(REPOSITORY) \
		--tag=$(TAG) \
		--username=$(GITHUB_USER) \
		--password=env:GITHUB_TOKEN

iso: ## Build ISO image
	@echo "💿 Building ISO..."
	@dagger call build-iso \
		--source=. \
		--image-ref=$(REGISTRY)/$(REPOSITORY):$(TAG) \
		export --path=./output.iso
	@echo "✅ ISO saved to output.iso"

qcow2: ## Build QCOW2 VM image
	@echo "💽 Building QCOW2..."
	@dagger call build-qcow2 \
		--source=. \
		--image-ref=$(REGISTRY)/$(REPOSITORY):$(TAG) \
		export --path=./output.qcow2
	@echo "✅ QCOW2 saved to output.qcow2"

pipeline: ## Run full CI/CD pipeline (no publish)
	@echo "🚀 Running CI pipeline..."
	@dagger call ci-pipeline \
		--source=. \
		--repository=$(REPOSITORY) \
		--tag=$(TAG) \
		--git-commit=$(GIT_COMMIT) \
		--run-tests=true \
		--publish-image=false

pipeline-publish: ## Run full CI/CD pipeline with publish
	@echo "🚀 Running CI pipeline with publish..."
	@test -n "$(GITHUB_TOKEN)" || (echo "Error: GITHUB_TOKEN not set" && exit 1)
	@dagger call ci-pipeline \
		--source=. \
		--registry=$(REGISTRY) \
		--repository=$(REPOSITORY) \
		--tag=$(TAG) \
		--git-commit=$(GIT_COMMIT) \
		--username=$(GITHUB_USER) \
		--password=env:GITHUB_TOKEN \
		--run-tests=true \
		--publish-image=true

lint: ## Lint Containerfile with hadolint
	@echo "📝 Linting Containerfile..."
	@dagger call lint-containerfile --source=.

clean: ## Clean up build artifacts
	@echo "🧹 Cleaning up..."
	@rm -f output.iso output.qcow2 *.tar
	@echo "✅ Clean complete"

# Development helpers
dev-install: ## Install Dagger CLI
	@echo "📦 Installing Dagger..."
	@curl -fsSL https://dl.dagger.io/dagger/install.sh | sh
	@echo "✅ Dagger installed"

dev-functions: ## List all available Dagger functions
	@dagger functions

dev-shell: build ## Open interactive shell in built container
	@echo "🐚 Opening shell..."
	@IMAGE=$$(dagger call build --source=. --git-commit=$(GIT_COMMIT)) && \
	dagger call build --source=. --git-commit=$(GIT_COMMIT) terminal

# Quick shortcuts
all: validate build test ## Run validate, build, and test
release: all publish ## Run all checks and publish
