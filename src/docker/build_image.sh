#!/usr/bin/env bash
# =============================================================================
# Disk Image Creation Script (build_image.sh)
# =============================================================================
# Purpose:
#   Creates a blank disk image with properly configured EFI System Partition
#   (ESP) and root partition. This forms the base for our bootable system
#   images.
#
# Environment:
#   - Can run directly on Linux systems with appropriate tools
#   - Typically run inside the disk-tools container
#   - Requires root or appropriate loop device permissions
#
# Usage:
#   ARCH=<arch> IMG_SIZE=<size> ./build_image.sh
#   Examples:
#     ARCH=x64 IMG_SIZE=20G ./build_image.sh
#     ARCH=aarch64 ./build_image.sh
# =============================================================================

# Import strict mode settings and tracing configuration
source /usr/local/lib/strict_trace.sh

# -----------------------------------------------------------------------------
# Configuration Variables
# -----------------------------------------------------------------------------
# ARCH: Target architecture (defaults to x64 if not specified)
ARCH=${ARCH:-x64}

# Image path and size configuration
# - Creates architecture-specific image names (e.g., template-x64.img)
# - Default image size of 10G can be overridden via IMG_SIZE environment variable
IMG_PATH=template-${ARCH}.img
IMG_SIZE="${IMG_SIZE:-10G}"


# -----------------------------------------------------------------------------
# Image File Creation
# -----------------------------------------------------------------------------
# Create an empty file of specified size using truncate
# This is faster than dd and doesn't require writing zeros
truncate -s "$IMG_SIZE" "$IMG_PATH"

# -----------------------------------------------------------------------------
# Loop Device Setup
# -----------------------------------------------------------------------------
# Attach the image file to a loop device for block device operations
# - --find: Automatically find an unused loop device
# - --show: Print the assigned device name
# - --partscan: Scan for partitions after setup
if ! LOOPDEV=$(losetup --find --show --partscan "$IMG_PATH"); then
  echo "[warn] No free loop devices; opening shell for inspection."
fi

# Ensure loop device is detached on script exit
trap 'losetup -d "$LOOPDEV"' EXIT

# -----------------------------------------------------------------------------
# Partition Layout Creation
# -----------------------------------------------------------------------------
# Create a fresh GPT partition table and define partitions
#
# 1. Clear any existing partition table
sgdisk --zap-all "$LOOPDEV"

# 2. Create ESP (EFI System Partition)
#    - Size: 512MB (generous for multiple kernels/initrds)
#    - Type: EF00 (EFI System Partition)
#    - Label: EFI
sgdisk -n1:0:+512M -t1:EF00 -c1:EFI  "$LOOPDEV"

# 3. Create root partition
#    - Size: Remaining space
#    - Type: 8300 (Linux filesystem)
#    - Label: root
sgdisk -n2:0:0      -t2:8300 -c2:root "$LOOPDEV"

# Note: --partscan in losetup already triggers partition device creation


# -----------------------------------------------------------------------------
# Filesystem Creation
# -----------------------------------------------------------------------------
# 1. Format ESP (partition 1) as FAT32
#    - Required by UEFI specification
#    - Universally readable across operating systems
mkfs.vfat -F32 "${LOOPDEV}p1"

# 2. Format root partition (partition 2) as ext4
#    - Modern Linux filesystem with journaling
#    - Good balance of features and performance
mkfs.ext4        "${LOOPDEV}p2"

# -----------------------------------------------------------------------------
# Completion
# -----------------------------------------------------------------------------
echo "[info] $IMG_PATH created and formatted."
# Loop device cleanup handled by EXIT trap
