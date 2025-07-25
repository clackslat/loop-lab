# =============================================================================
# Configuration Management Makefile
# =============================================================================
# Component: infra/config
# Purpose: Manage EDN configuration and external resource definitions
# =============================================================================

# Default architecture
ARCH ?= x64

# Configuration files (simplified paths)
EDN_CONFIG := src/external_resources.edn
BB_SCRIPT := src/external_resources.bb
LOAD_SCRIPT := src/load_scripts.sh

# Default target - show help
.DEFAULT_GOAL := help

.PHONY: help
help: ## Show available targets
	@echo "Configuration Management Component"
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: build
build: validate ## Build/validate configuration (default)

.PHONY: validate
validate: ## Validate configuration files
	@echo "Validating configuration files..."
	@test -f "$(EDN_CONFIG)" || (echo "✗ EDN config missing: $(EDN_CONFIG)" && exit 1)
	@test -f "$(BB_SCRIPT)" || (echo "✗ Babashka script missing: $(BB_SCRIPT)" && exit 1)
	@test -f "$(LOAD_SCRIPT)" || (echo "✗ Load script missing: $(LOAD_SCRIPT)" && exit 1)
	@$(BB_SCRIPT) docker-build-args $(ARCH) >/dev/null || (echo "✗ Configuration access failed" && exit 1)
	@echo "✓ Configuration is valid"

.PHONY: test
test: validate ## Run configuration tests
	@echo "Testing configuration for multiple architectures..."
	@$(BB_SCRIPT) docker-build-args x64 >/dev/null && echo "✓ x64 config OK"
	@$(BB_SCRIPT) docker-build-args aarch64 >/dev/null && echo "✓ aarch64 config OK"

.PHONY: clean
clean: ## Clean configuration artifacts
	@echo "No artifacts to clean"

.PHONY: status
status: ## Show configuration status
	@echo "Configuration Management Status:"
	@echo "  Architecture: $(ARCH)"
	@for file in "$(EDN_CONFIG)" "$(BB_SCRIPT)" "$(LOAD_SCRIPT)"; do \
		if [ -f "$$file" ]; then \
			echo "  ✓ $$file"; \
		else \
			echo "  ✗ $$file missing"; \
		fi; \
	done
