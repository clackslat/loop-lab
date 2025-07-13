#!/usr/bin/env bash

# 1) fail fast
set -euo pipefail          # -e = exit on error, -u = exit on unset var, -o pipefail

# 2) readable trace
export PS4='[${BASH_SOURCE##*/}:${LINENO}] '
set -x                     # -x = trace each command with the PS4 prefix

IMAGE=loop-lab-disktools
ARCH=${ARCH:-x64}                     # set ARCH=aarch64 when needed

# (re)build the tools image
docker build -t "$IMAGE" -f src/docker/Dockerfile src/docker

# Step 0/1 – create template.img and partition it
docker run --rm --privileged \
  -v /dev:/dev \
  -v "$(pwd)":/work -w /work "$IMAGE" \
  /work/src/docker/build_image.sh

# Step 2-A – prepare ESP (UEFI Shell default)
docker run --rm --privileged \
  -v /dev:/dev \
  -v "$(pwd)":/work -w /work \
  --entrypoint /work/src/docker/prep_esp.sh \
  "$IMAGE" "$ARCH"

# Step 2-B – populate rootfs + GRUB  (later)
# docker run --rm --privileged \
#   -v /dev:/dev \
#   -v "$(pwd)":/work -w /work "$IMAGE" \
#   /work/src/docker/import_rootfs.sh "$ARCH"
