#!/usr/bin/env bash
set -Eeuo pipefail

# ---------- defaults (avoid unbound-variable with set -u) ----------
IMG_PATH="${IMG_PATH:-./template.img}"
IMG_SIZE="${IMG_SIZE:-10G}"
export IMG_PATH IMG_SIZE

# ---------- live logging ----------
if command -v ts >/dev/null 2>&1; then
  exec > >(ts $'\033[0;32m[%H:%M:%S]\033[0m' | tee -a build_template.log) 2>&1
else
  exec > >(tee -a build_template.log) 2>&1
fi
export PS4=$'\033[1;94m[${LINENO}] \033[0m'; set -x

# ---------- build steps ----------
truncate -s "$IMG_SIZE" "$IMG_PATH"

if ! LOOPDEV=$(losetup --find --show --partscan "$IMG_PATH"); then
  echo "[warn] No free loop devices; opening shell for inspection."
  exec bash
fi
trap 'losetup -d "$LOOPDEV"' EXIT

sgdisk --zap-all "$LOOPDEV"
sgdisk -n1:0:+512M -t1:EF00 -c1:EFI  "$LOOPDEV"
sgdisk -n2:0:0      -t2:8300 -c2:root "$LOOPDEV"
partx -u "$LOOPDEV"
mkfs.vfat -F32 "${LOOPDEV}p1"
mkfs.ext4        "${LOOPDEV}p2"

echo "[info] template.img created and formatted."
exec sleep infinity
