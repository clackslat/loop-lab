#!/usr/bin/env bash
# =============================================================================
# find_shell_scripts.sh - Helper utility to identify shell scripts
# =============================================================================
# This script identifies shell scripts in the repository using multiple methods:
# 1. Files with .sh extension
# 2. Files with bash or sh shebangs
#
# It excludes binary files, images, and other non-shell files to prevent
# false positives and improper analysis.
#
# Usage:
#   source hooks/find_shell_scripts.sh
#   find_shell_scripts [base_dir]
#
# Returns:
#   Prints a newline-delimited list of shell script paths
# =============================================================================

# Function to find shell scripts in a directory
find_shell_scripts() {
  local base_dir="${1:-.}"  # Default to current directory if not specified
  
  # Find all shell scripts with proper extensions or shebangs
  # First, find scripts with .sh extension
  local sh_ext_scripts
  sh_ext_scripts=$(find "$base_dir" -type f -name "*.sh" -not -path "*/.git/*" -not -path "*/test/*")
  
  # Then find scripts with bash/sh shebang, excluding images and binary files
  local shebang_scripts
  shebang_scripts=$(find "$base_dir" -type f -not -path "*/.git/*" -not -path "*/test/*" \
    -not -path "*.img" -not -path "*.efi" -not -path "*.fd" \
    -exec grep -l "^#!.*\(bash\|sh\)" {} \; 2>/dev/null || true)
  
  # Combine both lists and remove duplicates
  echo "$sh_ext_scripts $shebang_scripts" | tr ' ' '\n' | sort -u | grep -v "^$"
}

# If this script is called directly (not sourced), run the function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  find_shell_scripts "$@"
fi
