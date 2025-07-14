#!/usr/bin/env bash
# Build Noble disk images for every architecture listed in arch_info.sh

# --------------------------------------------------------------------------
# Common tracing / strict settings
# --------------------------------------------------------------------------
source ./src/docker/strict_trace.sh        # sets PS4 + -euo pipefail
source ./src/docker/arch_info.sh           # provides $ARCH_LIST, maps
# --------------------------------------------------------------------------

echo "[build_all_arch] detaching stale loop devices …"
if command -v docker >/dev/null 2>&1; then
  docker run --rm --privileged ubuntu:22.04 losetup -D || true
fi

for ARCH in $ARCH_LIST; do
  echo "[build_all_arch] building image for $ARCH …"
  ARCH=$ARCH bash src/docker/run_in_docker.sh
done

echo "[build_all_arch] ✅  all architectures built successfully."
