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

# -----------------------------------------------------------------------------
# Environment Detection and Script Sourcing
# -----------------------------------------------------------------------------
# Determine if we're running inside Docker, under ShellCheck, or in local environment
# This approach handles different runtime environments gracefully

# Function to detect Docker environment
in_docker() {
  # Check for .dockerenv file
  [ -f /.dockerenv ] && return 0
  # Check for docker in cgroup
  grep -q docker /proc/self/cgroup 2>/dev/null && return 0
  # Not in Docker
  return 1
}

# Source scripts based on environment
# shellcheck disable=SC1090,SC1091
if in_docker; then
  # 1) Source strict mode & tracing
  . "/usr/local/lib/strict_trace.sh"
  # 2) Source per-arch metadata
  . "/usr/local/lib/arch_info.sh"
else
  # 1) Source strict mode & tracing
  . "$(dirname "${BASH_SOURCE[0]}")/strict_trace.sh"
  # 2) Source per-arch metadata
  . "$(dirname "${BASH_SOURCE[0]}")/arch_info.sh"
fi
# Enable shellcheck info codes after the if/else statement
# shellcheck enable=all
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
  echo "[error] Failed to allocate loop device" >&2
  exit 1
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
