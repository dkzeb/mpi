# systemd modes implementation plan (Phase 3)

**Goal:** Boot or switch into MaschinePI or MixxxDJ without rebooting while
ensuring the inactive application releases the MK3 and audio devices.

## Runtime contract

- All three custom targets retain `multi-user.target` for SSH/network access.
- `maschinepi.target` and `mixxx.target` conflict and are isolatable.
- Every application/audio service is `PartOf=` its owning target, so stopping a
  target stops the full stack. This is required in addition to target conflicts.
- App services are not enabled under `multi-user.target`.
- Phase 3 uses a stored-default shell selector. Phase 4 replaces its backend
  with MK3/keyboard Shift detection and the on-screen menu without changing the
  target interface.

## Tasks

- [x] Implement selector, MaschinePI, and Mixxx targets.
- [x] Implement target-owned MaschinePI and Mixxx service bundles.
- [x] Implement per-mode PipeWire quantum/rate activation and reset.
- [x] Add stored default and `mpi-mode-switch` for SSH hardware testing.
- [x] Add static tests for conflicts, isolation, ownership, and enablement.
- [ ] Verify boot into the stored default on Raspberry Pi 4.
- [ ] Isolate Mixxx → MaschinePI → Mixxx and verify complete device/audio release.

## Hardware commands

```bash
sudo mpi-mode-switch mixxx
sudo mpi-mode-switch maschinepi
sudo mpi-mode-switch --set-default mixxx
systemctl list-units 'mixxx*' 'maschinepi*' 'mk3*' 'xvfb*' 'openbox*'
journalctl -b -u mpi-station-first-boot -u mk3-mode-selector
```
