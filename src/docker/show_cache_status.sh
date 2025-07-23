#!/usr/bin/env bash
# =============================================================================
# Cache Status Script (show_cache_status.sh)
# =============================================================================
# Purpose:
#   Shows the current cache status for all architectures and resource types.
#   Uses the Babashka configuration to determine cache paths.
#
# Usage:
#   ./show_cache_status.sh [architecture]
#   
# Examples:
#   ./show_cache_status.sh          # Show status for all architectures
#   ./show_cache_status.sh x64      # Show status for x64 only
#
# Dependencies:
#   - external_resources.bb: Babashka script for cache paths
#   - external_resources.edn: Configuration file
# =============================================================================

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Determine architectures to check
if [ $# -eq 1 ]; then
    ARCHITECTURES=("$1")
else
    ARCHITECTURES=("x64" "aarch64")
fi

echo "Cache status:"

# Check boot resources
echo "Boot resources (UEFI shells):"
for arch in "${ARCHITECTURES[@]}"; do
    cache_path=$("$SCRIPT_DIR/external_resources.bb" cache-location "$arch" boot)
    echo -n "  $arch: "
    if [ -f "$cache_path" ]; then
        size=$(du -h "$cache_path" | cut -f1)
        echo "✓ cached ($size) at $cache_path"
    else
        echo "✗ not cached at $cache_path"
    fi
done

# Check OS resources
echo "OS resources (rootfs):"
for arch in "${ARCHITECTURES[@]}"; do
    cache_path=$("$SCRIPT_DIR/external_resources.bb" cache-location "$arch" os)
    echo -n "  $arch: "
    if [ -f "$cache_path" ]; then
        size=$(du -h "$cache_path" | cut -f1)
        echo "✓ cached ($size) at $cache_path"
    else
        echo "✗ not cached at $cache_path"
    fi
done
