#!/usr/bin/env bash
# Build a blank template disk with EFI + root partitions.
# Runs fine on bare Linux *or* inside the docker/disk-tools image.
source /usr/local/lib/strict_trace.sh
ARCH=${ARCH:-x64}     
# ─── user-tweakable vars ─────────────────────────────────────────────
IMG_PATH=template-${ARCH}.img
IMG_SIZE="${IMG_SIZE:-10G}"
# ─────────────────────────────────────────────────────────────────────


truncate -s "$IMG_SIZE" "$IMG_PATH"

# Allocate a loop device (fatally warn if none)
if ! LOOPDEV=$(losetup --find --show --partscan "$IMG_PATH"); then
  echo "[warn] No free loop devices; opening shell for inspection."
fi
trap 'losetup -d "$LOOPDEV"' EXIT

# Partition + format
sgdisk --zap-all "$LOOPDEV"
sgdisk -n1:0:+512M -t1:EF00 -c1:EFI  "$LOOPDEV"
sgdisk -n2:0:0      -t2:8300 -c2:root "$LOOPDEV"
#LOOPDEV=$(losetup --find --show -P "$IMG_PATH")   # -P already triggers part scan


mkfs.vfat -F32 "${LOOPDEV}p1"
mkfs.ext4        "${LOOPDEV}p2"
echo "[info] $IMG_PATH created and formatted."
