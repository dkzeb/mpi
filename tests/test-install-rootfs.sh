#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

root="$tmp_dir/root"
boot="$tmp_dir/boot"
release="$tmp_dir/release"
mkdir -p "$root/etc" "$boot" "$release/external/mixxx-mk3" "$release/external/maschinepi-te"
printf '127.0.1.1 raspberrypi\n' > "$root/etc/hosts"
printf '# fixture\n' > "$release/README.md"

"$repo_root/image/install-rootfs.sh" \
  --root "$root" --boot "$boot" --release-tree "$release" --password test-only

[[ -L "$root/etc/systemd/system/default.target" ]]
[[ "$(readlink "$root/etc/systemd/system/default.target")" == /etc/systemd/system/mode-selector.target ]]
[[ -L "$root/etc/systemd/system/multi-user.target.wants/mpi-station-first-boot.service" ]]
[[ ! -e "$root/etc/systemd/system/multi-user.target.wants/maschinepi.service" ]]
[[ ! -e "$root/etc/systemd/system/multi-user.target.wants/mixxx.service" ]]
grep -qx 'default_mode=maschinepi' "$root/var/lib/mk3-mode/config"
grep -q '^mpi:' "$boot/userconf.txt"
[[ -e "$boot/ssh" ]]
[[ -x "$root/usr/local/sbin/mpi-mode-switch" ]]
grep -q 'mpi-station' "$root/etc/hosts"

echo "install-rootfs fixture: PASS"
