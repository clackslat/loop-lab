# =============================================================================
# Loop-Lab Build System
# =============================================================================
# Purpose:
#   Hierarchical build system orchestrating infrastructure and application 
#   components. Each component has its own Makefile and can operate independently
#   while this main Makefile provides a unified developer interface.
#
# Architecture:
#   - infra/config/     : Configuration management and validation
#   - infra/cache-mgmt/ : Cache preparation and management
#   - infra/docker/     : Build environment containerization
#   - infra/scm/        : Source control and Git hooks
#   - app/netboot/      : Network boot disk image assembly
#
# Key Features:
#   - Component independence with hierarchical orchestration
#   - Dependency tracking for efficient rebuilds
#   - Cache management for base systems
#   - Architecture-specific builds (x64, aarch64)
#   - Development workflow support
# =============================================================================

# Default architecture
ARCH ?= x64

# Build directories
BUILD_DIR := build
OUTPUT_DIR := $(BUILD_DIR)/images

# Main outputs
IMAGE_OUTPUT := $(OUTPUT_DIR)/template-$(ARCH).img

# Default target - show basic usage
.DEFAULT_GOAL := usage

# =============================================================================
# Hierarchical Component Orchestration
# =============================================================================
# Purpose:
#   Pure Make dependency-driven build system with dynamic component discovery.
#   Supports the pattern: make [scope] [component] [verb] [params...]
#
# Usage Examples:
#   make all build               → Build everything
#   make all clean               → Clean everything  
#   make all test                → Test everything
#   make app clean               → Clean all app components
#   make infra test              → Test all infra components
#   make app netboot image       → Build netboot image
#   make infra config validate   → Validate configuration
#
# Architecture:
#   - Top level: Dynamic component discovery + Make dependency routing
#   - Component level: Pure implementation of verbs
# =============================================================================

# Step-by-step argument parsing logic - straightforward approach
SCOPE := $(word 1,$(MAKECMDGOALS))

# Straightforward logic: if first word is "all", everything shifts left
ifeq ($(SCOPE),all)
COMPONENT := all
VERB := $(word 2,$(MAKECMDGOALS))
PARAMS := $(wordlist 3,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
else
# For non-"all" scopes, we need at least 3 words: [scope] [component] [verb]
ifeq ($(shell test $(words $(MAKECMDGOALS)) -ge 3 && echo ok),ok)
COMPONENT := $(word 2,$(MAKECMDGOALS))
VERB := $(word 3,$(MAKECMDGOALS))
PARAMS := $(wordlist 4,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
else
# Less than 3 words - set flag for usage routing
ROUTE_TO_USAGE := true
endif
endif

# Lazy component discovery - only compute when needed
APP_COMPONENTS = $(shell find app -maxdepth 1 -type d -not -name app | sed 's|app/||' | sort)
INFRA_COMPONENTS = $(shell find infra -maxdepth 1 -type d -not -name infra | sed 's|infra/||' | sort)

# Create prefixed targets for Make dependency routing (computed per-need)
APP_TARGETS = $(addprefix app/,$(APP_COMPONENTS))
INFRA_TARGETS = $(addprefix infra/,$(INFRA_COMPONENTS))

# Make dependency mechanism - let Make handle the iteration
.PHONY: all app infra

# Top-level dependencies - "all" depends on both app and infra scopes
all: app infra ## Build everything using Make dependencies

# Explicit scope targets with clear routing
.PHONY: app
app: infra
ifeq ($(ROUTE_TO_USAGE),true)
	$(MAKE) usage
else ifeq ($(COMPONENT),all)
	@for target in $(APP_TARGETS); do $(MAKE) $$target VERB=$(VERB) PARAMS="$(PARAMS)"; done
else
	$(MAKE) app/$(COMPONENT) VERB=$(VERB) PARAMS="$(PARAMS)"
endif

.PHONY: infra  
infra:
ifeq ($(ROUTE_TO_USAGE),true)
	$(MAKE) usage
else ifeq ($(COMPONENT),all)
	@for target in $(INFRA_TARGETS); do $(MAKE) $$target VERB=$(VERB) PARAMS="$(PARAMS)"; done
else
	$(MAKE) infra/$(COMPONENT) VERB=$(VERB) PARAMS="$(PARAMS)"
endif

# Component targets - route to verb
$(addprefix app/,$(APP_COMPONENTS)):
	@echo "→ Running '$(VERB)' on $@"
	@$(MAKE) -C $@ $(VERB) VERB=$(VERB) PARAMS="$(PARAMS)"

$(addprefix infra/,$(INFRA_COMPONENTS)):
	@echo "→ Running '$(VERB)' on $@"
	@$(MAKE) -C $@ $(VERB) VERB=$(VERB) PARAMS="$(PARAMS)"

# Make all component targets phony (computed per-need)
.PHONY: $(addprefix app/,$(APP_COMPONENTS)) $(addprefix infra/,$(INFRA_COMPONENTS))

# =============================================================================
# Information and Help
# =============================================================================

.PHONY: usage
usage: ## Show basic usage information
	@echo "Loop-Lab Hierarchical Build System"
	@echo "=================================="
	@echo ""
	@echo "Usage: make [scope] [target] [verb] [ARCH=x64|aarch64]" 
	@echo ""
	@echo "Quick Start:"
	@echo "  make all build               # Build everything"
	@echo "  make all status              # Show system status"
	@echo "  make all help                # Show all available operations"
	@echo "  make app help                # Show app component operations"
	@echo "  make infra help              # Show infra component operations"
	@echo ""
	@echo "Examples:"
	@echo "  make all build               # Build everything"
	@echo "  make all clean               # Clean everything"
	@echo "  make app netboot image       # Build netboot image"
	@echo "  make infra docker shell      # Start Docker shell"

# Prevent make from trying to build verb parameters as targets
%:
	@:

# =============================================================================
# Configuration
# =============================================================================

# Ensure intermediate files are not deleted
.SECONDARY:

# Use bash for all shell commands
SHELL := /bin/bash

# Enable parallel builds where safe
.PARALLEL:
