#!/usr/bin/env bash
set -euo pipefail

image_path="${1:?image path required}"
release_tree="${2:?release tree required}"
maschinepi_binary="${3:-}"
password="${4:-maschinepi}"

loop=""
root_mount="$(mktemp -d)"
boot_mount="$(mktemp -d)"

cleanup() {
  mountpoint -q "$root_mount" && umount "$root_mount" || true
  mountpoint -q "$boot_mount" && umount "$boot_mount" || true
  [[ -n "$loop" ]] && losetup -d "$loop" || true
  rmdir "$root_mount" "$boot_mount" 2>/dev/null || true
}
trap cleanup EXIT

loop="$(losetup --find --show --partscan "$image_path")"
partprobe "$loop" || true
sleep 1

[[ -b "${loop}p1" && -b "${loop}p2" ]] || {
  echo "Expected boot/root partitions ${loop}p1 and ${loop}p2" >&2
  exit 1
}

mount "${loop}p1" "$boot_mount"
mount "${loop}p2" "$root_mount"

args=(--root "$root_mount" --boot "$boot_mount" --release-tree "$release_tree" --password "$password")
[[ -n "$maschinepi_binary" ]] && args+=(--maschinepi-binary "$maschinepi_binary")
/repo/image/install-rootfs.sh "${args[@]}"
sync
