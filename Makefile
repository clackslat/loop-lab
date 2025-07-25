# =============================================================================
# Cache Preparation
# =============================================================================

.PHONY: prep-cache
prep-cache: ## Prepare/download cache for the given architecture (ARCH)
	@echo "Preparing cache for $(ARCH)..."
	@$(MAKE) prep-cache-boot ARCH=$(ARCH)
	@$(MAKE) prep-cache-os ARCH=$(ARCH)

.PHONY: prep-cache-boot
prep-cache-boot: ## Check and download boot resources (UEFI shell) if missing
	@$(CACHE_SCRIPTS_DIR)/check_and_download_cache.sh $(ARCH) boot

.PHONY: prep-cache-os
prep-cache-os: ## Check and download OS resources (rootfs) if missing
	@$(CACHE_SCRIPTS_DIR)/check_and_download_cache.sh $(ARCH) os
# =============================================================================
# Loop-Lab Makefile
# =============================================================================
# Purpose:
#   Provides fine-grained control over the build process with caching support.
#   Allows selective rebuilding of Docker images and disk images based on
#   what has actually changed.
#
# Key Features:
#   - Dependency tracking for efficient rebuilds
#   - Cache management for base systems
#   - Architecture-specific builds
#   - Development workflow support
# =============================================================================

# Default architecture
ARCH ?= x64

# Infrastructure and application directories
CONFIG_DIR := infra/config/src
CACHE_SCRIPTS_DIR := infra/cache-mgmt/src
DOCKER_DIR := infra/docker/src
ASSEMBLY_DIR := app/netboot/src/assembly

# Build directories and files
BUILD_DIR := build
CACHE_DIR := $(BUILD_DIR)/cache
OUTPUT_DIR := $(BUILD_DIR)/images

# Docker image and container names
DOCKER_IMAGE := loop-lab-builder
DOCKER_TAG := latest
FULL_IMAGE_NAME := $(DOCKER_IMAGE):$(DOCKER_TAG)

# Source files that affect Docker image
DOCKER_SOURCES := $(DOCKER_DIR)/Dockerfile \
				  $(DOCKER_DIR)/strict_trace.sh \
				  $(CONFIG_DIR)/load_scripts.sh \
				  $(CONFIG_DIR)/external_resources.edn \
				  $(CONFIG_DIR)/external_resources.bb \
				  $(ASSEMBLY_DIR)/build_image.sh \
				  $(ASSEMBLY_DIR)/prep_esp.sh \
				  $(ASSEMBLY_DIR)/import_rootfs.sh \
				  $(CACHE_SCRIPTS_DIR)/prep_cache.sh \
				  $(CACHE_SCRIPTS_DIR)/check_and_download_cache.sh \
				  $(CACHE_SCRIPTS_DIR)/show_cache_status.sh \
				  $(CACHE_SCRIPTS_DIR)/clean_cache.sh

# Output files
IMAGE_OUTPUT := $(OUTPUT_DIR)/template-$(ARCH).img
DOCKER_BUILT_MARKER := $(BUILD_DIR)/.docker-built

# Default target
.PHONY: all
all: image

# =============================================================================
# Setup and Cleanup
# =============================================================================

.PHONY: setup
setup: ## Create necessary directories
	@echo "Setting up build directories..."
	@mkdir -p $(BUILD_DIR) $(CACHE_DIR) $(OUTPUT_DIR)

