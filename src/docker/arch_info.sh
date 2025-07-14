ARCH_LIST="x64 aarch64"              # master list each caller can loop over

declare -A ROOTFS_TAR=(
  [x64]    ="/rootfs-cache/amd64/rootfs.tar.xz"
  [aarch64]="/rootfs-cache/arm64/rootfs.tar.xz"
)

declare -A GRUB_TARGET=(
  [x64]="x86_64-efi"
  [aarch64]="arm64-efi"
)

declare -A EFI_SHELL_PATH=(
  [x64]    ="/usr/local/share/uefi-shell/x64/Shell.efi"
  [aarch64]="/usr/local/share/uefi-shell/aarch64/Shell.efi"
)
