#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  import_rootfs.sh – unpack Noble root-fs tarball, then install kernel+GRUB
#                     (packages fetched online, values read from arch_info.sh)
# ---------------------------------------------------------------------------
source /usr/local/lib/strict_trace.sh    # PS4 + set -euo pipefail
source /usr/local/lib/arch_info.sh       # gives ROOTFS_TAR, GRUB_PKG, GRUB_TARGET …

ARCH=${1:-${ARCH:-x64}}                  # allow CLI or env override
IMG=/work/template-${ARCH}.img
# ── look up everything in a single place ------------------------------------
TAR=${ROOTFS_TAR[$ARCH]}
GRUB=${GRUB_PKG[$ARCH]}
TARGET=${GRUB_TARGET[$ARCH]}

# ── 1. attach image & mount partitions --------------------------------------
LOOP=$(losetup -f --show -P "$IMG")
mount "${LOOP}p2" /mnt
mkdir -p /mnt/boot/efi
mount "${LOOP}p1" /mnt/boot/efi

# ── 2. unpack root-fs -------------------------------------------------------
tar -xJpf "$TAR" -C /mnt --numeric-owner

# ── 3. write fstab ----------------------------------------------------------
cat > /mnt/etc/fstab <<EOF
UUID=$(blkid -s UUID -o value "${LOOP}p2") /          ext4  defaults  0 1
UUID=$(blkid -s UUID -o value "${LOOP}p1") /boot/efi  vfat  umask=0077 0 2
EOF

# ── 4. bind pseudo-filesystems + resolver -----------------------------------
for d in /dev /dev/pts /proc /sys; do mount --bind "$d" "/mnt$d"; done
mkdir -p /mnt/run/systemd/resolve
cp /etc/resolv.conf /mnt/run/systemd/resolve/stub-resolv.conf 

# ── 5. chroot: install kernel & GRUB ----------------------------------------
chroot /mnt bash -euo pipefail -c "
  apt-get update
  DEBIAN_FRONTEND=noninteractive \
    apt-get -y install $GRUB shim-signed linux-image-generic

  grub-install \
      --target=$TARGET \
      --efi-directory=/boot/efi \
      --bootloader-id=UBUNTU \
      --no-nvram \
      --removable

  update-grub
"

# ── 6. clean-up -------------------------------------------------------------
for d in /dev/pts /dev /proc /sys; do umount "/mnt$d"; done
umount /mnt/boot/efi
umount /mnt
losetup -d "$LOOP"

echo '[✓] rootfs populated and GRUB installed'
