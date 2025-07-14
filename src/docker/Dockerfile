# ──────────────────────────────────────────────────────────────
#  loop-lab ▸ disk-tools builder  (online package install)
#  • Base  : Ubuntu 22.04 (Jammy)
#  • Target: Ubuntu 24.04 (Noble) root-fs
# ──────────────────────────────────────────────────────────────
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# 0. minimal runtime utilities (losetup, mkfs, curl, etc.)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        util-linux gdisk dosfstools e2fsprogs kpartx udev dmsetup \
        curl xz-utils ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# 1. fetch Noble release root-fs tarballs (amd64 + arm64)
RUN set -eux; \
    for arch in amd64 arm64; do \
      mkdir -p /rootfs-cache/${arch}; \
      curl -fsSL \
        "https://cloud-images.ubuntu.com/minimal/releases/noble/release/ubuntu-24.04-minimal-cloudimg-${arch}-root.tar.xz" \
        -o "/rootfs-cache/${arch}/rootfs.tar.xz"; \
    done

# 2. copy helper libraries & scripts
COPY strict_trace.sh   /usr/local/lib/
COPY arch_info.sh      /usr/local/lib/
COPY build_image.sh    /usr/local/bin/
COPY prep_esp.sh       /usr/local/bin/
COPY import_rootfs.sh  /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh

ENTRYPOINT ["/usr/local/bin/build_image.sh"]
