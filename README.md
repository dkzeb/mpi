# mpi-station

Integrator/delivery repository for the **MK3 dual-mode** rig: one Raspberry Pi
4 plus Native Instruments Maschine MK3 that boots into either the MaschinePI
DAW or MixxxDJ, chosen at boot by holding Shift on the MK3 or a keyboard.

This repository owns what neither application repository should: the mutually
exclusive systemd targets, the `mk3-mode-selector` binary, the fused Raspberry
Pi OS Lite image build, and generalized OTA tooling. Releases are composed by
pinning three submodules.

## Layout

| Path | Owns | Phase |
|---|---|---|
| `external/libmk3` | Shared C MK3 driver (single source of truth) | 1 (done) |
| `external/mixxx-mk3` | Mixxx provisioning, screen daemon, mappings | — |
| `external/maschinepi-te` | MaschinePI DAW and Pi image tooling | — |
| `systemd/` | Mode targets and selector service | 3 |
| `mode-selector/` | `mk3-mode-selector` binary | 4 |
| `image/` | Fused image build | 2b |
| `ota/` | Over-the-air update tooling | 5 |
| `config/` | Mode config store | 3/4 |
| `docs/specs/` | Authoritative design | — |
| `docs/plans/` | Per-phase implementation plans | — |

## Clone

```bash
git clone --recursive git@github.com:dkzeb/mpi-station.git
cd mpi-station
./scripts/check-submodules.sh
```

If cloned without `--recursive`, run:

```bash
git submodule update --init --recursive
```

## Release and pinning policy

Each submodule is pinned to a specific commit. A release bumps the pins together
and is tagged here. On-device OTA pulls this integrator repository, advancing
the pins as a set, rather than allowing each component to track a branch. This
keeps both modes on a reproducible, known-good combination.

## Status

Phase 1 (libmk3 unification) and Phase 2 (integrator scaffold) are complete.
The Phase 2b image injector and Phase 3 systemd modes are implemented and await
image/Raspberry Pi 4 validation. Run the host-side checks with:

```bash
./tests/test-systemd-modes.sh
./tests/test-install-rootfs.sh
```

Build and hardware instructions are in `docs/hardware-test.md`. See
`docs/plans/` for the roadmap and
`docs/specs/2026-07-21-mk3-dual-mode-shared-base-design.md` for the full design.

`external/mixxx-mk3` currently points at `e80d138` from branch
`agent/libmk3-unification`, the first hardware-verified ref that consumes
libmk3 as a submodule. Re-pin it to `master` once that work merges.
