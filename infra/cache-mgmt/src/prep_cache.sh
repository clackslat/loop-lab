#!/usr/bin/env bash
# =============================================================================
# Cache Preparation Script (prep_cache.sh)
# =============================================================================
# Purpose:
#   Pre-downloads and caches all external resources (UEFI shells, rootfs 
#   tarballs) to separate caching concerns from functional logic.
#   This improves build speed and reliability by ensuring all resources
#   are available before functional scripts run.
#
# Environment:
#   - Runs inside the disk-tools Docker container during build time
#   - Creates cache directory structure
#   - Downloads all required external resources
#
# Dependencies:
#   - load_scripts.sh: Loads strict_trace.sh and provides BB_SCRIPT
#
# Usage:
#   ./prep_cache.sh [ARCH]
#   Example: ./prep_cache.sh x64
#   Example: ./prep_cache.sh aarch64
#   Default: x64 if no architecture specified
#
# Note:
#   This script is called during Docker image build to populate caches
# =============================================================================

# -----------------------------------------------------------------------------
# Script Sourcing
# -----------------------------------------------------------------------------
# Source required scripts
# shellcheck disable=SC1090,SC1091
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
. "$SCRIPT_DIR/load_scripts.sh"
# Enable shellcheck info codes after sourcing
# shellcheck enable=all

# -----------------------------------------------------------------------------
# Cache Directory Setup
# -----------------------------------------------------------------------------
echo "[CACHE] Setting up cache directories..."
UEFI_SHELLS_DIR=$("$BB_SCRIPT" cache-dir uefi-shells)
BASE_SYSTEMS_DIR=$("$BB_SCRIPT" cache-dir base-systems)
mkdir -p "$UEFI_SHELLS_DIR"
mkdir -p "$BASE_SYSTEMS_DIR"

# Get target architecture (default to x64 if not specified)
ARCH=${1:-${ARCH:-x64}}
echo "[CACHE] Preparing cache for architecture: $ARCH"

# -----------------------------------------------------------------------------
# UEFI Shell Caching
# -----------------------------------------------------------------------------
echo "[CACHE] Pre-downloading UEFI shell for $ARCH..."

# Get UEFI configuration
UEFI_SHELL_CONFIG_OUTPUT=$("$BB_SCRIPT" uefi-config "$ARCH")
if [[ $? -ne 0 ]]; then
    echo "[ERROR] Failed to get UEFI configuration for architecture: $ARCH"
    exit 1
fi

# Export the UEFI configuration variables
eval "$UEFI_SHELL_CONFIG_OUTPUT"

# Determine cache filename and path
CACHED_UEFI_SHELL=$("$BB_SCRIPT" uefi-cache-path "$ARCH")

if [[ -f "$CACHED_UEFI_SHELL" ]]; then
    echo "[CACHE] ✓ UEFI shell for $ARCH already cached ($CACHED_UEFI_SHELL)"
else
    echo "[CACHE] → Downloading UEFI shell for $ARCH from $UEFI_SHELL_URL"
    if curl -fsSL "$UEFI_SHELL_URL" -o "$CACHED_UEFI_SHELL"; then
        echo "[CACHE] ✓ UEFI shell for $ARCH cached successfully ($CACHED_UEFI_SHELL)"
    else
        echo "[ERROR] Failed to download UEFI shell for $ARCH"
        exit 1
    fi
fi

# -----------------------------------------------------------------------------
# Rootfs Caching
# -----------------------------------------------------------------------------
echo "[CACHE] Pre-downloading rootfs tarball for $ARCH..."

# Get Ubuntu URL and rootfs path
UBUNTU_URL=$("$BB_SCRIPT" ubuntu-url "$ARCH")
CACHED_ROOTFS=$("$BB_SCRIPT" rootfs-path "$ARCH")

if [[ $? -ne 0 ]]; then
    echo "[ERROR] Failed to get Ubuntu configuration for architecture: $ARCH"
    exit 1
fi

# Create directory if it doesn't exist
ROOTFS_DIR=$(dirname "$CACHED_ROOTFS")
mkdir -p "$ROOTFS_DIR"

if [[ -f "$CACHED_ROOTFS" ]]; then
    echo "[CACHE] ✓ Rootfs tarball for $ARCH already cached ($CACHED_ROOTFS)"
else
    echo "[CACHE] → Downloading rootfs tarball for $ARCH from $UBUNTU_URL"
    if curl -fsSL "$UBUNTU_URL" -o "$CACHED_ROOTFS"; then
        echo "[CACHE] ✓ Rootfs tarball for $ARCH cached successfully ($CACHED_ROOTFS)"
    else
        echo "[ERROR] Failed to download rootfs tarball for $ARCH"
        exit 1
    fi
fi

# -----------------------------------------------------------------------------
# Cache Validation
# -----------------------------------------------------------------------------
echo "[CACHE] Validating cached resources..."

# List cached UEFI shells
echo "[CACHE] Cached UEFI shells:"
UEFI_SHELLS_DIR=$("$BB_SCRIPT" cache-dir uefi-shells)
ls -la "$UEFI_SHELLS_DIR/" || echo "[CACHE] No UEFI shells cached yet"

# List cached rootfs files
echo "[CACHE] Cached rootfs files:"
find /rootfs-cache -name "*.tar.xz" -exec ls -la {} \; 2>/dev/null || echo "[CACHE] No rootfs files cached yet"

# Show cache sizes
echo "[CACHE] Cache directory sizes:"
CACHE_BASE_DIR=$("$BB_SCRIPT" cache-dir "base-dir")
du -sh "$CACHE_BASE_DIR"/* 2>/dev/null || echo "[CACHE] Cache directories empty"
echo "[CACHE] Rootfs cache sizes:"
du -sh /rootfs-cache/* 2>/dev/null || echo "[CACHE] Rootfs cache empty"

echo "[CACHE] ✓ Cache preparation completed successfully"
