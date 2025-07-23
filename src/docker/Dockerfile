# =============================================================================
# Disk-tools Container Image
# =============================================================================
# Purpose:
#   This Dockerfile creates an image that serves as the environment for building
#   bootable disk images for multiple architectures. It includes all necessary
#   tools and scripts required for the build process.
#
#   Cache files are expected to be mounted at runtime via volume mounts.
#   Build arguments provide cache locations and architecture metadata.
#
# Base Image:
#   Ubuntu 22.04 (Jammy) - Chosen for stability and compatibility with Noble
# =============================================================================

# Start from Ubuntu 22.04 base
FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Build arguments from Makefile/Babashka script
ARG ARCH
ARG BOOT_ARCH
ARG OS_ARCH

# Set environment variables for scripts
ENV TARGET_ARCH=${ARCH}
ENV TARGET_BOOT_ARCH=${BOOT_ARCH}
ENV TARGET_OS_ARCH=${OS_ARCH}

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
# - xz-utils: Decompress rootfs tarballs
# - ca-certificates: For any HTTPS operations
# -----------------------------------------------------------------------------
# Install necessary packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        util-linux gdisk dosfstools xz-utils wget curl \
        kmod udev multipath-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Install Babashka
# -----------------------------------------------------------------------------
# Install babashka for EDN configuration processing
# Using the official installation script for latest version
RUN curl -fsSL https://raw.githubusercontent.com/babashka/babashka/master/install | bash

# -----------------------------------------------------------------------------
# Install Build Scripts
# -----------------------------------------------------------------------------
# Copy and install all helper scripts needed for the build process:
#
# Library scripts (in /usr/local/lib):
# - strict_trace.sh: Shell strictness settings and tracing
# - load_scripts.sh: Helper to load common scripts
# - external_resources.edn: External URLs and resource configuration (EDN format)
# - external_resources.bb: Babashka script to process EDN configuration
#
# Executable scripts (in /usr/local/bin):
# - build_image.sh: Main entry point, creates basic disk structure
# - prep_esp.sh: Prepares EFI System Partition
# - import_rootfs.sh: Imports and configures root filesystem
# -----------------------------------------------------------------------------
COPY strict_trace.sh         /usr/local/lib/
COPY load_scripts.sh         /usr/local/lib/
COPY external_resources.edn  /usr/local/lib/
COPY external_resources.bb   /usr/local/lib/
COPY build_image.sh          /usr/local/bin/
COPY prep_esp.sh             /usr/local/bin/
COPY import_rootfs.sh        /usr/local/bin/

# Make all scripts executable
RUN chmod +x /usr/local/bin/*.sh /usr/local/lib/*.sh /usr/local/lib/*.bb

# -----------------------------------------------------------------------------
# Runtime Expectations
# -----------------------------------------------------------------------------
# This image expects the following volume mounts at runtime:
# - /work: Working directory with source files
# - /cache: Mounted cache directory with required resources
# - /output: Output directory for built images
#
# The /cache directory should contain all necessary resources for the build.
# Cache management is handled externally by the Makefile.
# -----------------------------------------------------------------------------

# Set the default entry point to the main build script
ENTRYPOINT ["/usr/local/bin/build_image.sh"]
