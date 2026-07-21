#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
units="$repo_root/systemd"

if command -v systemd-analyze >/dev/null; then
  verify_root="$(mktemp -d)"
  trap 'rm -rf "$verify_root"' EXIT
  mkdir -p \
    "$verify_root/etc/systemd/system" "$verify_root/usr/lib/systemd/system" \
    "$verify_root/usr/local/sbin" "$verify_root/usr/local/bin" \
    "$verify_root/usr/bin" "$verify_root/bin" \
    "$verify_root/opt/mpi-station/external/mixxx-mk3/pi-setup"
  cp -a /usr/lib/systemd/system/. "$verify_root/usr/lib/systemd/system/"
  cp "$units"/* "$verify_root/etc/systemd/system/"

  for path in \
    usr/local/sbin/mpi-audio-profile \
    usr/local/sbin/mpi-configure-mixxx-controller \
    usr/local/sbin/mpi-mode-select \
    usr/local/sbin/mpi-station-first-boot \
    usr/local/bin/maschinepi \
    usr/local/bin/mk3-screen-daemon \
    usr/bin/Xvfb usr/bin/openbox usr/bin/xsetroot usr/bin/pw-jack usr/bin/python3 \
    bin/bash \
    opt/mpi-station/external/mixxx-mk3/pi-setup/mk3-bootsplash.sh \
    opt/mpi-station/external/mixxx-mk3/pi-setup/mk3-headphone-mirror.sh; do
    install -D -m 755 /bin/true "$verify_root/$path"
  done

  printf 'mpi:x:1000:1000::/home/mpi:/bin/bash\n' > "$verify_root/etc/passwd"
  printf 'audio:x:29:mpi\npipewire:x:995:mpi\nplugdev:x:46:mpi\n' > "$verify_root/etc/group"
  mapfile -t unit_names < <(find "$units" -maxdepth 1 -type f \
    \( -name '*.target' -o -name '*.service' \) -printf '%f\n')
  systemd-analyze --root="$verify_root" verify \
    --recursive-errors=no --generators=no --man=no "${unit_names[@]}"
fi

grep -q '^Conflicts=mixxx.target$' "$units/maschinepi.target"
grep -q '^Conflicts=maschinepi.target$' "$units/mixxx.target"
grep -q '^AllowIsolate=yes$' "$units/maschinepi.target"
grep -q '^AllowIsolate=yes$' "$units/mixxx.target"

for unit in maschinepi.service maschinepi-audio-profile.service; do
  grep -q '^PartOf=maschinepi.target$' "$units/$unit"
done

for unit in \
  mixxx.service mixxx-audio-profile.service xvfb.service openbox.service \
  mk3-bootsplash.service mk3-screen-daemon.service mk3-t9-daemon.service \
  mk3-mouse-daemon.service mk3-overlay.service mk3-headphone-mirror.service; do
  grep -q '^PartOf=mixxx.target$' "$units/$unit"
done

grep -q 'while systemctl is-active --quiet mk3-bootsplash.service' \
  "$units/mk3-screen-daemon.service"

if rg -n '^WantedBy=multi-user.target$' "$units"/maschinepi.service "$units"/mixxx.service \
    "$units"/xvfb.service "$units"/openbox.service "$units"/mk3-*.service; then
  echo "Application services must only be wanted by their mode target" >&2
  exit 1
fi

echo "systemd mode invariants: PASS"
