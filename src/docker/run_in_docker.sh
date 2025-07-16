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
#  5.1 – make template.img + partition
docker run --rm --privileged \
  -v /dev:/dev \
  -v "$(pwd)":/work -w /work \
  -e ARCH="$ARCH" \
  --entrypoint /work/src/docker/build_image.sh "$IMAGE"

# 5.2 – stage UEFI Shell fallback (BOOTX64/AA64.EFI) on the ESP
docker run --rm --privileged \
  -v /dev:/dev \
  -v "$(pwd)":/work -w /work \
  -e ARCH="$ARCH" \
  --entrypoint /work/src/docker/prep_esp.sh "$IMAGE"

#  5.3 – import rootfs & install GRUB (writes into $VARS_COPY)
docker run --rm --privileged \
  -v /dev:/dev \
  -v "$(pwd)":/work -w /work \
  -e ARCH="$ARCH" \
  --entrypoint /work/src/docker/import_rootfs.sh "$IMAGE"
