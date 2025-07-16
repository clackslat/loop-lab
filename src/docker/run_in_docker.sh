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

set -euo pipefail

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
brew_prefix=$(brew --prefix 2>/dev/null || echo "")
if [[ -n "$brew_prefix" ]]; then
  _fallback_dir="$brew_prefix/share/qemu"
else
  _fallback_dir="/opt/homebrew/share/qemu"
fi

# firmware code
if [[ -f "$_primary_code" ]]; then
  FW_CODE="$_primary_code"
elif [[ -f "$_fallback_dir/$(basename "$_primary_code")" ]]; then
  FW_CODE="$_fallback_dir/$(basename "$_primary_code")"
else
  echo "ERROR: firmware code not found at '$_primary_code' or '$_fallback_dir/$(basename "$_primary_code")'" >&2
  exit 1
fi

# vars template
if [[ -f "$_primary_vars" ]]; then
  VARS_TEMPLATE="$_primary_vars"
elif [[ -f "$_fallback_dir/$(basename "$_primary_vars")" ]]; then
  VARS_TEMPLATE="$_fallback_dir/$(basename "$_primary_vars")"
else
  echo "ERROR: template vars.fd not found at '$_primary_vars' or '$_fallback_dir/$(basename "$_primary_vars")'" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# 3. Create writable vars.fd once per repo checkout
# -----------------------------------------------------------------------------
if [[ ! -f "$VARS_COPY" ]]; then
  cp "$VARS_TEMPLATE" "$VARS_COPY"
  echo ">> Created writable NVRAM store: $VARS_COPY"
fi

# export for child scripts
export ARCH FW_CODE VARS_COPY UEFI_ID

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


#  5.3 – import rootfs & install GRUB (writes into $VARS_COPY)
docker run --rm --privileged \
  -v /dev:/dev \
  -v "$(pwd)":/work -w /work \
  -e ARCH="$ARCH" \
  --entrypoint /work/src/docker/import_rootfs.sh "$IMAGE"
