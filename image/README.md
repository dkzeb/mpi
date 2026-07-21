# image/ — fused RPi OS Lite image build (Phase 2b)

Produces one flashable image with both stacks installed, gated behind the
systemd targets. The base approach is decided in Phase 2b: either extend the
MaschinePI image tooling (`external/maschinepi-te/pi-tools/`) or provision into
a stock Raspberry Pi OS Lite root filesystem. Either way, it then runs the
Mixxx provisioner (`external/mixxx-mk3/pi-setup/mk3-pi-setup.sh`, adapted for
non-interactive/chroot use) into the same rootfs, places on-device Git checkouts
(this repo plus submodules) for OTA, installs the Phase 3 units, and sets the
default target to `mode-selector.target`.

The build must reconcile shared components touched by both provisioners,
including PipeWire configuration, `99-mk3` udev rules, and the boot splash, so
the last writer is intentional.

See the design spec sections “Build / packaging” and “Risks & validations”.
