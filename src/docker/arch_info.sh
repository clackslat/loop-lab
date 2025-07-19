#!/usr/bin/env bash
#==============================================================================
# arch_info.sh  –  Single source of per-architecture metadata
#
# Every other script should   source "$(dirname "$0")/arch_info.sh"   and then
# read the associative arrays documented below.
#
# ───────────────────────────── Variables you will actually use ─────────────────
#   ARCH_LIST                 : list of supported architectures
#
#   ROOTFS_TAR[arch]          : cached debootstrap tarball for that arch
#
#   GRUB_TARGET[arch]         : argument for  grub-install --target
#   GRUB_PKG[arch]            : apt package that provides that grub-install
#
#   EFI_SHELL_PATH[arch]      : path to Shell.efi copied into the ESP
#
#   FW_CODE[arch]             : read-only AAVMF “code” firmware image
#   FW_VARS_TEMPLATE[arch]    : vendor-supplied blank vars.fd template
#   FW_VARS_WORK[arch]        : writable copy *in repo root* (git-ignored)
#
#   UEFI_ID[arch]             : two-letter suffix BOOT{ID}.EFI (AA64 / X64)
#
#  Optional arrays kept for reference (set but not yet consumed by any script):
#   PKG_CACHE_DIR[arch]
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
ARCH_LIST="x64 aarch64"  # Space-separated list of supported architectures

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
declare -A ROOTFS_TAR=(
  # x64 systems use amd64 Ubuntu rootfs
  [x64]="/rootfs-cache/amd64/rootfs.tar.xz"
  # aarch64 systems use arm64 Ubuntu rootfs
  [aarch64]="/rootfs-cache/arm64/rootfs.tar.xz"
)

###############################################################################
# GRUB Bootloader Configuration
###############################################################################
# These arrays define GRUB-related settings for each architecture:
#
# GRUB_TARGET: Specifies the EFI target architecture for GRUB installation
# - Used with grub-install --target to ensure proper EFI binary generation
#
# GRUB_PKG: Specifies the architecture-specific GRUB package to install
# - These packages provide the actual GRUB EFI binaries and tools
###############################################################################
declare -A GRUB_TARGET=(
  # x64: Standard UEFI PC target
  [x64]="x86_64-efi"
  # aarch64: ARM64 UEFI target
  [aarch64]="arm64-efi"
)
declare -A GRUB_PKG=(
  # x64: AMD64 GRUB EFI package
  [x64]="grub-efi-amd64"
  # aarch64: ARM64 GRUB EFI package
  [aarch64]="grub-efi-arm64"
)

###############################################################################
# UEFI Shell Configuration
###############################################################################
# EFI_SHELL_PATH maps architectures to their UEFI shell binary locations
# The UEFI shell serves as a fallback boot option and debugging tool
#
# These shells are typically downloaded from:
# https://github.com/pbatard/UEFI-Shell/releases
#
# Path convention:
# /work/assets/<arch>/Shell.efi where <arch> matches our architecture names
###############################################################################
declare -A EFI_SHELL_PATH=(
  # x64 UEFI shell binary location
  [x64]="/work/assets/x64/Shell.efi"
  # aarch64 UEFI shell binary location
  [aarch64]="/work/assets/aarch64/Shell.efi"
)

###############################################################################
# UEFI Firmware Configuration
###############################################################################
# These arrays define paths and settings for UEFI firmware components that
# are needed for testing and debugging the boot process.
#
# All paths are designed to work in both the build container and on macOS hosts
# for maximum compatibility during development and testing.
###############################################################################

# FW_CODE: Read-only UEFI firmware code images
# These provide the base UEFI implementation for each architecture
declare -A FW_CODE=(
  # x64: Standard PC UEFI implementation
  [x64]="/usr/share/qemu/edk2-x86_64-code.fd"
  # aarch64: ARM64 UEFI implementation
  [aarch64]="/usr/share/qemu/edk2-aarch64-code.fd"
)

# FW_VARS_TEMPLATE: Clean UEFI variable store templates
# These provide the starting point for UEFI variable storage
declare -A FW_VARS_TEMPLATE=(
  # x64: PC UEFI variable template
  [x64]="/usr/share/qemu/edk2-i386-vars.fd"
  # aarch64: ARM UEFI variable template
  [aarch64]="/usr/share/qemu/edk2-arm-vars.fd"
)

# FW_VARS_WORK: Working copies of UEFI variable stores
# These are created in the repository root and ignored by git
declare -A FW_VARS_WORK=(
  # x64: Working variable store
  [x64]="edk2-vars-x64.fd"
  # aarch64: Working variable store
  [aarch64]="edk2-vars-aarch64.fd"
)

###############################################################################
# UEFI Binary Naming
###############################################################################
# UEFI_ID defines the two-letter suffix used in the removable media boot path
# This follows the UEFI specification for architecture-specific boot files
# Example: BOOTX64.EFI or BOOTAA64.EFI in the ESP's /EFI/BOOT/ directory
###############################################################################
declare -A UEFI_ID=(
  # x64: Uses X64 suffix (BOOTX64.EFI)
  [x64]="X64"
  # aarch64: Uses AA64 suffix (BOOTAA64.EFI)
  [aarch64]="AA64"
)

