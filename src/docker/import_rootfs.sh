#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# import_rootfs.sh – unpack rootfs, install kernel, then stage EFI-stub kernel +
#                    initrd, and decompress the .EFI stub if it’s still gzipped
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Environment Detection and Script Sourcing
# -----------------------------------------------------------------------------
# Determine if we're running inside Docker, under ShellCheck, or in local environment

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

# 3) Pick ARCH and image
ARCH=${1:-${ARCH:-x64}}
IMG="/work/template-${ARCH}.img"

# 4) Locate the rootfs tarball
# Use case statement instead of associative array for better ShellCheck compatibility
case "$ARCH" in
  "x64")
    TAR="/rootfs-cache/amd64/rootfs.tar.xz"
    ;;
  "aarch64")
    TAR="/rootfs-cache/arm64/rootfs.tar.xz"
    ;;
  *)
    echo "Error: Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

# Export for consistency with other scripts
export TAR

# 5) Attach image and identify partitions
# Loop devices are naturally isolated per architecture because:
# - Each Docker container has its own device namespace
# - Container privileges are limited to its own devices
# - Loop devices are automatically cleaned up on container exit
# - Each arch uses its own image file (template-${ARCH}.img)
LOOPDEV=$(losetup --find --show --partscan "$IMG")
ESP="${LOOPDEV}p1"
ROOT="${LOOPDEV}p2"

# 6) Mount filesystems
MOUNT_POINT="${MOUNT_POINT:-/mnt}"
mkdir -p "$MOUNT_POINT"
mount -t ext4  "$ROOT"      "$MOUNT_POINT"
mkdir -p     "$MOUNT_POINT/boot/efi"
mount -t vfat "$ESP"       "$MOUNT_POINT/boot/efi"

# ── ensure EFI/BOOT exists on the *mounted* ESP
mkdir -p "$MOUNT_POINT/boot/efi/EFI/BOOT"

# 7) Unpack rootfs
tar -xJpf "$TAR" -C "$MOUNT_POINT" --numeric-owner

# 8) Fix DNS in chroot
mkdir -p "$MOUNT_POINT/etc"
rm -f    "$MOUNT_POINT/etc/resolv.conf"
install -Dm644 /etc/resolv.conf "$MOUNT_POINT/etc/resolv.conf"
install -Dm644 /etc/hosts       "$MOUNT_POINT/etc/hosts"

# 9) Mount pseudo-filesystems for chroot
mkdir -p "$MOUNT_POINT/proc" "$MOUNT_POINT/sys" "$MOUNT_POINT/dev"
mount -t proc     proc     "$MOUNT_POINT/proc"
mount -t sysfs    sysfs    "$MOUNT_POINT/sys"
mount -t devtmpfs devtmpfs "$MOUNT_POINT/dev"
mkdir -p "$MOUNT_POINT/dev/pts"
mount -t devpts   devpts   "$MOUNT_POINT/dev/pts"

# Setup cleanup trap for all mounts and loop device
trap 'umount "$MOUNT_POINT/dev/pts" "$MOUNT_POINT/dev" "$MOUNT_POINT/sys" "$MOUNT_POINT/proc" "$MOUNT_POINT/boot/efi" "$MOUNT_POINT"; rmdir "$MOUNT_POINT"; losetup -d "$LOOPDEV"' EXIT

# 10) Chroot & install kernel + shim + iSCSI support
chroot "$MOUNT_POINT" /bin/bash -euox pipefail <<EOF
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y shim-signed linux-image-generic openssh-server sudo open-iscsi

# Create maintenance user with sudo access
useradd -m -s /bin/bash maintuser
echo "maintuser:maintpass" | chpasswd
usermod -aG sudo maintuser

# Configure sshd to allow password authentication
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Enable autologin for maintuser on console (architecture-specific)
mkdir -p /etc/systemd/system/getty@tty1.service.d/
cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<SYSTEMD
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin maintuser --noclear %I \$TERM
SYSTEMD
echo "$ARCH"
# Configure serial console autologin based on architecture
case "$ARCH" in
  "aarch64")
    # ARM64 uses ttyAMA0 for PL011 UART
    mkdir -p /etc/systemd/system/serial-getty@ttyAMA0.service.d/
    cat > /etc/systemd/system/serial-getty@ttyAMA0.service.d/autologin.conf <<ARMSYSTEMD
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin maintuser --keep-baud 115200,38400,9600 %I \$TERM
ARMSYSTEMD
    ;;
  "x64")
    # x86_64 uses ttyS0 for 16550 UART
    mkdir -p /etc/systemd/system/serial-getty@ttyS0.service.d/
    cat > /etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf <<X64SYSTEMD
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin maintuser --keep-baud 115200,38400,9600 %I \$TERM
X64SYSTEMD
    ;;
