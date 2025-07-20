#!/usr/bin/env bash
#==============================================================================
# arch_info.sh  –  Architecture-specific Configuration
#
# Available Configuration Arrays:
#   ARCH_LIST                 : List of supported architectures (x64, aarch64)
#   ROOTFS_TAR[arch]          : Path to cached Ubuntu Noble rootfs tarball
#   EFI_SHELL_URL[arch]       : Download URL for UEFI shell binary
#   UEFI_ID[arch]             : Two-letter suffix for boot files (X64/AA64)
#==============================================================================

# Enable strict mode for safer execution
set -euo pipefail

###############################################################################
# Supported Architecture Configuration
###############################################################################
# ARCH_LIST defines the architectures that this build system supports.
# Current supported architectures:
# - x64: Standard 64-bit x86 architecture (also known as amd64/x86_64)
# - aarch64: 64-bit ARM architecture (also known as arm64)
###############################################################################
# Export for use in other scripts
export ARCH_LIST="x64 aarch64"  # Space-separated list of supported architectures

###############################################################################
# Root Filesystem Tarball Configuration
###############################################################################
# ROOTFS_TAR maps each architecture to the path of its root filesystem tarball
# within the build container. These tarballs are downloaded during container
# build and contain the base Ubuntu Noble system for each architecture.
#
# Path format: /rootfs-cache/<deb-arch>/rootfs.tar.xz
# where <deb-arch> is the Debian architecture name (amd64/arm64)
###############################################################################
# Exported for use in build scripts
declare -A ROOTFS_TAR
ROOTFS_TAR=(
  # x64 systems use amd64 Ubuntu rootfs
  [x64]="/rootfs-cache/amd64/rootfs.tar.xz"
  # aarch64 systems use arm64 Ubuntu rootfs
  [aarch64]="/rootfs-cache/arm64/rootfs.tar.xz"
)
# Export for use in other scripts
export ROOTFS_TAR

###############################################################################
# UEFI Shell Configuration
###############################################################################
# EFI_SHELL_URL maps architectures to their UEFI shell download URLs.
# The shells are downloaded directly into the ESP as fallback boot options.
###############################################################################
# Define array for shell URLs
declare -A EFI_SHELL_URL
EFI_SHELL_URL=(
  # x64 UEFI shell download URL
  [x64]="https://github.com/pbatard/UEFI-Shell/releases/download/25H1/shellx64.efi"
  # aarch64 UEFI shell download URL
  [aarch64]="https://github.com/pbatard/UEFI-Shell/releases/download/25H1/shellaa64.efi"
)
# Export for use in other scripts
export EFI_SHELL_URL

###############################################################################
# UEFI Binary Naming
###############################################################################
# UEFI_ID defines the two-letter suffix used in the removable media boot path
# This follows the UEFI specification for architecture-specific boot files
# Example: BOOTX64.EFI or BOOTAA64.EFI in the ESP's /EFI/BOOT/ directory
###############################################################################
# Define array for UEFI IDs
declare -A UEFI_ID
UEFI_ID=(
  # x64: Uses X64 suffix (BOOTX64.EFI)
  [x64]="X64"
  # aarch64: Uses AA64 suffix (BOOTAA64.EFI)
  [aarch64]="AA64"
)
# Export for use in other scripts
export UEFI_ID
