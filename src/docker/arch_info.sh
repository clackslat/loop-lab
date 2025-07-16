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

set -euo pipefail

###############################################################################
# Supported architectures
###############################################################################
ARCH_LIST="x64 aarch64"

###############################################################################
# rootfs tarballs
###############################################################################
declare -A ROOTFS_TAR=(
  [x64]="/rootfs-cache/amd64/rootfs.tar.xz"
  [aarch64]="/rootfs-cache/arm64/rootfs.tar.xz"
)

###############################################################################
# GRUB metadata
###############################################################################
declare -A GRUB_TARGET=(
  [x64]="x86_64-efi"
  [aarch64]="arm64-efi"
)
declare -A GRUB_PKG=(
  [x64]="grub-efi-amd64"
  [aarch64]="grub-efi-arm64"
)

###############################################################################
# UEFI Shell asset
###############################################################################
declare -A EFI_SHELL_PATH=(
  [x64]="/work/assets/x64/Shell.efi"
  [aarch64]="/work/assets/aarch64/Shell.efi"
)

###############################################################################
# Firmware paths  (work both inside the Ubuntu builder *and* on macOS)
###############################################################################
declare -A FW_CODE=(
  [x64]="/usr/share/qemu/edk2-x86_64-code.fd"
  [aarch64]="/usr/share/qemu/edk2-aarch64-code.fd"
)
declare -A FW_VARS_TEMPLATE=(
  [x64]="/usr/share/qemu/edk2-i386-vars.fd"
  [aarch64]="/usr/share/qemu/edk2-arm-vars.fd"
)
declare -A FW_VARS_WORK=(
  [x64]="edk2-vars-x64.fd"
  [aarch64]="edk2-vars-aarch64.fd"
)

# Two-letter file suffix for the removable-media fallback
declare -A UEFI_ID=(
  [x64]="X64"
  [aarch64]="AA64"
)

