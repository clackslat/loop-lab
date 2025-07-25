# =============================================================================
# Network Boot Application Makefile
# =============================================================================
# Component: app/netboot
# Purpose: Build network boot disk images
# =============================================================================

# Default architecture and configuration
ARCH ?= x64
IMG_SIZE := 10G
DOCKER_IMAGE := loop-lab-builder:latest

# Paths (simplified)
BUILD_DIR := ../../build
OUTPUT_DIR := $(BUILD_DIR)/images
IMAGE_OUTPUT := $(OUTPUT_DIR)/template-$(ARCH).img

.PHONY: help
help: ## Show available targets
	@echo "Network Boot Application Component"
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: build
build: image ## Build disk image (default)

$(IMAGE_OUTPUT):
	@mkdir -p "$(OUTPUT_DIR)"
	@echo "Building $(ARCH) disk image..."
	@docker run --rm --privileged \
		-v "$(CURDIR)/$(BUILD_DIR):/output" \
		-v "$(CURDIR)/$(BUILD_DIR)/cache:/cache" \
		-v /dev:/dev \
		-e ARCH=$(ARCH) \
		-e IMG_PATH="/output/images/template-$(ARCH).img" \
		-e IMG_SIZE=$(IMG_SIZE) \
		$(DOCKER_IMAGE) build_image.sh
	@echo "✓ Image built: $(IMAGE_OUTPUT)"

.PHONY: image
image: $(IMAGE_OUTPUT) ## Build disk image

.PHONY: test
test: ## Run component tests
	@echo "Running netboot tests..."
	@if [ -f "test/test_image.sh" ]; then \
		cd test && ./test_image.sh $(ARCH); \
	else \
		echo "No tests found"; \
	fi

.PHONY: clean
clean: ## Clean built artifacts
	@echo "Cleaning netboot artifacts..."
	@rm -f "$(OUTPUT_DIR)"/template-*.img

.PHONY: status
status: ## Show component status
	@echo "Network Boot Component Status:"
	@echo "  Architecture: $(ARCH)"
	@echo "  Image: $(IMAGE_OUTPUT)"
	@if [ -f "$(IMAGE_OUTPUT)" ]; then \
		echo "  Status: ✓ Built"; \
		ls -lh "$(IMAGE_OUTPUT)"; \
	else \
		echo "  Status: ✗ Not built"; \
	fi
