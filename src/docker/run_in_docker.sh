#!/usr/bin/env bash
#==============================================================================
# run_in_docker.sh – entry point for building the loop-lab disk images
#
# 1. loads strict mode + tracing      (strict_trace.sh)
# 2. loads per-arch metadata         (arch_info.sh)
# 3. (re)builds the disk-tools Docker
# 4. runs the build stages:
#    - build_image.sh: create and partition disk image
#    - prep_esp.sh: setup EFI system partition with shell
#    - import_rootfs.sh: install root filesystem
#
# Usage:
#   ARCH=aarch64 ./src/docker/run_in_docker.sh
#   ARCH=x64     ./src/docker/run_in_docker.sh
#==============================================================================

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

SCRIPT_DIR="$(dirname "$0")"

# 0. Strict mode + tracing
safe_source "${SCRIPT_DIR}/strict_trace.sh"

# -----------------------------------------------------------------------------
# 1. Load per-arch metadata
# -----------------------------------------------------------------------------
safe_source "${SCRIPT_DIR}/arch_info.sh"
ARCH=${ARCH:-aarch64}

# sanity-check
# shellcheck disable=SC2076
# Note: Quoting right-hand side is intentional to match the ARCH string literally, not as regex
if [[ ! " ${ARCH_LIST} " =~ " ${ARCH} " ]]; then
  echo "ERROR: unsupported ARCH='${ARCH}' (supported: ${ARCH_LIST})" >&2
  exit 1
fi

# Get the UEFI ID for this architecture (e.g., X64 or AA64)
# Use a safer approach with direct mapping for simplicity
case "$ARCH" in
  x64)
    UEFI_ID="X64"
    ;;
  aarch64)
    UEFI_ID="AA64"
    ;;
  *)
    echo "ERROR: Unknown architecture '$ARCH', cannot determine UEFI_ID" >&2
    exit 1
    ;;
esac

# Export UEFI_ID for use in other scripts
export UEFI_ID

# -----------------------------------------------------------------------------
# 4. Build the disk-tools Docker image
# -----------------------------------------------------------------------------
IMAGE=loop-lab-disktools
docker build -t "$IMAGE" -f src/docker/Dockerfile src/docker

# -----------------------------------------------------------------------------
# 5. Run the three build stages
# -----------------------------------------------------------------------------
# Parallel execution considerations:
# 1. Mount points:
#    - Each architecture needs its own mount point to avoid conflicts
#    - MOUNT_POINT env var is used by build scripts to isolate filesystems
#    - Format: /mnt_${ARCH} ensures unique paths (e.g., /mnt_x64, /mnt_aarch64)
#
# 2. Resource isolation:
#    - Each container gets its own:
#      - Loop devices (via --privileged)
#      - Mount namespace
#      - Filesystem mounts
#    - Prevents cross-architecture interference
#
# 3. Environment variables:
#    -e ARCH         : Tells build scripts which architecture to target
#    -e MOUNT_POINT  : Provides architecture-specific mount point
#                      Used by build_image.sh, prep_esp.sh, and import_rootfs.sh
#                      to avoid conflicts in parallel builds
#
# 4. Volume mounts:
#    -v /dev:/dev    : Required for loop device access
#    -v $(pwd):/work : Makes workspace available inside container
# -----------------------------------------------------------------------------

#  5.1 – make template.img + partition
docker run --rm --privileged \
  -v /dev:/dev \
  -v "$(pwd)":/work -w /work \
  -e ARCH="$ARCH" \
  -e MOUNT_POINT="/mnt_${ARCH}" \
  --entrypoint /work/src/docker/build_image.sh "$IMAGE"

# 5.2 – stage UEFI Shell fallback (BOOTX64/AA64.EFI) on the ESP
# Each container maintains isolation through:
# - Unique mount points from MOUNT_POINT env var
# - Independent loop device allocation
# - Separate filesystem namespace
docker run --rm --privileged \
  -v /dev:/dev \
  -v "$(pwd)":/work -w /work \
  -e ARCH="$ARCH" \
  -e MOUNT_POINT="/mnt_${ARCH}" \
  --entrypoint /work/src/docker/prep_esp.sh "$IMAGE"

# 5.3 – import Ubuntu root filesystem
# Final stage uses same isolation mechanisms:
# - Architecture-specific mount point
# - Independent device management
# - Clean unmounting handled by container exit
docker run --rm --privileged \
  -v /dev:/dev \
  -v "$(pwd)":/work -w /work \
  -e ARCH="$ARCH" \
  -e MOUNT_POINT="/mnt_${ARCH}" \
  --entrypoint /work/src/docker/import_rootfs.sh "$IMAGE"
