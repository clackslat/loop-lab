# =============================================================================
# Disk-tools Container Image
# =============================================================================
# Purpose:
#   This Dockerfile creates an image that serves as the environment for building
#   bootable disk images for multiple architectures. It includes all necessary
#   tools, rootfs tarballs, and scripts required for the build process.
#
# Base Image:
#   Ubuntu 22.04 (Jammy) - Chosen for stability and compatibility with Noble
# =============================================================================

# Start from Ubuntu 22.04 base
FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# -----------------------------------------------------------------------------
# System Utilities Installation
# -----------------------------------------------------------------------------
# Install required packages:
# - util-linux: Core Linux utilities including losetup
# - gdisk: GUID partition table manipulation
# - dosfstools: FAT filesystem utilities for ESP
# - e2fsprogs: ext4 filesystem utilities for root
# - kpartx: Device mapper tools
# - udev: Dynamic device management
# - dmsetup: Device mapper setup
# - curl: Download rootfs tarballs
# - xz-utils: Decompress rootfs tarballs
# - ca-certificates: HTTPS downloads
# -----------------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        util-linux gdisk dosfstools e2fsprogs kpartx udev dmsetup \
        curl xz-utils ca-certificates && \
    rm -rf /var/lib/apt/lists/*  # Clean up to reduce image size

# -----------------------------------------------------------------------------
# Download Ubuntu Noble Root Filesystems
# -----------------------------------------------------------------------------
# Download minimal Ubuntu 24.04 (Noble) root filesystem tarballs for each
# supported architecture. These will be used as the base for our custom images.
#
# Architecture mapping:
# - amd64 → x86_64/x64 systems
# - arm64 → aarch64 systems
# -----------------------------------------------------------------------------
RUN set -eux; for arch in amd64 arm64; do \
      mkdir -p /rootfs-cache/${arch}; \
      curl -fsSL \
        "https://cloud-images.ubuntu.com/minimal/releases/noble/release/ubuntu-24.04-minimal-cloudimg-${arch}-root.tar.xz" \
        -o "/rootfs-cache/${arch}/rootfs.tar.xz"; \
    done

# -----------------------------------------------------------------------------
# Install Build Scripts
# -----------------------------------------------------------------------------
# Copy and install all helper scripts needed for the build process:
#
# Library scripts (in /usr/local/lib):
# - strict_trace.sh: Shell strictness settings and tracing
# - arch_info.sh: Architecture-specific configuration
#
# Executable scripts (in /usr/local/bin):
# - build_image.sh: Main entry point, creates basic disk structure
# - prep_esp.sh: Prepares EFI System Partition
# - import_rootfs.sh: Imports and configures root filesystem
# -----------------------------------------------------------------------------
COPY strict_trace.sh   /usr/local/lib/
COPY arch_info.sh      /usr/local/lib/
COPY build_image.sh    /usr/local/bin/
COPY prep_esp.sh       /usr/local/bin/
COPY import_rootfs.sh  /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh  # Ensure scripts are executable

# Set the default entry point to the main build script
ENTRYPOINT ["/usr/local/bin/build_image.sh"]
