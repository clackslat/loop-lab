#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# import_rootfs.sh – unpack rootfs, install kernel, then stage EFI-stub kernel +
#                    initrd, and decompress the .EFI stub if it’s still gzipped
# -----------------------------------------------------------------------------

# 1) Strict mode & tracing
source /usr/local/lib/strict_trace.sh

# 2) Per-arch metadata
source /usr/local/lib/arch_info.sh

# 3) Pick ARCH and image
ARCH=${1:-${ARCH:-x64}}
IMG="/work/template-${ARCH}.img"

# 4) Locate the rootfs tarball
TAR="${ROOTFS_TAR[$ARCH]}"

# 5) Attach image and identify partitions
LOOPDEV=$(losetup --find --show --partscan "$IMG")
ESP="${LOOPDEV}p1"
ROOT="${LOOPDEV}p2"

# 6) Mount filesystems
mount -t ext4  "$ROOT"      /mnt
mkdir -p     /mnt/boot/efi
mount -t vfat "$ESP"       /mnt/boot/efi

# ── ensure EFI/BOOT exists on the *mounted* ESP
mkdir -p /mnt/boot/efi/EFI/BOOT

# 7) Unpack rootfs
tar -xJpf "$TAR" -C /mnt --numeric-owner

# 8) Fix DNS in chroot
mkdir -p /mnt/etc
rm -f    /mnt/etc/resolv.conf
install -Dm644 /etc/resolv.conf /mnt/etc/resolv.conf
install -Dm644 /etc/hosts       /mnt/etc/hosts

# 9) Mount pseudo-filesystems for chroot
mount -t proc     proc     /mnt/proc
mount -t sysfs    sysfs    /mnt/sys
mount -t devtmpfs devtmpfs /mnt/dev
mkdir -p /mnt/dev/pts
mount -t devpts   devpts   /mnt/dev/pts

# 10) Chroot & install kernel + shim
chroot /mnt /bin/bash -euo pipefail <<EOF
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y shim-signed linux-image-generic
EOF

# 11) Write fstab
ROOT_UUID=$(blkid -s UUID -o value "$ROOT")
EFI_UUID=$(blkid -s UUID -o value "$ESP")
cat > /mnt/etc/fstab <<EOF
UUID=$ROOT_UUID  /          ext4    defaults        0 1
UUID=$EFI_UUID   /boot/efi  vfat    umask=0077      0 1
EOF

# 12) Stage EFI-stub kernel & initrd
ID="${UEFI_ID[$ARCH]}"

kernel_files=(/mnt/boot/vmlinuz-*)
initrd_files=(/mnt/boot/initrd.img-*)
(( ${#kernel_files[@]} )) || { echo "ERROR: no kernel image found" >&2; exit 1; }
(( ${#initrd_files[@]} )) || { echo "ERROR: no initrd image found" >&2; exit 1; }

KIMG=${kernel_files[0]##*/}
IIMG=${initrd_files[0]##*/}

cp "/mnt/boot/${KIMG}"    "/mnt/boot/efi/EFI/BOOT/${KIMG}"
cp "/mnt/boot/${IIMG}"    "/mnt/boot/efi/EFI/BOOT/"
ls -al /mnt/boot/efi/EFI/BOOT/
case "$ARCH" in
  aarch64)
    mv "/mnt/boot/efi/EFI/BOOT/${KIMG}" "/mnt/boot/efi/EFI/BOOT/${KIMG}.gz"
    gzip -d "/mnt/boot/efi/EFI/BOOT/${KIMG}.gz"
    ;;
esac
ls -al /mnt/boot/efi/EFI/BOOT/
# 16) **NEW** — write a startup.nsh so EDK2 auto-boots your stub
ROOT_PARTUUID=$(blkid -s PARTUUID -o value "$ROOT")
cat > /mnt/boot/efi/EFI/BOOT/startup.nsh <<EOF
FS0:
cd EFI\\BOOT
${KIMG} root=PARTUUID=${ROOT_PARTUUID} ro console=ttyAMA0
EOF
chmod 0644 /mnt/boot/efi/EFI/BOOT/startup.nsh
ls -al /mnt/boot/efi/EFI/BOOT/
cat /mnt/boot/efi/EFI/BOOT/startup.nsh
# 14) Cleanup mounts & detach
umount /mnt/dev/pts
umount /mnt/dev
umount /mnt/sys
umount /mnt/proc
umount /mnt/boot/efi
umount /mnt
losetup -d "$LOOPDEV"

echo "[✓] import_rootfs complete: rootfs unpacked, kernel+initrd staged, EFI stub fixed"
