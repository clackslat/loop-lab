# =============================================================================
# Source Control Management Makefile
# =============================================================================
# Component: infra/scm  
# Purpose: Git hooks and repository management tools
# =============================================================================

# Component paths
COMPONENT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
SRC_DIR := $(COMPONENT_DIR)src
ROOT_DIR := $(COMPONENT_DIR)../..

# SCM scripts
PRE_COMMIT_HOOK := $(SRC_DIR)/pre-commit
BUILD_ALL_SCRIPT := $(SRC_DIR)/build_all_arch.sh
FIND_SCRIPTS := $(SRC_DIR)/find_shell_scripts.sh

.PHONY: help
help: ## Show component help
	@echo "Source Control Management Component"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

.PHONY: install-hooks
install-hooks: ## Install Git hooks
	@echo "Installing Git hooks..."
	@cd "$(ROOT_DIR)" && git config core.hooksPath "$(SRC_DIR)"
	@echo "✓ Git hooks installed"

.PHONY: build
build: install-hooks ## Build/setup SCM environment (install hooks)

.PHONY: build-all
build-all: ## Build for all architectures
	@echo "Building for all architectures..."
	@$(BUILD_ALL_SCRIPT)

.PHONY: find-scripts
find-scripts: ## Find and validate shell scripts
	@echo "Finding shell scripts..."
	@$(FIND_SCRIPTS)

.PHONY: validate-scripts
validate-scripts: ## Validate shell scripts with shellcheck
	@echo "Validating shell scripts..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		find "$(ROOT_DIR)" -name "*.sh" -exec shellcheck {} +; \
		echo "✓ Shell scripts validated"; \
	else \
		echo "⚠ shellcheck not installed, skipping validation"; \
	fi

.PHONY: test
test: validate-scripts ## Run SCM tests
	@echo "Testing SCM component..."
	@$(MAKE) find-scripts
	@echo "✓ SCM tests passed"

.PHONY: clean
clean: ## Clean SCM artifacts
	@echo "SCM component has no build artifacts to clean"

.PHONY: status
status: ## Show SCM status
	@echo "Source Control Management Status:"
	@echo "  Pre-commit Hook: $(PRE_COMMIT_HOOK)"
	@echo "  Build All Script: $(BUILD_ALL_SCRIPT)"
	@echo "  Find Scripts: $(FIND_SCRIPTS)"
	@cd "$(ROOT_DIR)" && echo "  Current Git hooks path: $$(git config core.hooksPath || echo 'default')"
	@for file in "$(PRE_COMMIT_HOOK)" "$(BUILD_ALL_SCRIPT)" "$(FIND_SCRIPTS)"; do \
		if [ -f "$$file" ]; then \
			echo "  ✓ $$file exists"; \
		else \
			echo "  ✗ $$file missing"; \
		fi; \
	done
