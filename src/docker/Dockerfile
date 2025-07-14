FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# 0. utilities
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        util-linux gdisk dosfstools e2fsprogs kpartx udev dmsetup \
        curl xz-utils ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# 1. root-fs tar-balls
RUN set -eux; for arch in amd64 arm64; do \
      mkdir -p /rootfs-cache/${arch}; \
      curl -fsSL \
        "https://cloud-images.ubuntu.com/minimal/releases/noble/release/ubuntu-24.04-minimal-cloudimg-${arch}-root.tar.xz" \
        -o "/rootfs-cache/${arch}/rootfs.tar.xz"; \
    done

# 2. helper scripts
COPY strict_trace.sh   /usr/local/lib/
COPY arch_info.sh      /usr/local/lib/
COPY build_image.sh    /usr/local/bin/
COPY prep_esp.sh       /usr/local/bin/
COPY import_rootfs.sh  /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh

ENTRYPOINT ["/usr/local/bin/build_image.sh"]
