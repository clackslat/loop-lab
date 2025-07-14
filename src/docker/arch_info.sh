ARCH_LIST="x64 aarch64"              # master list each caller can loop over

declare -A ROOTFS_TAR=(
  [x64]="/rootfs-cache/amd64/rootfs.tar.xz"
  [aarch64]="/rootfs-cache/arm64/rootfs.tar.xz"
)

declare -A GRUB_TARGET=(
  [x64]="x86_64-efi"
  [aarch64]="arm64-efi"
)
declare -A GRUB_PKG=(
  [x64]="grub-efi-amd64"
  [aarch64]="grub-efi-arm64"
)
declare -A EFI_SHELL_PATH=(
  [x64]="/work/assets/x64/Shell.efi"
  [aarch64]="/work/assets/aarch64/Shell.efi"
)
declare -A PKG_CACHE_DIR=(
  [x64]="/pkg-cache/amd64"
  [aarch64]="/pkg-cache/arm64"
)
