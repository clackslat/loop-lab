#!/usr/bin/env bash
source "$(dirname "$0")/strict_trace.sh"
source "$(dirname "$0")/arch_info.sh"

IMAGE=loop-lab-disktools
ARCH=${ARCH:-aarch4}                     # set ARCH=x64 when needed

# (re)build the tools image
docker build -t "$IMAGE" -f src/docker/Dockerfile src/docker

# Step 0/1 – create template.img and partition it
docker run --rm --privileged \
  -v /dev:/dev \
  -v "$(pwd)":/work -w /work \
  --entrypoint /work/src/docker/build_image.sh "$IMAGE"

# Step 2-A – prepare ESP (UEFI Shell default)
docker run --rm --privileged \
  -v /dev:/dev \
  -v "$(pwd)":/work -w /work \
  --entrypoint /work/src/docker/prep_esp.sh \
  "$IMAGE" "$ARCH"

# Step 2-B – populate rootfs + GRUB  (later)
 docker run --rm --privileged \
   -v /dev:/dev \
   -v "$(pwd)":/work -w /work \
   --entrypoint /work/src/docker/import_rootfs.sh "$IMAGE" "$ARCH"
