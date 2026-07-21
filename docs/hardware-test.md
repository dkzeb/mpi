# Raspberry Pi 4 image and mode test

This procedure validates the Phase 2b image and Phase 3 systemd targets on a
Raspberry Pi 4 with a Maschine MK3. Phase 4's Shift/menu selector is not part of
this test yet; mode selection is the stored default plus an SSH command.

## 1. Build the image

Download a stock Raspberry Pi OS Lite **arm64** image, then run:

```bash
./image/build-image.sh \
  --base /path/to/raspios-lite-arm64.img.xz \
  --output image/output/mpi-station-test.img \
  --compress
```

If an ARM64 MaschinePI binary is available, add:

```bash
--maschinepi-binary /path/to/maschinepi
```

Without it, the Pi builds MaschinePI on first boot. The build emits the image
and a neighboring `.sha256` file. Verify it before flashing:

```bash
(cd image/output && sha256sum -c mpi-station-test.img.xz.sha256)
MPI_BUILD_TMPDIR=/dev/shm ./image/inspect-image.sh \
  image/output/mpi-station-test.img.xz
```

## 2. Flash and provision

Prefer Raspberry Pi Imager's “Use custom image” flow. If using `dd`, identify
the SD-card device carefully; the output device is overwritten:

```bash
xz -dc image/output/mpi-station-test.img.xz | \
  sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```

Connect Ethernet for the first boot. Attach the MK3 before the second boot so
both modes can be tested. The temporary image login is:

- user: `mpi`
- password: `maschinepi` (or the `--password` value used at build time)
- hostname: `mpi-station`

First boot installs packages and builds missing binaries, writes
`/var/lib/mpi-station/provisioned`, and reboots. This can take a long time when
MaschinePI is built on the Pi. Follow progress over the serial console or SSH:

```bash
journalctl -fu mpi-station-first-boot.service
```

After the automatic reboot, the default `maschinepi.target` should start.

## 3. Verify target ownership and switching

```bash
systemctl get-default
systemctl is-active maschinepi.target
systemctl is-active mixxx.target
systemctl status maschinepi.service --no-pager
```

Expected: default is `mode-selector.target`, MaschinePI target/service are
active, and Mixxx is inactive.

Switch to Mixxx:

```bash
sudo mpi-mode-switch mixxx
systemctl is-active mixxx.target
systemctl is-active maschinepi.service
systemctl status mixxx.service mk3-screen-daemon.service --no-pager
```

Expected: Mixxx appears across both MK3 screens, its controller mapping is live,
master audio uses MK3 outputs, and cue/headphone audio uses the Pi jack. The
MaschinePI service must be inactive.

Switch back:

```bash
sudo mpi-mode-switch maschinepi
systemctl is-active maschinepi.target
systemctl is-active mixxx.service xvfb.service openbox.service \
  mk3-screen-daemon.service mk3-t9-daemon.service mk3-mouse-daemon.service \
  mk3-overlay.service
```

Expected: MaschinePI owns the displays/controller and every listed Mixxx unit is
inactive. Repeat Mixxx → MaschinePI → Mixxx at least twice to catch delayed USB
or PipeWire release.

Inspect audio and logs after each transition:

```bash
sudo -u mpi XDG_RUNTIME_DIR=/run/user/1000 wpctl status
journalctl -b -u maschinepi.service -u mixxx.service \
  -u mk3-screen-daemon.service -u '*audio-profile.service' --no-pager
```

Persist a different default and reboot:

```bash
sudo mpi-mode-switch --set-default mixxx
sudo reboot
```

Expected: the next boot still has `mode-selector.target` as the system default,
but the selector isolates `mixxx.target`.

## 4. Capture failures

If first-boot provisioning fails, it intentionally leaves the provision marker
absent so the service retries on the next boot. Capture:

```bash
journalctl -b -u mpi-station-first-boot.service --no-pager
systemctl --failed --no-pager
git -C /opt/mpi-station submodule status --recursive
```

For mode-switch failures, also record `lsusb -t`, `wpctl status`, and the unit
logs above before rebooting; teardown behavior cannot be diagnosed afterward.
