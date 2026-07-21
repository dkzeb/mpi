#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: install-rootfs.sh --root ROOT --boot BOOT --release-tree DIR
                         [--maschinepi-binary FILE] [--password PASSWORD]
EOF
  exit 2
}

root=""
boot=""
release_tree=""
maschinepi_binary=""
password="maschinepi"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) root="$2"; shift 2 ;;
    --boot) boot="$2"; shift 2 ;;
    --release-tree) release_tree="$2"; shift 2 ;;
    --maschinepi-binary) maschinepi_binary="$2"; shift 2 ;;
    --password) password="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -d "$root" && -d "$boot" && -d "$release_tree" ]] || usage
repo_root="$(cd "$(dirname "$0")/.." && pwd)"

install -d -m 755 "$root/opt/mpi-station"
cp -a "$release_tree/." "$root/opt/mpi-station/"

install -d -m 755 "$root/etc/systemd/system" "$root/usr/local/sbin"
install -m 644 "$repo_root"/systemd/*.service "$repo_root"/systemd/*.target \
  "$root/etc/systemd/system/"
install -m 755 "$repo_root/scripts/mpi-mode-select" "$root/usr/local/sbin/"
install -m 755 "$repo_root/scripts/mpi-mode-switch" "$root/usr/local/sbin/"
install -m 755 "$repo_root/scripts/mpi-audio-profile" "$root/usr/local/sbin/"
install -m 755 "$repo_root/scripts/mpi-configure-mixxx-controller" "$root/usr/local/sbin/"
install -m 755 "$repo_root/image/mpi-station-first-boot" \
  "$root/usr/local/sbin/mpi-station-first-boot"

if [[ -n "$maschinepi_binary" ]]; then
  [[ -f "$maschinepi_binary" ]] || { echo "Missing MaschinePI binary: $maschinepi_binary" >&2; exit 1; }
  file "$maschinepi_binary" | grep -Eq 'ARM aarch64|ARM64' || {
    echo "MaschinePI binary is not ARM64: $(file "$maschinepi_binary")" >&2
    exit 1
  }
  install -D -m 755 "$maschinepi_binary" "$root/usr/local/bin/maschinepi"
fi

install -d -m 755 "$root/var/lib/mk3-mode" "$root/var/lib/mpi-station"
install -m 644 "$repo_root/config/mk3-mode.conf" "$root/var/lib/mk3-mode/config"

install -d -m 755 "$root/etc/sysctl.d" "$root/etc/udev/rules.d"
cat > "$root/etc/sysctl.d/99-realtime-audio.conf" <<'EOF'
vm.swappiness=10
vm.dirty_ratio=3
vm.dirty_background_ratio=1
kernel.sched_rt_runtime_us=-1
EOF
cat > "$root/etc/udev/rules.d/99-mk3-controller.rules" <<'EOF'
SUBSYSTEM=="usb", ATTRS{idVendor}=="17cc", ATTRS{idProduct}=="1600", MODE="0664", GROUP="audio"
EOF

install -d -m 755 "$root/etc/systemd/system/multi-user.target.wants"
ln -sfn /etc/systemd/system/mpi-station-first-boot.service \
  "$root/etc/systemd/system/multi-user.target.wants/mpi-station-first-boot.service"
ln -sfn /lib/systemd/system/ssh.service \
  "$root/etc/systemd/system/multi-user.target.wants/ssh.service"
ln -sfn /etc/systemd/system/mode-selector.target "$root/etc/systemd/system/default.target"

printf 'mpi-station\n' > "$root/etc/hostname"
if [[ -f "$root/etc/hosts" ]]; then
  sed -i -E 's/([[:space:]])raspberrypi([[:space:]]|$)/\1mpi-station\2/g' "$root/etc/hosts"
fi

password_hash="$(openssl passwd -6 "$password")"
printf 'mpi:%s\n' "$password_hash" > "$boot/userconf.txt"
touch "$boot/ssh"

echo "Installed mpi-station release into $root"
echo "Default mode: maschinepi"
echo "First boot user: mpi"
