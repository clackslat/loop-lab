#!/usr/bin/env bash
# -------------------------------------------------------------
#  import_rootfs.sh – unpack root-fs, then install kernel+GRUB
#                     ONLINE (no .deb cache)
# -------------------------------------------------------------
source /usr/local/lib/strict_trace.sh
source /usr/local/lib/arch_info.sh

ARCH=${ARCH:-x64}
IMG=${IMG:-template.img}

# 1. attach loop device & mount partitions
LOOP=$(losetup -f --show -P "$IMG")
mount "${LOOP}p2" /mnt
mkdir -p /mnt/boot/efi
mount "${LOOP}p1" /mnt/boot/efi

# 2. unpack root-fs tarball
tar -xJpf "${ROOTFS_TAR[$ARCH]}" -C /mnt --numeric-owner

# 3. fstab
cat > /mnt/etc/fstab <<EOF
UUID=$(blkid -s UUID -o value "${LOOP}p2") /          ext4  defaults  0 1
UUID=$(blkid -s UUID -o value "${LOOP}p1") /boot/efi  vfat  umask=0077 0 2
EOF

# 4. bind pseudo-filesystems
for d in /dev /dev/pts /proc /sys; do
  mount --bind "$d" "/mnt$d"
done

# 5. **copy resolver from the tools container into the chroot**
mkdir -p /mnt/run/systemd/resolve
cp /etc/resolv.conf /mnt/run/systemd/resolve/stub-resolv.conf

# 6. install GRUB / kernel **online**
chroot /mnt bash -euo pipefail -c "
  apt-get update
  DEBIAN_FRONTEND=noninteractive \
    apt-get -y install ${GRUB_PKG[$ARCH]} shim-signed linux-image-generic
  grub-install --target=${GRUB_TARGET[$ARCH]} --efi-directory=/boot/efi --bootloader-id=UBUNTU
  update-grub
"

# 7. clean-up
for d in /dev/pts /dev /proc /sys; do umount "/mnt$d"; done
umount /mnt/boot/efi
umount /mnt
losetup -d "$LOOP"

echo '[✓] rootfs populated and GRUB installed'
