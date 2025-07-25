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
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
. "$PROJECT_ROOT/infra/config/src/load_scripts.sh"
# Enable shellcheck info codes after sourcing
# shellcheck enable=all

# -----------------------------------------------------------------------------
# Cache Directory Setup
# -----------------------------------------------------------------------------
echo "[CACHE] Setting up cache directories..."
UEFI_SHELL_PATH=$("$BB_SCRIPT" cache-location x64 boot)
BASE_SYSTEM_PATH=$("$BB_SCRIPT" cache-location x64 os)
UEFI_SHELLS_DIR=$(dirname "$UEFI_SHELL_PATH")
BASE_SYSTEMS_DIR=$(dirname "$BASE_SYSTEM_PATH")
mkdir -p "$UEFI_SHELLS_DIR"
mkdir -p "$BASE_SYSTEMS_DIR"

# Get target architecture (default to x64 if not specified)
ARCH=${1:-${ARCH:-x64}}
echo "[CACHE] Preparing cache for architecture: $ARCH"

# -----------------------------------------------------------------------------
# UEFI Shell Caching
# -----------------------------------------------------------------------------
echo "[CACHE] Pre-downloading UEFI shell for $ARCH..."

# Get source URL and cache location
UEFI_SOURCE_URL=$("$BB_SCRIPT" source-url "$ARCH" boot)
UEFI_CACHE_PATH=$("$BB_SCRIPT" cache-location "$ARCH" boot)

if [[ -z "$UEFI_SOURCE_URL" || -z "$UEFI_CACHE_PATH" ]]; then
    echo "[ERROR] Failed to get UEFI configuration for architecture: $ARCH"
    exit 1
fi

# Determine cache filename and path
CACHED_UEFI_SHELL="$UEFI_CACHE_PATH"

if [[ -f "$CACHED_UEFI_SHELL" ]]; then
    echo "[CACHE] ✓ UEFI shell for $ARCH already cached ($CACHED_UEFI_SHELL)"
else
    echo "[CACHE] → Downloading UEFI shell for $ARCH from $UEFI_SOURCE_URL"
    if curl -fsSL "$UEFI_SOURCE_URL" -o "$CACHED_UEFI_SHELL"; then
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
UBUNTU_URL=$("$BB_SCRIPT" source-url "$ARCH" os)
CACHED_ROOTFS=$("$BB_SCRIPT" cache-location "$ARCH" os)

if [[ -z "$UBUNTU_URL" || -z "$CACHED_ROOTFS" ]]; then
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

# Show what we cached
echo "[CACHE] UEFI shell: $CACHED_UEFI_SHELL"
if [[ -f "$CACHED_UEFI_SHELL" ]]; then
    echo "[CACHE] ✓ UEFI shell cached ($(stat -f%z "$CACHED_UEFI_SHELL" 2>/dev/null || stat -c%s "$CACHED_UEFI_SHELL") bytes)"
else
    echo "[CACHE] ✗ UEFI shell not cached"
fi

echo "[CACHE] Rootfs: $CACHED_ROOTFS"
if [[ -f "$CACHED_ROOTFS" ]]; then
    echo "[CACHE] ✓ Rootfs cached ($(stat -f%z "$CACHED_ROOTFS" 2>/dev/null || stat -c%s "$CACHED_ROOTFS") bytes)"
else
    echo "[CACHE] ✗ Rootfs not cached"
fi

echo "[CACHE] ✓ Cache preparation completed successfully"
