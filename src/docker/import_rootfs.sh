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

# Function to safely source scripts with environment awareness
safe_source() {
  local script_path="$1"
  local script_name
  script_name=$(basename "$script_path")
  
  if [ -f "$script_path" ]; then
    # File exists, source it directly
    # shellcheck disable=SC1090
    . "$script_path"
  elif in_docker; then
    # We're in Docker but file doesn't exist - this shouldn't happen
    echo "Error: Expected Docker script $script_path not found" >&2
    exit 1
  else
    # We're running in a non-Docker environment (local or CI)
    # Set up equivalent functionality for the specific script
    case "$script_name" in
      strict_trace.sh)
        # Apply strict mode settings that would be in strict_trace.sh
        set -euo pipefail
        export PS4='[$(printf "%(%H:%M:%S)T" -1)] ${BASH_SOURCE##*/}:${LINENO}> '
        ;;
      arch_info.sh)
        # Define minimal arch info variables for local testing
        export ARCH_LIST="x64 aarch64"
        
        # Define and populate associative arrays with minimum required data
        declare -A ROOTFS_TAR
        ROOTFS_TAR=([x64]="/rootfs-cache/amd64/rootfs.tar.xz" [aarch64]="/rootfs-cache/arm64/rootfs.tar.xz")
        export ROOTFS_TAR
        
        declare -A EFI_SHELL_URL
        EFI_SHELL_URL=([x64]="https://example.com/shellx64.efi" [aarch64]="https://example.com/shellaa64.efi")
        export EFI_SHELL_URL
        
        declare -A UEFI_ID
        UEFI_ID=([x64]="X64" [aarch64]="AA64")
        export UEFI_ID
        ;;
      *)
        # For other scripts, just report they're being skipped
        echo "Notice: $script_path not found, running in non-Docker environment" >&2
        ;;
    esac
  fi
}

# 1) Source strict mode & tracing with environment awareness
safe_source "/usr/local/lib/strict_trace.sh"

# 2) Source per-arch metadata with environment awareness
safe_source "/usr/local/lib/arch_info.sh"

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

# 10) Chroot & install kernel + shim
chroot "$MOUNT_POINT" /bin/bash -euo pipefail <<EOF
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y shim-signed linux-image-generic
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
  x64|amd64|x86_64)
    # No image tweaking needed; bzImage is already EFI-bootable
    # Use the first 16550 UART exposed by QEMU/SeaBIOS/OVMF
    CONSOLE_FLAGS="console=ttyS0,115200 earlycon=ttyS0,115200"
    ;;

  # ── (Optional) RISC-V example to show how you’d extend it ─────────────────
  riscv64)
    # Kernel image is fine; just pick the usual SiFive UART
    CONSOLE_FLAGS="console=ttySIF0,115200 earlycon"
    ;;

  # ── Catch-all ──────────────────────────────────────────────────────────────
  *)
    echo "ERROR: unsupported ARCH '$ARCH'" >&2
    exit 1
    ;;
esac
ls -al "$MOUNT_POINT/boot/efi/EFI/BOOT/"
# 16) **NEW** — write a startup.nsh so EDK2 auto-boots your stub
ROOT_PARTUUID=$(blkid -s PARTUUID -o value "$ROOT")
CMDLINE="root=PARTUUID=${ROOT_PARTUUID} rootfstype=ext4 rw rootwait ${CONSOLE_FLAGS} console=tty0 earlyprintk=efi,keep ignore_loglevel loglevel=8 debug initcall_debug efi=debug systemd.log_level=debug systemd.log_target=console"
cat > "$MOUNT_POINT/boot/efi/EFI/BOOT/startup.nsh" <<EOF
@echo -off
echo "Checking mapped devices..."
map -r
echo "Entering ESP filesystem..."
FS0:
cd EFI\BOOT
echo "Current directory contents:"
ls
echo "Command line:"
echo "${KIMG} initrd=\EFI\BOOT\\${IIMG} ${CMDLINE}"
echo "Loading kernel..."
${KIMG} initrd=\EFI\BOOT\\${IIMG} ${CMDLINE}
EOF
chmod 0644 "$MOUNT_POINT/boot/efi/EFI/BOOT/startup.nsh"
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

echo "[✓] import_rootfs complete: rootfs unpacked, kernel+initrd staged, EFI stub fixed"
