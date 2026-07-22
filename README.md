# mpi-station

**One Raspberry Pi + Native Instruments Maschine MK3, two instruments.**
mpi-station builds and ships a single flashable image that boots into either:

- **MaschinePI** — a headless [Tracktion-based DAW / groovebox](https://github.com/dkzeb/maschinepi-te), or
- **MixxxDJ** — [Mixxx DJ software with full MK3 control](https://github.com/dkzeb/mixxx-mk3),

chosen at boot by holding **Shift** on the MK3 (or a keyboard). Switch modes,
reboot, and the same hardware becomes a different instrument.

## Download & flash (recommended)

You do not need to build anything. Grab the latest ready-to-run image and flash
it to an SD card.

1. **Download** the newest `mpi-station-*.img.xz` from the
   [Releases page](https://github.com/dkzeb/mpi-station/releases).
2. **Flash** it to an SD card (16 GB or larger) with
   [Raspberry Pi Imager](https://www.raspberrypi.com/software/) (choose *Use
   custom image*), [balenaEtcher](https://etcher.balena.io/), or `dd`:
   ```bash
   xz -dc mpi-station-YYYYMMDD.img.xz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
   ```
   Replace `/dev/sdX` with your card — double-check it, `dd` is unforgiving.
3. **Boot** the Pi with the MK3 connected. On first boot the image expands to
   fill the card and provisions two data partitions (your Mixxx library and your
   MaschinePI samples).
4. **Pick a mode:** hold **Shift** during boot to choose MixxxDJ or MaschinePI.

### First boot

- Default login: **`mpi` / `maschinepi`**. Change the password before putting the
  device on an untrusted network.
- Two storage areas are created automatically and grow to fill the card:
  `MIXXX_LIBRARY` → `/home/mpi/Music`, and `MPI_SAMPLES` →
  `/home/mpi/maschinepi/samples` (preloaded with a starter sample set).

## What this repository is

mpi-station is the **integrator / delivery** repo. It owns what neither
application repo should: the mutually exclusive systemd mode targets, the
`mk3-mode-selector`, the fused image build, and over-the-air update tooling. A
release is a reproducible combination of three pinned submodules.

| Path | Owns |
|---|---|
| `external/libmk3` | Shared C MK3 driver — single source of truth |
| `external/mixxx-mk3` | Mixxx provisioning, screen daemon, mappings |
| `external/maschinepi-te` | MaschinePI DAW and Pi image tooling |
| `image/` | Fused Raspberry Pi OS Lite image build |
| `systemd/` | Mode targets and selector service |
| `mode-selector/` | `mk3-mode-selector` binary |
| `ota/` | Over-the-air update tooling |
| `config/` | Mode config store |
| `docs/specs/`, `docs/plans/` | Authoritative design and per-phase plans |

## Build the image yourself (developers)

```bash
git clone --recursive git@github.com:dkzeb/mpi-station.git
cd mpi-station
git submodule update --init --recursive        # if not cloned with --recursive
./scripts/check-submodules.sh
```

Build a fused image from a stock Raspberry Pi OS Lite (arm64) base. All
compilation, package installation, and provisioning happen on the host (inside
the `pi-gen` helper container — no host `sudo` needed for the mount step):

```bash
./image/build-image.sh --base /path/to/raspios-lite-arm64.img.xz --compress
```

Useful flags: `--maschinepi-binary /path/to/arm64/maschinepi` reuses an existing
ARM64 build; `--password` sets the injected login; `--data-bootstrap-mb` sizes
the pre-boot data partitions. See [`image/README.md`](image/README.md) for the
full pipeline and [`docs/hardware-test.md`](docs/hardware-test.md) for on-device
validation.

Host-side checks:

```bash
./tests/test-systemd-modes.sh
./tests/test-install-rootfs.sh
./tests/test-mode-selector.sh
```

## Releases & updates

Each submodule is pinned to a specific commit; a release bumps all three pins
together and tags them here. On-device OTA advances the pinned set as a unit
rather than letting components track branches, so every unit runs a known-good
combination. See [`ota/README.md`](ota/README.md).

## Contributing

Read [AGENTS.md](AGENTS.md) and the design spec in `docs/specs/` before working
here. The driver (`external/libmk3`) is canonical
[libmk3](https://github.com/dkzeb/libmk3) — never edit a vendored copy; changes
go upstream and are pulled in by bumping the pin.

## License

Copyright (C) 2026 Sebastian Hines.

The mpi-station tooling (image builder, mode selector, systemd units, OTA
scripts) is released under the **GNU General Public License v3.0** — see
[`LICENSE`](LICENSE).

The **flashable image** it produces is a *mere aggregation* of separately
licensed works, each retaining its own license: Raspberry Pi OS, MixxxDJ
(GPLv2+), MaschinePI (GPLv3), the [libmk3](https://github.com/dkzeb/libmk3)
driver (MIT), and vendor firmware. Bundling them on one SD card does not
relicense any of them. GPL permits redistribution and does not prevent accepting
donations.
