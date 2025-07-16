#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# prep_esp.sh – Stage only the UEFI Shell for the target ARCH by fetching it
#
# Runs inside Docker with the ESP mounted at /mnt.
# Sources:
#   strict_trace.sh → set -xeuo pipefail + PS4 tracing
#   arch_info.sh    → defines ARCH_LIST, UEFI_ID[]
#
# Usage (inside run_in_docker.sh):
#   ARCH=aarch64 ./prep_esp.sh
# -----------------------------------------------------------------------------

exit 0
set -euo pipefail

# 1. Strict mode & tracing
source "$(dirname "${BASH_SOURCE[0]}")/strict_trace.sh"

# 2. Per-arch metadata
source "$(dirname "${BASH_SOURCE[0]}")/arch_info.sh"

# 3. Determine ARCH (from env or first arg), default to x64
ARCH=${ARCH:-${1:-x64}}

# 4. Map ARCH → official EDK2 shell URL
declare -A SHELL_URL=(
  ['x64']="https://github.com/tianocore/edk2/releases/download/edk2-stable202408/UEFI_Shell_Full.efi"
  ['aarch64']="https://github.com/tianocore/edk2/releases/download/edk2-stable202408/UEFI_Shell_AArch64.efi"
)

# 5. Lookup the URL and UEFI_ID for this ARCH
URL="${SHELL_URL[$ARCH]}"
ID="${UEFI_ID[$ARCH]}"             # X64 or AA64

# 6. Fetch and stage the single-shell fallback loader
echo "[ESP] fetching $ARCH UEFI Shell from $URL"
mkdir -p /mnt/EFI/BOOT
curl -fsSL "$URL" -o "/mnt/EFI/BOOT/BOOT${ID}.EFI"
echo "[ESP] staged BOOT${ID}.EFI"

# 7. Leave the Ubuntu stub (will be overwritten by import_rootfs.sh)
mkdir -p /mnt/EFI/UBUNTU
cat > /mnt/EFI/UBUNTU/grub.cfg <<'EOF'
# placeholder — import_rootfs.sh will overwrite this with GRUB’s config
EOF

echo "[✓] ESP ready: fallback Shell placeholder for $ARCH installed as BOOT${ID}.EFI"
