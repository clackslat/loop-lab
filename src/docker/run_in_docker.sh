#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# run_in_docker.sh – entry point for building the loop-lab disk images
#
# 1. loads strict mode + tracing      (strict_trace.sh)
# 2. loads per-arch metadata         (arch_info.sh)
# 3. ensures a writable vars.fd      (one per ARCH, git-ignored)
# 4. (re)builds the disk-tools Docker
# 5. runs the three build stages
#
# Usage:
#   ARCH=aarch64 ./src/docker/run_in_docker.sh
#   ARCH=x64     ./src/docker/run_in_docker.sh
# ---------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# 0. Strict mode + tracing
# -----------------------------------------------------------------------------
source "$(dirname "$0")/strict_trace.sh"

# -----------------------------------------------------------------------------
# 1. Load per-arch metadata
# -----------------------------------------------------------------------------
source "$(dirname "$0")/arch_info.sh"
ARCH=${ARCH:-aarch64}

# sanity-check
if [[ ! " ${ARCH_LIST} " =~ " ${ARCH} " ]]; then
  echo "ERROR: unsupported ARCH='${ARCH}' (supported: ${ARCH_LIST})" >&2
  exit 1
fi

# raw values from arch_info.sh
_primary_code=${FW_CODE[$ARCH]}
_primary_vars=${FW_VARS_TEMPLATE[$ARCH]}
VARS_COPY=${FW_VARS_WORK[$ARCH]}
UEFI_ID=${UEFI_ID[$ARCH]}

# -----------------------------------------------------------------------------
# 2. Resolve “code.fd” and “vars.fd” template paths with fallback
# -----------------------------------------------------------------------------
# For each, if the primary path exists, use it; otherwise try Homebrew’s prefix.
# basename() ensures we only change the directory.

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

#  5.3 – import rootfs & install GRUB (writes into $VARS_COPY)
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
