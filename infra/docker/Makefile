# =============================================================================
# Docker Build Environment Makefile
# =============================================================================
# Component: infra/docker
# Purpose: Build and manage containerized build environment
# =============================================================================

# Default architecture and configuration
ARCH ?= x64
DOCKER_IMAGE := loop-lab-builder
DOCKER_TAG := latest
FULL_IMAGE_NAME := $(DOCKER_IMAGE):$(DOCKER_TAG)

# Paths (simplified)
BUILD_DIR := ../../build
DOCKER_BUILT_MARKER := $(BUILD_DIR)/.docker-built

# Architecture mappings (simplified)
BOOT_ARCH_x64 := X64
BOOT_ARCH_aarch64 := AA64
OS_ARCH_x64 := amd64
OS_ARCH_aarch64 := arm64
BOOT_ARCH := $(BOOT_ARCH_$(ARCH))
OS_ARCH := $(OS_ARCH_$(ARCH))

.PHONY: help
help: ## Show available targets
	@echo "Docker Build Environment Component"
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: build
build: $(DOCKER_BUILT_MARKER) ## Build Docker image (default)

$(DOCKER_BUILT_MARKER): src/Dockerfile
	@mkdir -p "$(BUILD_DIR)"
	@echo "Building Docker image for $(ARCH)..."
	@cd ../../ && docker build -f infra/docker/src/Dockerfile \
		--build-arg ARCH=$(ARCH) \
		--build-arg BOOT_ARCH=$(BOOT_ARCH) \
		--build-arg OS_ARCH=$(OS_ARCH) \
		-t $(FULL_IMAGE_NAME) .
	@touch $@
	@echo "✓ Docker image built: $(FULL_IMAGE_NAME)"

.PHONY: shell
shell: build ## Start interactive shell in build container
	@echo "Starting shell in build container..."
	@docker run -it --rm --privileged \
		-v "$(PWD)/$(BUILD_DIR):/output" \
		-v "$(PWD)/$(BUILD_DIR)/cache:/cache" \
		-e ARCH=$(ARCH) \
		$(FULL_IMAGE_NAME) bash

.PHONY: test
test: build ## Test Docker environment
	@echo "Testing Docker environment..."
	@docker run --rm $(FULL_IMAGE_NAME) bash -c "echo 'Container is working'"

.PHONY: clean
clean: ## Remove Docker image and artifacts
	@echo "Cleaning Docker artifacts..."
	@docker rmi $(FULL_IMAGE_NAME) 2>/dev/null || true
	@rm -f "$(DOCKER_BUILT_MARKER)"

.PHONY: status
status: ## Show Docker status
	@echo "Docker Build Environment Status:"
	@echo "  Image: $(FULL_IMAGE_NAME)"
	@echo "  Architecture: $(ARCH) (Boot: $(BOOT_ARCH), OS: $(OS_ARCH))"
	@if docker images -q $(FULL_IMAGE_NAME) >/dev/null 2>&1; then \
		echo "  Status: ✓ Built"; \
	else \
		echo "  Status: ✗ Not built"; \
	fi
