# Fused Raspberry Pi OS Lite image implementation plan (Phase 2b)

**Goal:** Produce a standard flashable arm64 Raspberry Pi OS Lite image that
contains ready-to-run distributions of both applications. Image creation must
not enable either application outside its mode target, and the target must not
compile or download packages.

## Decision

Use the supported MaschinePI **official-image injection** approach rather than
the older full pi-gen rebuild. The integrator injects its pinned release tree,
systemd policy, and provisioning entrypoint into a supplied Raspberry Pi OS
Lite arm64 image. A privileged helper container mounts the image, avoiding a
host root requirement. The initial on-Pi provisioner was rejected during
hardware bring-up. The integrator now cross-compiles every project-owned ARM64
binary, installs all runtime packages into the mounted rootfs under QEMU, and
injects the pinned Mixxx package. The image appends separately labeled Mixxx
library and MaschinePI sample filesystems.

## Tasks

- [x] Export a self-contained shallow release checkout with recursive submodules.
- [x] Add a rootfs installer that injects units, scripts, config, SSH/user setup,
  and the release checkout without executing foreign-architecture binaries.
- [x] Cross-compile MaschinePI, Mixxx helpers, and the selector on the host.
- [x] Provision packages, PipeWire, mappings, skin, splash, and user state into
  the mounted image on the host.
- [x] Add `MIXXX_LIBRARY` and preloaded `MPI_SAMPLES` partitions and fstab mounts.
- [x] Add a Docker-backed image mount/injection command with optional compression
  and SHA-256 output.
- [x] Add a rootfs fixture test proving default-target and enablement policy.
- [ ] Build the revised host-provisioned image and inspect all four filesystems.
- [ ] Flash and validate selector plus both modes on Raspberry Pi 4 hardware.

## Exit checks

- `tests/test-install-rootfs.sh` passes.
- The output is a partitioned `.img`/`.img.xz` with checksum.
- `default.target` selects `mode-selector.target`.
- The provision marker, ARM64 executables, runtime dependencies, Mixxx state,
  sample content, and both data filesystems exist before flashing.
- No first-boot build/provision service exists; app startup belongs solely to
  mode targets.
