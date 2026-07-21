# image/ — fused Raspberry Pi OS Lite image build (Phase 2b)

Produces one flashable image with both stacks installed and gated behind the
systemd mode targets. Phase 2b chose the supported MaschinePI official-image
injection approach: supply a stock Raspberry Pi OS Lite arm64 image and inject
the pinned integrator release plus a one-time hardware provisioner.

```bash
./image/build-image.sh --base /path/to/raspios-lite-arm64.img.xz --compress
```

The mount/injection step runs in the existing `pi-gen:latest` helper container,
so host sudo is not required. On first Pi boot, Ethernet/Wi-Fi is required while
the provisioner installs dependencies, installs the pinned Mixxx arm64 package,
and builds the MK3 screen tooling. By default it also builds MaschinePI natively;
pass `--maschinepi-binary /path/to/arm64/maschinepi` to avoid that long build.

The injected test login is `mpi` / `maschinepi` unless `--password` is supplied.
Change it before putting the device on an untrusted network.

The build must reconcile shared components touched by both provisioners,
including PipeWire configuration, `99-mk3` udev rules, and the boot splash, so
the last writer is intentional.

See `docs/plans/2026-07-21-fused-image-build.md` and `docs/hardware-test.md`.
