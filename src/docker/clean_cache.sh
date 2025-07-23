#!/usr/bin/env bash
# =============================================================================
# Cache Clean Script (clean_cache.sh)
# =============================================================================
# Purpose:
#   Cleans cache files for specified architecture and resource types.
#   Uses the Babashka configuration to determine cache paths.
#
# Usage:
#   ./clean_cache.sh <architecture> [resource_type]
#   ./clean_cache.sh all [resource_type]
#   
# Examples:
#   ./clean_cache.sh x64            # Clean all caches for x64
#   ./clean_cache.sh x64 boot       # Clean only boot cache for x64
#   ./clean_cache.sh x64 os         # Clean only OS cache for x64
#   ./clean_cache.sh all            # Clean all caches for all architectures
#   ./clean_cache.sh all boot       # Clean boot caches for all architectures
#
# Dependencies:
#   - external_resources.bb: Babashka script for cache paths
#   - external_resources.edn: Configuration file
# =============================================================================

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Check arguments
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Usage: $0 <architecture|all> [resource_type]"
    echo "  architecture: x64, aarch64, all"
    echo "  resource_type: boot, os (optional, defaults to both)"
    exit 1
fi

ARCH_ARG="$1"
RESOURCE_TYPE="${2:-both}"

# Determine architectures to clean
if [ "$ARCH_ARG" = "all" ]; then
    ARCHITECTURES=("x64" "aarch64")
    echo "Cleaning caches for all architectures..."
else
    ARCHITECTURES=("$ARCH_ARG")
    echo "Cleaning cache for $ARCH_ARG..."
fi

# Determine resource types to clean
case "$RESOURCE_TYPE" in
    "boot")
        RESOURCE_TYPES=("boot")
        ;;
    "os")
        RESOURCE_TYPES=("os")
        ;;
    "both")
        RESOURCE_TYPES=("boot" "os")
        ;;
    *)
        echo "Error: Invalid resource type '$RESOURCE_TYPE'. Use 'boot', 'os', or omit for both."
        exit 1
        ;;
esac

# Clean cache files
for arch in "${ARCHITECTURES[@]}"; do
    for resource_type in "${RESOURCE_TYPES[@]}"; do
        cache_path=$("$SCRIPT_DIR/external_resources.bb" cache-location "$arch" "$resource_type")
        if [ -f "$cache_path" ]; then
            rm -f "$cache_path"
            echo "✓ Cleaned $resource_type cache for $arch: $cache_path"
        else
            echo "✓ No $resource_type cache to clean for $arch: $cache_path"
        fi
    done
done
