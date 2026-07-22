# Integrator migration inventory

Surveyed against the Phase 2 pins on 2026-07-21. “Move” means mpi-station owns
the resulting generalized implementation. “Reference” means the app-specific
source remains in its application repository and is invoked or packaged by the
integrator.

| Item | Current location | Destination | Action | Phase | Rationale |
|---|---|---|---|---|---|
| Mode targets and selector service | No prototype found at `maschinepi-te@ff7cc6e` | `systemd/` | Create here | 3 | Cross-application startup and exclusion belong to the integrator. |
| Mode selector binary | No prototype found at `maschinepi-te@ff7cc6e` | `mode-selector/` | Create here | 4 | It owns the controller before either app and must remain mode-agnostic. |
| MusicPI service | `maschinepi-te:pi-tools/maschinepi.service` | `systemd/` | Reference and install with integrator overrides | 2b/3 | App-specific launch details stay with MusicPI; target ownership belongs here. |
| MusicPI first-boot and realtime setup | `maschinepi-te:pi-tools/first-boot.*`, `realtime-config.sh`, `pi-image-setup.sh` | `image/` | Reference; adapt through image-build configuration | 2b | These are application provisioning inputs, not shared runtime policy. |
| MusicPI boot display/listener | `maschinepi-te:pi-tools/mk3-boot-display.*`, `mk3-boot-listener.*` | `mode-selector/`, `image/assets/` | Reuse branding/assets; migrate selector-relevant behavior | 4 | The selector owns the MK3 during boot and replaces app-specific boot ownership. |
| MusicPI image pipeline | `maschinepi-te:pi-tools/`, repository `scripts/gen-img.sh` | `image/` | Reference as one candidate base | 2b | The base choice must be made after comparing it with stock RPi OS Lite provisioning. |
| Mixxx provisioner | `mixxx-mk3:pi-setup/mk3-pi-setup.sh` | `image/` | Reference and invoke in noninteractive/chroot mode | 2b | App provisioning stays upstream; fused-image orchestration belongs here. |
| Mixxx service bundle | `mixxx-mk3:pi-setup/*.service`, NAS mount | `systemd/` | Reference app units; install integrator target/drop-ins | 2b/3 | The target must start the bundle without enabling each service globally. |
| Mixxx update entrypoint | `mixxx-mk3:pi-setup/mk3-update.sh` | `ota/` | Generalize per mode | 5 | OTA advances the integrator's pins as one tested release. |
| Mixxx pre-boot update prompt | `mixxx-mk3:pi-setup/mk3-check-update.sh`, `mk3-button-reader.py` | `ota/`, `mode-selector/` | Move check policy; replace X-only UI with selector backend | 5 | Update status must appear before either X or the DAW starts. |
| MusicPI update entrypoint | Missing | `ota/` | Create | 5 | MusicPI currently has no in-place pull/build/install/restart path. |
| Shared udev policy | Both repos' `pi-tools/99-mk3.rules` / `pi-setup/99-mk3.rules` | `image/` | Reconcile into one intentionally installed rule | 2b | Avoid accidental last-writer behavior in the fused rootfs. |
| Shared PipeWire policy | MusicPI realtime/image scripts and Mixxx provisioner | `image/`, `systemd/` | Reconcile base install; apply per-mode runtime profiles | 2b/3 | Both modes share one user PipeWire instance but need different routing/tuning. |

No `systemctl isolate`, `*.target`, or mode-selector prototype was present in the
pinned MusicPI checkout. Phases 3–4 therefore create those artifacts here
rather than moving existing code.
