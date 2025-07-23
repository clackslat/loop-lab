#!/usr/bin/env bash
# =============================================================================
# Cache Check and Download Script (check_and_download_cache.sh)
# =============================================================================
# Purpose:
#   Checks if cache resources exist for a given architecture and resource type.
#   Downloads missing resources using the Babashka configuration.
#
# Usage:
#   ./check_and_download_cache.sh <architecture> <resource_type>
#   
# Examples:
#   ./check_and_download_cache.sh x64 boot
#   ./check_and_download_cache.sh aarch64 os
#
# Dependencies:
#   - external_resources.bb: Babashka script for cache paths and URLs
#   - external_resources.edn: Configuration file
# =============================================================================

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Check arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 <architecture> <resource_type>"
    echo "  architecture: x64, aarch64"
    echo "  resource_type: boot, os"
    exit 1
fi

ARCH="$1"
RESOURCE_TYPE="$2"

echo "Checking $RESOURCE_TYPE cache for $ARCH..."

# Get cache path and source URL using Babashka
cache_path=$("$SCRIPT_DIR/external_resources.bb" cache-location "$ARCH" "$RESOURCE_TYPE")
source_url=$("$SCRIPT_DIR/external_resources.bb" source-url "$ARCH" "$RESOURCE_TYPE")

# Check if cache exists
if [ -f "$cache_path" ]; then
    echo "✓ $RESOURCE_TYPE resource already cached at: $cache_path"
    exit 0
fi

# Download missing resource
echo "$RESOURCE_TYPE resource missing, downloading..."
echo "Source URL: $source_url"
echo "Cache path: $cache_path"

# Create cache directory
mkdir -p "$(dirname "$cache_path")"

# Download with curl
echo "Downloading..."
if curl -L "$source_url" -o "$cache_path"; then
    echo "✓ $RESOURCE_TYPE resource cached at: $cache_path"
else
    echo "✗ Failed to download $RESOURCE_TYPE resource"
    rm -f "$cache_path"  # Clean up partial download
    exit 1
fi
