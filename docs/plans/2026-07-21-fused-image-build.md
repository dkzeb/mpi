# Fused Raspberry Pi OS Lite image implementation plan (Phase 2b)

**Goal:** Produce a standard flashable arm64 Raspberry Pi OS Lite image that
contains the pinned mpi-station release and provisions both applications on its
first hardware boot. Image creation must not enable either application outside
its mode target.

## Decision

Use the supported MaschinePI **official-image injection** approach rather than
the older full pi-gen rebuild. The integrator injects its pinned release tree,
systemd policy, and provisioning entrypoint into a supplied Raspberry Pi OS
Lite arm64 image. A privileged helper container mounts the image, avoiding a
host root requirement. The Pi performs apt installation and native builds once,
then records `/var/lib/mpi-station/provisioned` and reboots.

An optional prebuilt ARM64 MaschinePI binary avoids the long native build. The
pinned Mixxx arm64 package is already carried by `mixxx-mk3`.

## Tasks

- [x] Export a self-contained shallow release checkout with recursive submodules.
- [x] Add a rootfs installer that injects units, scripts, config, SSH/user setup,
  and the release checkout without executing foreign-architecture binaries.
- [x] Add one-time Pi provisioning for dependencies, builds, PipeWire, mappings,
  skin, splash, and user state.
- [x] Add a Docker-backed image mount/injection command with optional compression
  and SHA-256 output.
- [x] Add a rootfs fixture test proving default-target and enablement policy.
- [x] Build against Raspberry Pi OS Lite arm64 2026-06-18 and inspect the
  resulting partitions and injected files.
- [ ] Flash and complete first-boot provisioning on Raspberry Pi 4 hardware.

## Exit checks

- `tests/test-install-rootfs.sh` passes.
- The output is a partitioned `.img`/`.img.xz` with checksum.
- `default.target` selects `mode-selector.target`.
- Only `mpi-station-first-boot.service` and SSH are enabled globally by the
  injection; app startup belongs solely to mode targets.
