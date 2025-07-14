#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Step 2-B  – unpack cached Ubuntu root-fs & install GRUB/shim
#  Usage:  import_rootfs.sh  x64 | aarch64
# ---------------------------------------------------------------------------
source /usr/local/lib/strict_trace.sh        # PS4 +  -xeuo pipefail

ARCH=${1:?need arch x64|aarch64}
IMG=/work/template.img                       # provided by earlier steps

# ── choose cached tarball + GRUB package -----------------------------------
if [[ $ARCH == aarch64 ]]; then
    TAR=/rootfs-cache/arm64/rootfs.tar.xz
    GRUB_PKG=grub-efi-arm64
else
    TAR=/rootfs-cache/amd64/rootfs.tar.xz
    GRUB_PKG=grub-efi-amd64
fi
KERNEL_PKG=linux-image-generic

# ── attach partitions -------------------------------------------------------
LOOP=$(losetup -f --show -P "$IMG")          # e.g. /dev/loop0
ROOT=${LOOP}p2
ESP=${LOOP}p1

mount "$ROOT" /mnt
mkdir -p /mnt/boot/efi
mount "$ESP"  /mnt/boot/efi

# ── unpack root-fs ----------------------------------------------------------
tar -xJ --numeric-owner -C /mnt -f "$TAR"

# minimal fstab
printf "%s / ext4 defaults 0 1\n%s /boot/efi vfat umask=0077 0 1\n" \
       "$ROOT" "$ESP" > /mnt/etc/fstab

# ── chroot to install kernel + GRUB ----------------------------------------
for d in /dev /dev/pts /proc /sys; do mount --bind "$d" /mnt"$d"; done
mkdir -p /mnt/run/systemd/resolve
cp /etc/resolv.conf /mnt/run/systemd/resolve/stub-resolv.conf
chroot /mnt bash -c "
  set -e
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive \
    apt-get install -y $GRUB_PKG shim-signed $KERNEL_PKG
  grub-install --target=${ARCH/x64/x86_64}-efi \
               --efi-directory=/boot/efi \
               --bootloader-id=UBUNTU
  update-grub
"

# ── clean-up ---------------------------------------------------------------
for d in /dev/pts /dev /proc /sys; do umount /mnt"$d"; done
umount /mnt/boot/efi
umount /mnt
losetup -d "$LOOP"

echo "[✓] rootfs populated and GRUB installed"