.PHONY: clean
clean: ## Clean build artifacts but keep cache
	@echo "Cleaning build artifacts..."
	@rm -rf $(OUTPUT_DIR)/*
	@rm -f $(DOCKER_BUILT_MARKER)

.PHONY: clean-all
clean-all: clean ## Clean everything including cache
	@echo "Cleaning everything including cache..."
	@rm -rf $(CACHE_DIR)/*

.PHONY: clean-docker
clean-docker: ## Remove Docker image and force rebuild
	@echo "Removing Docker image..."
	@docker rmi $(FULL_IMAGE_NAME) 2>/dev/null || true
	@rm -f $(DOCKER_BUILT_MARKER)

# =============================================================================
# Docker Image Management
# =============================================================================


# Generate Docker build arguments using Babashka, passing ARCH
DOCKER_BUILD_ARGS := $(shell cd $(CONFIG_DIR) && ./external_resources.bb docker-build-args $(ARCH))

# Get image configuration from EDN
IMG_PATH_FROM_EDN := $(shell cd $(CONFIG_DIR) && ./external_resources.bb image-path $(ARCH))
IMG_SIZE_FROM_EDN := $(shell cd $(CONFIG_DIR) && ./external_resources.bb image-size $(ARCH) 2>/dev/null || echo "10G")

$(DOCKER_BUILT_MARKER): $(DOCKER_SOURCES) prep-cache | setup
	@echo "Building Docker image..."
	@echo "Using build args: $(DOCKER_BUILD_ARGS)"
	@docker build $(DOCKER_BUILD_ARGS) -f $(DOCKER_DIR)/Dockerfile -t $(FULL_IMAGE_NAME) .
	@touch $@

.PHONY: docker-build
docker-build: $(DOCKER_BUILT_MARKER) ## Build Docker image if needed

.PHONY: docker-rebuild
docker-rebuild: clean-docker docker-build ## Force rebuild Docker image

.PHONY: docker-info
docker-info: ## Show Docker image information
	@echo "Docker image: $(FULL_IMAGE_NAME)"
	@docker images $(DOCKER_IMAGE) 2>/dev/null || echo "Image not built yet"
	@echo "Image built marker: $(DOCKER_BUILT_MARKER)"
	@test -f $(DOCKER_BUILT_MARKER) && echo "✓ Image is up to date" || echo "✗ Image needs rebuilding"

# =============================================================================
# Cache Management
# =============================================================================

.PHONY: cache-status
cache-status: ## Show cache status for all architectures
	@$(CACHE_SCRIPTS_DIR)/show_cache_status.sh

.PHONY: cache-clean
cache-clean: ## Clean cache for current architecture
	@$(CACHE_SCRIPTS_DIR)/clean_cache.sh $(ARCH)

.PHONY: cache-clean-all
cache-clean-all: ## Clean cache for all architectures
	@$(CACHE_SCRIPTS_DIR)/clean_cache.sh all

.PHONY: cache-clean-boot
cache-clean-boot: ## Clean only boot (UEFI shell) cache
	@$(CACHE_SCRIPTS_DIR)/clean_cache.sh $(ARCH) boot

.PHONY: cache-clean-os
cache-clean-os: ## Clean only OS (rootfs) cache
	@$(CACHE_SCRIPTS_DIR)/clean_cache.sh $(ARCH) os

# =============================================================================
# Image Building
# =============================================================================

$(IMAGE_OUTPUT): $(DOCKER_BUILT_MARKER) | setup
	@echo "Building $(ARCH) disk image..."
	@docker run --rm --privileged \
		-v "$(PWD):/work" \
		-v "$(PWD)/$(CACHE_DIR):/cache" \
		-v "$(PWD)/$(OUTPUT_DIR):/output" \
		-v "/dev:/dev" \
		-e ARCH=$(ARCH) \
		-e IMG_PATH=$(IMG_PATH_FROM_EDN) \
		-e IMG_SIZE=$(IMG_SIZE_FROM_EDN) \
		$(FULL_IMAGE_NAME)
	@echo "✓ Image built: $@"

.PHONY: image
image: $(IMAGE_OUTPUT) ## Build disk image for current architecture

.PHONY: image-rebuild
image-rebuild: cache-clean image ## Force rebuild image (clear cache first)

.PHONY: images-all
images-all: ## Build images for all architectures
	@$(MAKE) ARCH=x64 image
	@$(MAKE) ARCH=aarch64 image

.PHONY: images-rebuild-all
images-rebuild-all: cache-clean-all images-all ## Force rebuild all images

# =============================================================================
# Development Workflow
# =============================================================================

.PHONY: dev-rebuild
dev-rebuild: docker-rebuild image ## Full development rebuild (Docker + image)

.PHONY: dev-quick
dev-quick: docker-build image ## Quick development build (use cache)

.PHONY: dev-test
dev-test: image ## Build and run basic tests
	@echo "Running basic tests on $(ARCH) image..."
	@test -f $(IMAGE_OUTPUT) && echo "✓ Image file exists" || exit 1
	@ls -lh $(IMAGE_OUTPUT)

# =============================================================================
# Interactive Development
# =============================================================================

.PHONY: shell
shell: $(DOCKER_BUILT_MARKER) ## Start interactive shell in build container
	@docker run --rm -it --privileged \
		-v "$(PWD):/work" \
		-v "$(PWD)/$(CACHE_DIR):/cache" \
		-v "$(PWD)/$(OUTPUT_DIR):/output" \
		-v "/dev:/dev" \
		-e ARCH=$(ARCH) \
		-e IMG_PATH=$(IMG_PATH_FROM_EDN) \
		-e IMG_SIZE=$(IMG_SIZE_FROM_EDN) \
		--entrypoint /bin/bash \
		$(FULL_IMAGE_NAME)

.PHONY: debug
debug: $(DOCKER_BUILT_MARKER) ## Start container with debugging tools
	@docker run --rm -it --privileged \
		-v "$(PWD):/work" \
		-v "$(PWD)/$(CACHE_DIR):/cache" \
		-v "$(PWD)/$(OUTPUT_DIR):/output" \
		-v "/dev:/dev" \
		-e ARCH=$(ARCH) \
		-e IMG_PATH=$(IMG_PATH_FROM_EDN) \
		-e IMG_SIZE=$(IMG_SIZE_FROM_EDN) \
		-e DEBUG=1 \
		--entrypoint /bin/bash \
		$(FULL_IMAGE_NAME)

# =============================================================================
# Information and Help
# =============================================================================

.PHONY: status
status: docker-info cache-status ## Show overall build status
	@echo ""
	@echo "Build outputs:"
	@ls -la $(OUTPUT_DIR)/ 2>/dev/null || echo "  No images built yet"

.PHONY: help
help: ## Show this help message
	@echo "Loop-Lab Build System"
	@echo "===================="
	@echo ""
	@echo "Usage: make [target] [ARCH=x64|aarch64]"
	@echo ""
	@echo "Main targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Examples:"
	@echo "  make image ARCH=x64        # Build x64 image"
	@echo "  make dev-quick ARCH=aarch64 # Quick development build"
	@echo "  make cache-clean            # Clear cache for current arch"
	@echo "  make docker-rebuild         # Force Docker image rebuild"

# Make help the default when no target is specified
.DEFAULT_GOAL := help

# =============================================================================
# Configuration
# =============================================================================

# Ensure intermediate files are not deleted
.SECONDARY:

# Use bash for all shell commands
SHELL := /bin/bash

# Enable parallel builds where safe
.PARALLEL:
