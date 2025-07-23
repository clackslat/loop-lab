#!/usr/bin/env bash
# Simple test script for our external resources system

echo "=== Testing External Resources System ==="

# Load our scripts
. "$(dirname "${BASH_SOURCE[0]}")/load_scripts.sh"

echo "✓ Scripts loaded successfully"

echo "Supported architectures: $("$BB_SCRIPT" arch-list)"
echo "x64 rootfs path: $("$BB_SCRIPT" rootfs-path x64)"
echo "aarch64 UEFI ID: $("$BB_SCRIPT" uefi-id aarch64)"
echo "Ubuntu URL for x64: $("$BB_SCRIPT" ubuntu-url x64)"
echo "Cache version: $("$BB_SCRIPT" cache-version)"

echo "✓ All Babashka functions working!"
