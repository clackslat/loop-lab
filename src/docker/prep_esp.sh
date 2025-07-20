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
        echo "Notice: $script_path not found, running in non-Docker environment" >&2
        ;;
    esac
  fi
}

# Get the script directory
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Import safety settings and tracing configuration
safe_source "${SCRIPT_DIR}/strict_trace.sh"

# Log script directory for debugging
echo "${SCRIPT_DIR}"

# -----------------------------------------------------------------------------
# Architecture Configuration
# -----------------------------------------------------------------------------
# Import architecture-specific settings
safe_source "${SCRIPT_DIR}/arch_info.sh"

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
