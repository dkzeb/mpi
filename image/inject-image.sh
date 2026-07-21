#!/usr/bin/env bash
set -euo pipefail

image_path="${1:?image path required}"
release_tree="${2:?release tree required}"
maschinepi_binary="${3:-}"
password="${4:-maschinepi}"

boot_loop=""
root_loop=""
root_mount="$(mktemp -d)"
boot_mount="$(mktemp -d)"

cleanup() {
  mountpoint -q "$root_mount" && umount "$root_mount" || true
  mountpoint -q "$boot_mount" && umount "$boot_mount" || true
  [[ -n "$root_loop" ]] && losetup -d "$root_loop" || true
  [[ -n "$boot_loop" ]] && losetup -d "$boot_loop" || true
  rmdir "$root_mount" "$boot_mount" 2>/dev/null || true
}
trap cleanup EXIT

# The host appends headroom to the image. Extend partition 2 and its ext4
# filesystem before copying the release payload into it.
parted -s "$image_path" unit s resizepart 2 100%

mapfile -t partitions < <(
  sfdisk -d "$image_path" | awk -F'[=,]' '/start=.*size=/ {
    gsub(/[^0-9]/, "", $2)
    gsub(/[^0-9]/, "", $4)
    print $2 " " $4
  }'
)

[[ "${#partitions[@]}" -ge 2 ]] || {
  echo "Expected at least two partitions in $image_path" >&2
  exit 1
}

read -r boot_start boot_size <<< "${partitions[0]}"
read -r root_start root_size <<< "${partitions[1]}"
boot_loop="$(losetup --find --show \
  --offset "$((boot_start * 512))" --sizelimit "$((boot_size * 512))" "$image_path")"
root_loop="$(losetup --find --show \
  --offset "$((root_start * 512))" --sizelimit "$((root_size * 512))" "$image_path")"

set +e
e2fsck -f -y "$root_loop"
fsck_status=$?
set -e
[[ "$fsck_status" -lt 4 ]] || exit "$fsck_status"
resize2fs "$root_loop"

mount "$boot_loop" "$boot_mount"
mount "$root_loop" "$root_mount"

args=(--root "$root_mount" --boot "$boot_mount" --release-tree "$release_tree" --password "$password")
[[ -n "$maschinepi_binary" ]] && args+=(--maschinepi-binary "$maschinepi_binary")
/repo/image/install-rootfs.sh "${args[@]}"
sync
