# Host-built ready image and boot selector plan

**Goal:** Deliver one flashable Raspberry Pi 4 image that starts without target
compilation or package downloads, lets the user select MaschinePI or Mixxx at
boot, and exposes dedicated Mixxx-library and MaschinePI-sample filesystems.

## Required image contract

- The host cross-compiles `maschinepi`, `mk3-screen-daemon`, `mk3`, and
  `mk3-mode-selector` for ARM64.
- The pinned Mixxx ARM64 package and all runtime dependencies are installed into
  the mounted rootfs during image assembly under QEMU.
- `mode-selector.target` is the default. Shift on the MK3 or a keyboard opens a
  no-timeout menu; D1/D2 or encoder/push selects a mode; D8 persists the default.
- Partition 3 is ext4 label `MIXXX_LIBRARY`, mounted at `/home/mpi/Music`.
- Partition 4 is ext4 label `MPI_SAMPLES`, mounted at
  `/home/mpi/maschinepi/samples`, with `external/maschinepi-te/samples` copied in.
- Raspberry Pi OS root auto-expansion is disabled because root is no longer the
  last partition.
- Neither target contains a compiler-driven or network-driven first-boot step.

## Implementation gates

- [x] Cross-build MaschinePI and Mixxx MK3 helpers on the host.
- [x] Implement and cross-build the `libmk3`-based selector with native behavior
  tests.
- [x] Add the Mixxx-entry HID rebind required after MaschinePI releases USB.
- [x] Replace target-side provisioning with mounted-rootfs host provisioning.
- [x] Add and populate the two labeled data partitions.
- [ ] Build and inspect a fresh output image from a stock Raspberry Pi OS Lite
  ARM64 base.
- [ ] Hardware-validate no-Shift default boot, MK3 Shift menu, keyboard Shift
  menu, both direct selections, persisted default, audio, display, HID, and
  repeated mode switching.

## Evidence

- `tests/test-mode-selector.sh`
- `tests/test-systemd-modes.sh`
- `tests/test-install-rootfs.sh`
- `image/inspect-image.sh OUTPUT.img[.xz]`
- Hardware procedure: `docs/hardware-test.md`