esac

# Enable SSH service on boot
systemctl enable ssh

# Configure iSCSI for boot support
# Enable open-iscsi service
systemctl enable open-iscsi

# Configure iSCSI initiator name (will be overridden by boot parameters)
echo "InitiatorName=iqn.1993-08.org.debian:01:$(hostname)" > /etc/iscsi/initiatorname.iscsi

# Configure iscsid for automatic startup
sed -i 's/^node.startup = manual/node.startup = automatic/' /etc/iscsi/iscsid.conf
sed -i 's/^node.leading_login = No/node.leading_login = Yes/' /etc/iscsi/iscsid.conf

# Add iSCSI modules to initramfs
echo "# iSCSI boot support modules" >> /etc/initramfs-tools/modules
echo "iscsi_tcp" >> /etc/initramfs-tools/modules
echo "libiscsi" >> /etc/initramfs-tools/modules
echo "scsi_transport_iscsi" >> /etc/initramfs-tools/modules
echo "iscsi_boot_sysfs" >> /etc/initramfs-tools/modules

# Ensure network drivers are included (common ones)
echo "# Network drivers for iSCSI boot" >> /etc/initramfs-tools/modules
echo "e1000e" >> /etc/initramfs-tools/modules
echo "igb" >> /etc/initramfs-tools/modules
echo "virtio_net" >> /etc/initramfs-tools/modules

# Add iSCSI tools to initramfs
echo "COPY_EXEC_LIST=\"/sbin/iscsiadm /sbin/iscsistart\"" >> /etc/initramfs-tools/conf.d/iscsi

# Configure root filesystem type to avoid fsck hook warnings
echo "FSTYPE=ext4" >> /etc/initramfs-tools/conf.d/fstype

# Update initramfs to include iSCSI support
update-initramfs -u -k all
EOF

# 11) Write fstab
ROOT_UUID=$(blkid -s UUID -o value "$ROOT")
EFI_UUID=$(blkid -s UUID -o value "$ESP")
cat > "$MOUNT_POINT/etc/fstab" <<EOF
UUID=$ROOT_UUID  /          ext4    defaults        0 1
UUID=$EFI_UUID   /boot/efi  vfat    umask=0077      0 1
EOF

