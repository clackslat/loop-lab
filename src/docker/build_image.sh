#!/usr/bin/env bash
# Build a blank template disk with EFI + root partitions.
# Runs fine on bare Linux *or* inside the docker/disk-tools image.
source /usr/local/lib/strict_trace.sh

# ─── user-tweakable vars ─────────────────────────────────────────────
IMG_PATH="${IMG_PATH:-template.img}"
IMG_SIZE="${IMG_SIZE:-10G}"
# ─────────────────────────────────────────────────────────────────────


truncate -s "$IMG_SIZE" "$IMG_PATH"

# Allocate a loop device (fatally warn if none)
if ! LOOPDEV=$(losetup --find --show --partscan "$IMG_PATH"); then
  echo "[warn] No free loop devices; opening shell for inspection."
  exec bash
fi
trap 'losetup -d "$LOOPDEV"' EXIT

# Partition + format
sgdisk --zap-all "$LOOPDEV"
sgdisk -n1:0:+512M -t1:EF00 -c1:EFI  "$LOOPDEV"
sgdisk -n2:0:0      -t2:8300 -c2:root "$LOOPDEV"
#LOOPDEV=$(losetup --find --show -P "$IMG_PATH")   # -P already triggers part scan

# Wait (max 3 s) for /dev/loopXp1 to appear
for i in {1..30}; do
  [[ -e "${LOOPDEV}p1" ]] && break
  sleep 0.1
done || { echo "[err] partition nodes never appeared"; exit 1; }

mkfs.vfat -F32 "${LOOPDEV}p1"
mkfs.ext4        "${LOOPDEV}p2"
echo "[info] $IMG_PATH created and formatted."

# Keep container alive if running interactively
[[ -t 1 ]] && exec bash || true
