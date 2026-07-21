# image/ — fused Raspberry Pi OS Lite image build (Phase 2b)

Produces one flashable image with both stacks installed and gated behind the
systemd mode targets. Phase 2b chose the supported MaschinePI official-image
injection approach: supply a stock Raspberry Pi OS Lite arm64 image and perform
all compilation, package installation, and provisioning on the host.

```bash
./image/build-image.sh --base /path/to/raspios-lite-arm64.img.xz --compress
```

The mount/injection step runs in the existing `pi-gen:latest` helper container,
so host sudo is not required. The root filesystem receives 1024 MiB of build
headroom. Two labeled ext4 partitions are appended by default:

- `MIXXX_LIBRARY` (2048 MiB), mounted at `/home/mpi/Music`.
- `MPI_SAMPLES` (2048 MiB), mounted at
  `/home/mpi/maschinepi/samples` and preloaded with the pinned sample set.

Override their capacities with `--mixxx-library-mb` and `--samples-mb`.
MaschinePI, the Mixxx screen tools, and the selector are cross-compiled on the
host. Runtime packages and the pinned Mixxx ARM64 package are installed into the
mounted rootfs under QEMU. No compilation, package download, or provisioning is
performed by the Pi. Pass
`--maschinepi-binary /path/to/arm64/maschinepi` to reuse an existing ARM64
artifact.

The injected test login is `mpi` / `maschinepi` unless `--password` is supplied.
Change it before putting the device on an untrusted network.

The build must reconcile shared components touched by both provisioners,
including PipeWire configuration, `99-mk3` udev rules, and the boot splash, so
the last writer is intentional.

See `docs/plans/2026-07-21-fused-image-build.md` and `docs/hardware-test.md`.
