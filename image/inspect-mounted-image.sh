#!/usr/bin/env bash
set -euo pipefail

image_path="${1:?image path required}"
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

mapfile -t partitions < <(
  sfdisk -d "$image_path" | awk -F'[=,]' '/start=.*size=/ {
    gsub(/[^0-9]/, "", $2)
    gsub(/[^0-9]/, "", $4)
    print $2 " " $4
  }'
)
[[ "${#partitions[@]}" -ge 2 ]]
read -r boot_start boot_size <<< "${partitions[0]}"
read -r root_start root_size <<< "${partitions[1]}"

boot_loop="$(losetup --find --show --read-only \
  --offset "$((boot_start * 512))" --sizelimit "$((boot_size * 512))" "$image_path")"
root_loop="$(losetup --find --show --read-only \
  --offset "$((root_start * 512))" --sizelimit "$((root_size * 512))" "$image_path")"
mount -o ro "$boot_loop" "$boot_mount"
mount -o ro "$root_loop" "$root_mount"

default_target="$(readlink "$root_mount/etc/systemd/system/default.target")"
[[ "$default_target" == /etc/systemd/system/mode-selector.target ]]
[[ -e "$boot_mount/userconf.txt" && -e "$boot_mount/ssh" ]]
[[ -x "$root_mount/usr/local/sbin/mpi-station-first-boot" ]]
[[ -L "$root_mount/etc/systemd/system/multi-user.target.wants/mpi-station-first-boot.service" ]]
[[ ! -e "$root_mount/var/lib/mpi-station/provisioned" ]]

for unit in maschinepi.service mixxx.service xvfb.service openbox.service mk3-screen-daemon.service; do
  [[ ! -e "$root_mount/etc/systemd/system/multi-user.target.wants/$unit" ]]
done

echo "OS: $(. "$root_mount/etc/os-release"; echo "$PRETTY_NAME")"
echo "Default target: $default_target"
echo "Global mpi-station units:"
find "$root_mount/etc/systemd/system/multi-user.target.wants" -maxdepth 1 \
  -type l -name '*mpi-station*' -printf '  %f -> %l\n'
echo "Root filesystem space before first-boot expansion:"
df -h "$root_mount" | tail -n1

git config --global --add safe.directory '*'
git -C "$root_mount/opt/mpi-station" submodule status --recursive
"$root_mount/opt/mpi-station/scripts/check-submodules.sh"
echo "Image inspection: PASS"
