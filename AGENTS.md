# AGENTS.md — start here

This is **mpi-station**, the integrator/delivery repo for the MK3 dual-mode
initiative: one Raspberry Pi 4 + Maschine MK3 that boots into **either** the
MaschinePI DAW **or** MixxxDJ, chosen at boot by holding Shift.

## Current state

This repo is a **fresh scaffold**. It currently contains only documentation —
no submodules, code, units, or image yet. Your job is to execute the Phase 2
scaffold plan, which stands up the composition (three pinned submodules) and the
integrator's directory layout.

## Read in this order

1. `docs/specs/2026-07-21-mk3-dual-mode-shared-base-design.md` — the authoritative
   whole-initiative design. Read it before acting.
2. `docs/plans/2026-07-21-mpi-station-scaffold.md` — **the plan to execute now**
   (Phase 2). Bite-sized, TDD-style, exact commands. Use
   `superpowers:subagent-driven-development` or `superpowers:executing-plans`.
3. `docs/plans/2026-07-21-libmk3-unification.md` — Phase 1 (DONE), included for
   history/context. It explains why `libmk3` is the single source of truth and
   how the pins were established.

## Roadmap (each later phase gets its own plan in `docs/plans/`)

1. libmk3 unification — **DONE**.
2. **mpi-station scaffold — the current plan.**
2b. Fused RPi OS Lite image build (image-base approach decided here, not before).
3. systemd targets + `isolate` switching.
4. `mk3-mode-selector` binary.
5. OTA generalization + "update available" notification.

## Ground rules

- **Never mutate the app repos** (`libmk3`, `mixxx-mk3`, `maschinepi-te`). This
  repo only *references* them by commit via submodules.
- **Pinning policy:** submodules are pinned to specific commits, bumped together
  as a release. Do not set them to track branches.
- Always clone/update with `--recursive` — `mixxx-mk3` and `maschinepi-te` each
  nest their own `libmk3` submodule.
- Phase 2 produces **no** image, units, or binaries. Keep it to composition +
  docs; defer everything else to its own phase/plan.
