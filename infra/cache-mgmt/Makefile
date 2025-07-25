# =============================================================================
# Cache Management Makefile
# =============================================================================
# Component: infra/cache-mgmt
# Purpose: Handle external resource caching and downloads
# =============================================================================

# Component paths
COMPONENT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
SRC_DIR := $(COMPONENT_DIR)src
ROOT_DIR := $(COMPONENT_DIR)../..
BUILD_DIR := $(ROOT_DIR)/build
CACHE_DIR := $(BUILD_DIR)/cache

# Cache management scripts
CHECK_SCRIPT := $(SRC_DIR)/check_and_download_cache.sh
PREP_SCRIPT := $(SRC_DIR)/prep_cache.sh
STATUS_SCRIPT := $(SRC_DIR)/show_cache_status.sh
CLEAN_SCRIPT := $(SRC_DIR)/clean_cache.sh

# Default architecture
ARCH ?= x64

.PHONY: help
help: ## Show component help
	@echo "Cache Management Component"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

.PHONY: setup
setup: ## Create cache directories
	@mkdir -p "$(CACHE_DIR)"
	@echo "✓ Cache directories created"

.PHONY: build
build: prep ## Build/prepare cache for architecture (alias for prep)

.PHONY: prep
prep: setup ## Prepare cache for architecture
	@echo "Preparing cache for $(ARCH)..."
	@$(PREP_SCRIPT) $(ARCH)

.PHONY: prep-boot
prep-boot: setup ## Prepare boot cache only
	@echo "Preparing boot cache for $(ARCH)..."
	@$(CHECK_SCRIPT) $(ARCH) boot

.PHONY: prep-os
prep-os: setup ## Prepare OS cache only
	@echo "Preparing OS cache for $(ARCH)..."
	@$(CHECK_SCRIPT) $(ARCH) os

.PHONY: status
status: ## Show cache status
	@$(STATUS_SCRIPT)

.PHONY: clean
clean: ## Clean cache for current architecture
	@echo "Cleaning cache for $(ARCH)..."
	@$(CLEAN_SCRIPT) $(ARCH)

.PHONY: clean-all
clean-all: ## Clean cache for all architectures
	@echo "Cleaning cache for all architectures..."
	@$(CLEAN_SCRIPT) all

.PHONY: clean-boot
clean-boot: ## Clean boot cache only
	@echo "Cleaning boot cache for $(ARCH)..."
	@$(CLEAN_SCRIPT) $(ARCH) boot

.PHONY: clean-os
clean-os: ## Clean OS cache only
	@echo "Cleaning OS cache for $(ARCH)..."
	@$(CLEAN_SCRIPT) $(ARCH) os

.PHONY: test
test: ## Test cache management
	@echo "Testing cache management..."
	@$(MAKE) status
	@echo "✓ Cache management tests passed"
