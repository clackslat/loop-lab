#!/usr/bin/env bash
# Step-2A: prepare the EFI System Partition.
# Usage:   prep_esp.sh <arch>      # arch = x64  |  aarch64

# 1) fail fast
set -euo pipefail          # -e = exit on error, -u = exit on unset var, -o pipefail

# 2) readable trace
export PS4='[${BASH_SOURCE##*/}:${LINENO}] '
set -x                     # -x = trace each command with the PS4 prefix

ARCH=${1:?need arch x64|aarch64}
IMG=${IMG_PATH:-/work/template.img}
UEFI_ID=$( [[ $ARCH == x64 ]] && echo X64 || echo AA64 )
SHELL_EFI="/work/assets/$ARCH/Shell.efi"

echo "[ESP] installing ${SHELL_EFI##*/} for $ARCH"

# attach disk-image and expose its partitions
LOOP=$(losetup -f --show -P "$IMG")   # e.g. /dev/loop0 → loop0p1, loop0p2
ESP=${LOOP}p1

mount "$ESP" /mnt
mkdir -p /mnt/EFI/BOOT
cp "$SHELL_EFI" "/mnt/EFI/BOOT/BOOT${UEFI_ID}.EFI"   # default boot = Shell

mkdir -p /mnt/EFI/UBUNTU
echo "# placeholder – GRUB will overwrite" > /mnt/EFI/UBUNTU/grub.cfg

umount /mnt
losetup -d "$LOOP"
echo "[✓] ESP ready (Shell default, Ubuntu placeholder)"
