#!/usr/bin/env bash
# =============================================================================
# EFI System Partition Preparation Script (prep_esp.sh)
# =============================================================================
# Purpose:
#   Downloads and installs the appropriate UEFI Shell for the target
#   architecture into the EFI System Partition (ESP). The UEFI Shell acts as
#   a fallback boot option and debugging tool.
#
# Environment:
#   - Runs inside the disk-tools Docker container
#   - Expects ESP to be mounted at /mnt
#   - Requires network access to download UEFI shell binaries
#
# Dependencies:
#   - strict_trace.sh: Provides shell safety settings and tracing
#   - arch_info.sh: Provides architecture-specific configuration
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
# Script Setup and Configuration
# -----------------------------------------------------------------------------
# Import safety settings and tracing configuration
source "$(dirname "${BASH_SOURCE[0]}")/strict_trace.sh"
# Log script directory for debugging
echo "$(dirname "${BASH_SOURCE[0]}")"

# -----------------------------------------------------------------------------
# Architecture Configuration
# -----------------------------------------------------------------------------
# Import architecture-specific settings
source "$(dirname "${BASH_SOURCE[0]}")/arch_info.sh"

# Set target architecture (default to x64 if not specified)
ARCH=${1:-${ARCH:-x64}}
# Define image path based on architecture
IMG="/work/template-${ARCH}.img"

# -----------------------------------------------------------------------------
# Get the UEFI Shell download URL from arch_info.sh configuration
# -----------------------------------------------------------------------------
URL="${EFI_SHELL_URL[$ARCH]}"
ID="${UEFI_ID[$ARCH]}"             # X64 or AA64
# 2. Attach the image and mount the ESP at /mnt
LOOPDEV=$(losetup --find --show --partscan "$IMG")
ESP="${LOOPDEV}p1"
mkdir -p /mnt
mount -t vfat "$ESP" /mnt
# clean up on exit
trap 'umount /mnt; losetup -d "$LOOPDEV"' EXIT

# 6. Fetch and stage the single-shell fallback loader
echo "[ESP] fetching $ARCH UEFI Shell from $URL"
mkdir -p /mnt/EFI/BOOT
curl -fsSL "$URL" -o "/mnt/EFI/BOOT/BOOT${ID}.EFI"
ls -al /mnt/EFI/BOOT/
echo "[ESP] staged BOOT${ID}.EFI"

# 7. Leave the Ubuntu stub (will be overwritten by import_rootfs.sh)
mkdir -p /mnt/EFI/UBUNTU
#cat > /mnt/EFI/UBUNTU/grub.cfg <<'EOF'
# placeholder — import_rootfs.sh will overwrite this with GRUB’s config
#EOF

echo "[✓] ESP ready: fallback Shell placeholder for $ARCH installed as BOOT${ID}.EFI"
