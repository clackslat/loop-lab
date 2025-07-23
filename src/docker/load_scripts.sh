#!/usr/bin/env bash
# =============================================================================
# Script Loader Helper (load_scripts.sh)
# =============================================================================
# Purpose:
#   Simple helper to load common scripts from the same directory.
#   Works both locally and in Docker without environment detection.
#   All data handling now done via Babashka directly.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/load_scripts.sh"
# =============================================================================

# Get the directory containing the calling script
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Load strict mode settings only
. "$SCRIPT_DIR/strict_trace.sh"

# Path to Babashka script for direct usage
BB_SCRIPT="$SCRIPT_DIR/external_resources.bb"

# Export version information for cache validation - removed cache-version command as it doesn't exist
# EXTERNAL_RESOURCES_VERSION=$("$BB_SCRIPT" cache-version 2>/dev/null)
# export EXTERNAL_RESOURCES_VERSION
