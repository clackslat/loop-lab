#!/usr/bin/env bash
# =============================================================================
# EFI System Partition Preparation Script (prep_esp.sh)
# =============================================================================
# Purpose:
#   Installs the appropriate UEFI Shell for the target architecture into the 
#   EFI System Partition (ESP). The UEFI Shell acts as a fallback boot option 
#   and debugging tool. Uses pre-cached UEFI shells downloaded during image build.
#
# Environment:
#   - Runs inside the disk-tools Docker container
#   - Expects ESP to be mounted at /mnt
#   - Uses pre-cached UEFI shells (no network access required)
#
# Dependencies:
#   - load_scripts.sh: Loads strict_trace.sh and provides BB_SCRIPT
#   - prep_cache.sh: Must have run during image build to populate cache
#
# Usage:
#   ARCH=<arch> ./prep_esp.sh
#   Example: ARCH=aarch64 ./prep_esp.sh
#
# Note:
#   This script is typically called by run_in_docker.sh rather than
#   being invoked directly.
# =============================================================================

# -----------------------------------------------------------------------------
# Script Sourcing
# -----------------------------------------------------------------------------
# Source required scripts
# shellcheck disable=SC1090,SC1091
. "/usr/local/lib/load_scripts.sh"
# Enable shellcheck info codes after sourcing
# shellcheck enable=all

# -----------------------------------------------------------------------------
# Get the UEFI Shell configuration
# -----------------------------------------------------------------------------
# Set target architecture (default to x64 if not specified)
ARCH=${1:-${ARCH:-x64}}
# Define image path based on architecture
IMG="/work/template-${ARCH}.img"

# Get UEFI configuration for the target architecture
UEFI_CONFIG_OUTPUT=$("$BB_SCRIPT" uefi-config "$ARCH")
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to get UEFI configuration for architecture: $ARCH"
    exit 1
fi

# Export the UEFI configuration variables
eval "$UEFI_CONFIG_OUTPUT"

# -----------------------------------------------------------------------------
# Use Pre-cached UEFI Shell
# -----------------------------------------------------------------------------
# Access pre-cached UEFI shell (cached by prep_cache.sh during build)
CACHED_SHELL=$("$BB_SCRIPT" uefi-cache-path "$ARCH")

# Verify cached shell exists (should have been downloaded during image build)
if [[ ! -f "$CACHED_SHELL" ]]; then
    echo "[ERROR] Pre-cached UEFI shell not found: $CACHED_SHELL"
    echo "[ERROR] This indicates a problem with the cache preparation step"
    exit 1
fi

echo "[✓] Using pre-cached UEFI shell for $ARCH ($CACHED_SHELL)"
SHELL_SOURCE="$CACHED_SHELL"

# -----------------------------------------------------------------------------
# Mount Image and Setup ESP
# -----------------------------------------------------------------------------
# Attach the image and mount the ESP at /mnt
LOOPDEV=$(losetup --find --show --partscan "$IMG")
ESP="${LOOPDEV}p1"
mkdir -p /mnt
mount -t vfat "$ESP" /mnt
# clean up on exit
trap 'umount /mnt; losetup -d "$LOOPDEV"' EXIT

# -----------------------------------------------------------------------------
# Install UEFI Shell
# -----------------------------------------------------------------------------
# Stage the UEFI Shell as the fallback boot loader
echo "[ESP] staging $ARCH UEFI Shell as BOOT${UEFI_ID}.EFI"
mkdir -p /mnt/EFI/BOOT
cp "$SHELL_SOURCE" "/mnt/EFI/BOOT/BOOT${UEFI_ID}.EFI"
ls -al /mnt/EFI/BOOT/
echo "[ESP] staged BOOT${UEFI_ID}.EFI from $(basename "$SHELL_SOURCE")"

# Create Ubuntu directory structure (used later by import_rootfs.sh)
mkdir -p /mnt/EFI/UBUNTU

echo "[✓] ESP ready: fallback Shell for $ARCH installed as BOOT${UEFI_ID}.EFI"
