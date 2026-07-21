#!/usr/bin/env bash
set -euo pipefail

root="${1:?mounted rootfs path required}"
[[ -d "$root" && -x "$root/bin/bash" ]] || {
  echo "Invalid mounted rootfs: $root" >&2
  exit 1
}

qemu_source="$(command -v qemu-aarch64-static)"
qemu_target="$root/usr/bin/qemu-aarch64-static"
policy_target="$root/usr/sbin/policy-rc.d"
resolv_target="$root/etc/resolv.conf"
resolv_backup=""
mounted=()

cleanup() {
  for ((index=${#mounted[@]} - 1; index >= 0; index--)); do
    umount -l "${mounted[$index]}" 2>/dev/null || true
  done
  rm -f "$qemu_target" "$policy_target"
  if [[ -n "$resolv_backup" && -e "$resolv_backup" ]]; then
    rm -f "$resolv_target"
    mv "$resolv_backup" "$resolv_target"
  fi
}
trap cleanup EXIT

install -D -m 755 "$qemu_source" "$qemu_target"
install -D -m 755 /repo/image/policy-rc.d "$policy_target"

if [[ -e "$resolv_target" || -L "$resolv_target" ]]; then
  resolv_backup="$root/etc/resolv.conf.mpi-station-build"
  mv "$resolv_target" "$resolv_backup"
fi
cp /etc/resolv.conf "$resolv_target"

for virtual in dev dev/pts proc sys run; do
  install -d "$root/$virtual"
  mount --rbind "/$virtual" "$root/$virtual"
  mount --make-rslave "$root/$virtual"
  mounted+=("$root/$virtual")
done

chroot "$root" /usr/bin/qemu-aarch64-static \
  /bin/bash /usr/local/sbin/mpi-station-provision-rootfs
