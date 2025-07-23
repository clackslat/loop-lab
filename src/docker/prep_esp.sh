#!/usr/bin/env bash
# =============================================================================
# EFI System Partition Preparation Script (prep_esp.sh)
# =============================================================================
# Purpose:
#   Downloads and installs the appropriate UEFI Shell for the target
#   architecture into the EFI System Partition (ESP). The UEFI Shell acts as
#   a fallback boot option and debugging tool.
#
# Environment:
#   - Runs inside the disk-tools Docker container
#   - Expects ESP to be mounted at /mnt
#   - Requires network access to download UEFI shell binaries
#
# Dependencies:
#   - strict_trace.sh: Provides shell safety settings and tracing
#   - arch_info.sh: Provides architecture-specific configuration
#
# Usage:
#   ARCH=<arch> ./prep_esp.sh
#   Example: ARCH=aarch64 ./prep_esp.sh
#
# Note:
#   This script is typically called by run_in_docker.sh rather than
#   being invoked directly.
# =============================================================================
# -----------------------------------------------------------------------------
# Environment Detection and Script Sourcing
# -----------------------------------------------------------------------------
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
# -----------------------------------------------------------------------------

# Set target architecture (default to x64 if not specified)
ARCH=${1:-${ARCH:-x64}}
# Define image path based on architecture
IMG="/work/template-${ARCH}.img"

# -----------------------------------------------------------------------------
# Get the UEFI Shell download URL from arch_info.sh configuration
# -----------------------------------------------------------------------------
# Use case statement for UEFI_ID instead of associative array for better ShellCheck compatibility
case "$ARCH" in
    "x64")
        URL="https://github.com/pbatard/UEFI-Shell/releases/download/25H1/shellx64.efi"
        ID="X64"
        ;;
    "aarch64")
        URL="https://github.com/pbatard/UEFI-Shell/releases/download/25H1/shellaa64.efi"
        ID="AA64"
        ;;
    *)
        echo "Error: Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Export variables for use in other scripts
export URL ID
# 2. Attach the image and mount the ESP at /mnt
LOOPDEV=$(losetup --find --show --partscan "$IMG")
ESP="${LOOPDEV}p1"
mkdir -p /mnt
mount -t vfat "$ESP" /mnt
# clean up on exit
trap 'umount /mnt; losetup -d "$LOOPDEV"' EXIT

# 6. Fetch and stage the single-shell fallback loader
echo "[ESP] fetching $ARCH UEFI Shell from $URL"
mkdir -p /mnt/EFI/BOOT
curl -fsSL "$URL" -o "/mnt/EFI/BOOT/BOOT${ID}.EFI"
ls -al /mnt/EFI/BOOT/
echo "[ESP] staged BOOT${ID}.EFI"

# 7. Leave the Ubuntu stub (will be overwritten by import_rootfs.sh)
mkdir -p /mnt/EFI/UBUNTU
#cat > /mnt/EFI/UBUNTU/grub.cfg <<'EOF'
# placeholder — import_rootfs.sh will overwrite this with GRUB’s config
#EOF

echo "[✓] ESP ready: fallback Shell placeholder for $ARCH installed as BOOT${ID}.EFI"
