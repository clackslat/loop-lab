# ────────────────────────────────────────────────────────────────────────────
#  loop-lab • disk-tools image
#  ─ pulls both Ubuntu-24.04-minimal root-fs tarballs during the build
# ────────────────────────────────────────────────────────────────────────────
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

###############################################################################
#  Base utilities required at run-time
###############################################################################
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        util-linux gdisk dosfstools e2fsprogs kpartx udev dmsetup \
        curl xz-utils ca-certificates && \
    rm -rf /var/lib/apt/lists/*

###############################################################################
#  Cache BOTH architectures’ *Noble* root-fs tarballs  (single image layer)
###############################################################################
RUN mkdir -p /rootfs-cache/amd64 /rootfs-cache/arm64 && \
    curl -fsSL \
      https://cloud-images.ubuntu.com/minimal/releases/noble/release/ubuntu-24.04-minimal-cloudimg-amd64-root.tar.xz \
        -o /rootfs-cache/amd64/rootfs.tar.xz && \
    curl -fsSL \
      https://cloud-images.ubuntu.com/minimal/releases/noble/release/ubuntu-24.04-minimal-cloudimg-arm64-root.tar.xz \
        -o /rootfs-cache/arm64/rootfs.tar.xz

###############################################################################
#  Shared tracing header + helper scripts
###############################################################################
COPY strict_trace.sh   /usr/local/lib/
COPY build_image.sh    /usr/local/bin/
COPY prep_esp.sh       /usr/local/bin/
COPY import_rootfs.sh  /usr/local/bin/

ENTRYPOINT ["/usr/local/bin/build_image.sh"]