# 12) Stage EFI-stub kernel & initrd
kernel_files=("$MOUNT_POINT/boot/vmlinuz-"*)
initrd_files=("$MOUNT_POINT/boot/initrd.img-"*)
(( ${#kernel_files[@]} )) || { echo "ERROR: no kernel image found" >&2; exit 1; }
(( ${#initrd_files[@]} )) || { echo "ERROR: no initrd image found" >&2; exit 1; }

KIMG=${kernel_files[0]##*/}
IIMG=${initrd_files[0]##*/}

cp "$MOUNT_POINT/boot/${KIMG}"    "$MOUNT_POINT/boot/efi/EFI/BOOT/${KIMG}"
cp "$MOUNT_POINT/boot/${IIMG}"    "$MOUNT_POINT/boot/efi/EFI/BOOT/"
ls -al "$MOUNT_POINT/boot/efi/EFI/BOOT/"
case "$ARCH" in
  # ── 64-bit Arm ──────────────────────────────────────────────────────────────
  aarch64)
    # 1) EFI stub is still gzipped: rename → decompress
    mv "$MOUNT_POINT/boot/efi/EFI/BOOT/${KIMG}" "$MOUNT_POINT/boot/efi/EFI/BOOT/${KIMG}.gz"
    gzip -d "$MOUNT_POINT/boot/efi/EFI/BOOT/${KIMG}.gz"

    # 2) Preferred console device for most PL011/virt QEMU boards
    #    ttyAMA0 is the first PL011; earlycon keeps the first printk lines
    CONSOLE_FLAGS="console=ttyAMA0,115200 earlycon=ttyAMA0,115200"
    ;;

  # ── 64-bit x86 (QEMU, KVM, bare-metal PCs) ─────────────────────────────────
  x64)
    # No image tweaking needed; bzImage is already EFI-bootable
    # Use the first 16550 UART exposed by QEMU/SeaBIOS/OVMF
    CONSOLE_FLAGS="console=ttyS0,115200 earlycon=ttyS0,115200"
    ;;


  # ── Catch-all ──────────────────────────────────────────────────────────────
  *)
    echo "ERROR: unsupported ARCH '$ARCH'" >&2
    exit 1
    ;;
esac
ls -al "$MOUNT_POINT/boot/efi/EFI/BOOT/"
# 16) Write a startup.nsh with iSCSI boot capability
ROOT_PARTUUID=$(blkid -s PARTUUID -o value "$ROOT")

# Base kernel command line with console and debugging
BASE_CMDLINE="rootfstype=ext4 rw rootwait ${CONSOLE_FLAGS} console=tty0 earlyprintk=efi,keep ignore_loglevel loglevel=8 debug initcall_debug efi=debug systemd.log_level=debug systemd.log_target=console"

# iSCSI boot parameters (commented examples for easy enabling)
ISCSI_PARAMS="# iSCSI boot parameters (uncomment and modify as needed):
# ip=dhcp
# iscsi_initiator=iqn.1993-08.org.debian:01:initiator
# iscsi_target_name=iqn.2023-01.com.example:target
# iscsi_target_ip=192.168.1.100
# iscsi_target_port=3260
# iscsi_lun=1
# root=UUID=\${ROOT_UUID} (for iSCSI root)
# rd.iscsi.initiator=iqn.1993-08.org.debian:01:initiator"

cat > "$MOUNT_POINT/boot/efi/EFI/BOOT/startup.nsh" <<EOF
@echo -off
echo "Loop-lab EFI Boot Script - iSCSI Ready"
echo "======================================"
echo "This image supports both local and iSCSI boot modes"
echo ""
echo "For local boot (current): Uses PARTUUID=${ROOT_PARTUUID}"
echo "For iSCSI boot: Modify kernel parameters below"
echo ""
${ISCSI_PARAMS}
echo ""
echo "Checking mapped devices..."
map -r
echo "Entering ESP filesystem..."
FS0:
cd EFI\BOOT
echo "Current directory contents:"
ls
echo ""
echo "Booting with local root (modify for iSCSI):"
echo "Command line: ${KIMG} initrd=\EFI\BOOT\\${IIMG} root=PARTUUID=${ROOT_PARTUUID} ${BASE_CMDLINE}"
echo ""
echo "Loading kernel..."
${KIMG} initrd=\EFI\BOOT\\${IIMG} root=PARTUUID=${ROOT_PARTUUID} ${BASE_CMDLINE}
EOF
chmod 0644 "$MOUNT_POINT/boot/efi/EFI/BOOT/startup.nsh"

# Create an iSCSI boot script template
cat > "$MOUNT_POINT/boot/efi/EFI/BOOT/iscsi-boot.nsh" <<EOF
@echo -off
echo "iSCSI Boot Script Template"
echo "=========================="
echo "Configure the variables below for your iSCSI environment"
echo ""
echo "Setting up for iSCSI boot..."
echo ""
echo "Example iSCSI boot command:"
echo "${KIMG} initrd=\EFI\BOOT\\${IIMG} ip=dhcp iscsi_initiator=iqn.1993-08.org.debian:01:initiator iscsi_target_name=iqn.2023-01.com.example:target iscsi_target_ip=192.168.1.100 iscsi_target_port=3260 iscsi_lun=1 root=/dev/sda2 ${BASE_CMDLINE}"
echo ""
echo "Modify this script with your iSCSI target details and uncomment the line below:"
echo "# ${KIMG} initrd=\EFI\BOOT\\${IIMG} [your-iscsi-parameters] ${BASE_CMDLINE}"
echo ""
echo "Falling back to local boot..."
${KIMG} initrd=\EFI\BOOT\\${IIMG} root=PARTUUID=${ROOT_PARTUUID} ${BASE_CMDLINE}
EOF
chmod 0644 "$MOUNT_POINT/boot/efi/EFI/BOOT/iscsi-boot.nsh"
ls -al "$MOUNT_POINT/boot/efi/EFI/BOOT/"
cat "$MOUNT_POINT/boot/efi/EFI/BOOT/startup.nsh"

# 14) Cleanup handled by EXIT trap
# umount "$MOUNT_POINT/dev/pts"
# umount "$MOUNT_POINT/dev"
# umount "$MOUNT_POINT/sys"
# umount "$MOUNT_POINT/proc"
# umount "$MOUNT_POINT/boot/efi"
# umount "$MOUNT_POINT"
# losetup -d "$LOOPDEV"

echo "[✓] import_rootfs complete: rootfs unpacked, kernel+initrd staged, EFI stub fixed, iSCSI support enabled"
echo "    - Local boot: startup.nsh (default)"
echo "    - iSCSI boot: iscsi-boot.nsh (template)"
echo "    - iSCSI modules and tools included in initramfs"
echo "    - open-iscsi service enabled for runtime iSCSI operations"
