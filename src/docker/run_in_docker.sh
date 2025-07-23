#!/usr/bin/env bash
#==============================================================================
# run_in_docker.sh – entry point for building the loop-lab disk images
#
# 1. loads strict mode + tracing      (strict_trace.sh)
# 2. loads external resources config  (external_resources.sh via load_scripts.sh)
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
# Script Sourcing
# -----------------------------------------------------------------------------
# This script always runs on the host, so use local paths
# Load common scripts from same directory
. "$(dirname "${BASH_SOURCE[0]}")/load_scripts.sh"

ARCH=${ARCH:-aarch64}

# sanity-check using external resources
ARCH_LIST=$(get_arch_list)
# shellcheck disable=SC2076
# Note: Quoting right-hand side is intentional to match the ARCH string literally, not as regex
if [[ ! " ${ARCH_LIST} " =~ " ${ARCH} " ]]; then
  echo "ERROR: unsupported ARCH='${ARCH}' (supported: ${ARCH_LIST})" >&2
  exit 1
fi

# Get the UEFI ID for this architecture using external resources
UEFI_ID=$(get_uefi_id "$ARCH")

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
