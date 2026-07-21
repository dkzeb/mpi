# mpi-station Scaffold Implementation Plan (Phase 2 of MK3 dual-mode)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the `mpi-station` integrator repo skeleton — the three app repos pinned as git submodules at known-good refs, a documented directory layout for the integrator-owned components (systemd targets, mode-selector, image build, OTA), and a migration inventory — so the later phases have a home. **This phase builds no image and runs no app code.** It is pure composition + documentation, verifiable by a clean recursive clone.

**Architecture:** `mpi-station` is the delivery/integrator repo for the MK3 dual-mode initiative (run MaschinePI DAW *or* MixxxDJ on one Raspberry Pi 4 + Maschine MK3, selected at boot). It composes releases by pinning three submodules and owns the code that neither app repo should own: the mutually-exclusive systemd targets, the `mk3-mode-selector` binary, the fused-image build, and the generalized OTA tooling. The app repos stay independently developable; the integrator bumps submodule refs to compose a tested release. Full design: `docs/specs/2026-07-21-mk3-dual-mode-shared-base-design.md` (authoritative — read it first).

**Tech Stack:** git submodules, shell, systemd units, C (the future `mk3-mode-selector` builds against the `libmk3` submodule). No build system is stood up in this phase beyond a submodule-presence check.

## Global Constraints

- Repo remote: **`git@github.com:dkzeb/mpi-station.git`** (private). Default branch **`main`**.
- The three submodules and their **pin refs at scaffold time**:
  - `external/libmk3` → `git@github.com:dkzeb/libmk3.git` @ **`24c5cc0`** (canonical master HEAD; the single source of truth for the MK3 driver — Phase 1 output).
  - `external/mixxx-mk3` → `git@github.com:dkzeb/mixxx-mk3.git` @ **`e80d138`** (branch `agent/libmk3-unification` — the version that consumes libmk3 as a submodule). **Re-pin to `master` once that PR merges** (remote `master` was `8bc51d9` at scaffold time and does *not* yet contain the submodule conversion).
  - `external/maschinepi-te` → `git@github.com:dkzeb/maschinepi-te.git` @ **`ff7cc6e`** (remote `main` HEAD at scaffold time).
- **Pinning policy (from spec):** each submodule is pinned to a specific commit; a release is composed by the integrator bumping those refs together and tagging. On-device OTA pulls the *integrator* repo, not each component's own branch. Do not set submodules to track branches.
- **Do not disturb the app repos.** mpi-station only *references* them by commit; it never pushes into them. Adding a submodule pin does not modify the referenced repo.
- Nested submodule: `mixxx-mk3` and `maschinepi-te` each already contain their own `external/mk3` libmk3 submodule. Recursive clone must bring those up too — always use `--recursive` / `submodule update --init --recursive`.
- This phase produces **no** `.img`, installs **no** systemd units on the host, and compiles **no** binaries. Those are Phases 2b–5, each with its own plan.

## Phase roadmap (context — each later phase gets its own plan in `docs/plans/`)

1. **libmk3 unification** — DONE (Phase 1; plan `docs/plans/2026-07-21-libmk3-unification.md`).
2. **mpi-station scaffold (this plan).**
2b. Fused RPi OS Lite image build (image-base approach — extend MaschinePI pi-gen vs. stock RPi OS Lite — is decided in this sub-phase, not before).
3. systemd `maschinepi.target` / `mixxx.target` / `mode-selector.target` + `isolate` switching.
4. `mk3-mode-selector` binary (Shift detection via libmk3 + evdev, MK3 menu, per-mode branding) — builds against the `external/libmk3` submodule.
5. OTA generalization + selector "update available" notification.

---

### Task 1: Add the three app repos as pinned submodules

Compose the integrator by referencing the three repos at their known-good refs. This is the core of the scaffold — after this, a recursive clone reproduces the exact release inputs.

**Files:**
- Create: `/home/zeb/dev/mpi-station/.gitmodules`
- Create: `/home/zeb/dev/mpi-station/external/libmk3` (submodule gitlink)
- Create: `/home/zeb/dev/mpi-station/external/mixxx-mk3` (submodule gitlink)
- Create: `/home/zeb/dev/mpi-station/external/maschinepi-te` (submodule gitlink)

**Interfaces:**
- Produces: three pinned submodules under `external/` that later phases build/provision from.

- [ ] **Step 1: Add each submodule at the same relative parent path**

```bash
cd /home/zeb/dev/mpi-station
git submodule add git@github.com:dkzeb/libmk3.git        external/libmk3
git submodule add git@github.com:dkzeb/mixxx-mk3.git     external/mixxx-mk3
git submodule add git@github.com:dkzeb/maschinepi-te.git external/maschinepi-te
```

- [ ] **Step 2: Pin each submodule to its known-good ref**

```bash
cd /home/zeb/dev/mpi-station/external/libmk3        && git checkout 24c5cc0 && cd -
cd /home/zeb/dev/mpi-station/external/mixxx-mk3     && git checkout e80d138 && cd -
cd /home/zeb/dev/mpi-station/external/maschinepi-te && git checkout ff7cc6e && cd -
cd /home/zeb/dev/mpi-station
git add .gitmodules external/libmk3 external/mixxx-mk3 external/maschinepi-te
```

- [ ] **Step 3: Bring up the nested submodules (mixxx-mk3 & maschinepi-te each contain libmk3)**

```bash
cd /home/zeb/dev/mpi-station
git submodule update --init --recursive
```
Expected: `external/mixxx-mk3/external/mk3` and `external/maschinepi-te/external/mk3` populate (both resolve to canonical libmk3 `24c5cc0`).

- [ ] **Step 4: Verify the pins**

```bash
git submodule status --recursive
```
Expected: top-level `external/libmk3` at `24c5cc0`, `external/mixxx-mk3` at `e80d138`, `external/maschinepi-te` at `ff7cc6e`; nested `external/mk3` entries at `24c5cc0`. No `+`/`-` prefixes after init.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat: add libmk3, mixxx-mk3, maschinepi-te as pinned submodules"
```

---

### Task 2: Establish the integrator directory layout with README stubs

Create the homes for the integrator-owned components so later phases drop code into an intentional structure, and document what each will hold (sourced from the design spec). Each README is a real orientation doc, not a placeholder.

**Files:**
- Create: `/home/zeb/dev/mpi-station/systemd/README.md`
- Create: `/home/zeb/dev/mpi-station/mode-selector/README.md`
- Create: `/home/zeb/dev/mpi-station/image/README.md`
- Create: `/home/zeb/dev/mpi-station/ota/README.md`
- Create: `/home/zeb/dev/mpi-station/config/README.md`

**Interfaces:**
- Produces: the top-level component directories referenced by Phases 2b–5.

- [ ] **Step 1: Create `systemd/README.md`**

```markdown
# systemd/ — mode targets & selector service (Phase 3)

Holds the integrator-owned units that make the two modes mutually exclusive
and boot the selector first:

- `maschinepi.target` — pulls in the MaschinePI DAW stack; `Conflicts=mixxx.target`.
- `mixxx.target` — pulls in Xvfb/Openbox/Mixxx/screen-daemon; `Conflicts=maschinepi.target`.
- `mode-selector.target` — the default boot target; starts `mk3-mode-selector.service`.
- `mk3-mode-selector.service` — runs the selector binary (Phase 4) before either app.

Switching is `systemctl isolate <target>` — no reboot. The system default is
`mode-selector.target`; neither app's own auto-start is enabled (the target owns
start-up). Clean teardown on `isolate` (release MK3 + audio before the other mode
claims them) is validated here via `Conflicts=` + explicit ordering.

See spec §"Mode switching" and §"Build / packaging".
```

- [ ] **Step 2: Create `mode-selector/README.md`**

```markdown
# mode-selector/ — the mk3-mode-selector binary (Phase 4)

A small, mode-agnostic C binary that:
- Owns the MK3 at boot via the `external/libmk3` submodule (render + input).
- Reads Shift (MK3 Shift **or** keyboard Shift via evdev) in a short poll window.
- If Shift held: renders a menu on the MK3 screens; D1 = MaschinePI, D2 = Mixxx;
  encoder scrolls; "set default" persists to the config store.
- Issues `systemctl isolate <target>` for the chosen mode.
- Surfaces an "update available" indicator (Phase 5) before either app starts.

Builds against `external/libmk3` directly (not MaschinePI's JUCE layer) to stay
small. Invisible unless Shift is held; no auto-timeout once summoned.

See spec §"Mode selector" and §"Resolved defaults".
```

- [ ] **Step 3: Create `image/README.md`**

```markdown
# image/ — fused RPi OS Lite image build (Phase 2b)

Produces ONE flashable image with both stacks installed, gated behind the
systemd targets. **The base approach is decided in Phase 2b, not before:**
either extend the MaschinePI pi-gen stage (`external/maschinepi-te/pi-tools/`)
as the base, or provision into a stock RPi OS Lite rootfs. Either way it then
runs the Mixxx provisioner (`external/mixxx-mk3/pi-setup/mk3-pi-setup.sh`,
adapted for non-interactive/chroot) into the same rootfs, places on-device git
checkouts (this repo + submodules) for OTA, installs the Phase 3 units, and sets
the default target to `mode-selector.target`.

Must reconcile shared components both provisioners touch (PipeWire config,
`99-mk3` udev rules, boot splash) so the last writer is intentional.

See spec §"Build / packaging" and §"Risks & validations".
```

- [ ] **Step 4: Create `ota/README.md`**

```markdown
# ota/ — generalized over-the-air update tooling (Phase 5)

The image is a seed, not the source of truth: the device carries on-device git
checkouts (this integrator repo + submodules) and updates in place via
`git pull` — no reflash. Generalizes the mechanism Mixxx already has
(`external/mixxx-mk3/pi-setup/mk3-update.sh` / `mk3-check-update.sh`).

- OTA pulls the **integrator** repo (advancing pinned submodules together), then
  runs each mode's idempotent re-provision entrypoint (rebuild-if-changed,
  reinstall units/binary, restart service).
- MaschinePI needs a NEW Mixxx-equivalent `update` entrypoint (it ships a
  pi-gen-baked binary with no OTA path today).
- The pre-boot update check/prompt must work headless too: factor render+input
  so the backend is swappable (libmk3/C-driver in MaschinePI mode, Xvfb/zenity
  in Mixxx mode). The mode-selector hosts the check and surfaces the indicator.

See spec §"OTA updates (no reflash)".
```

- [ ] **Step 5: Create `config/README.md`**

```markdown
# config/ — mode config store (Phase 3/4)

A single small file (target: `/var/lib/mk3-mode/config`) holds:
- `default_mode` — the target name booted when no Shift is held.
- A slot table: menu slot → target name → display label, so adding a third mode
  is a table row, not code.

The selector reads it at boot; the "set default" menu action writes it.

See spec §"Config store".
```

- [ ] **Step 6: Commit**

```bash
cd /home/zeb/dev/mpi-station
git add systemd/README.md mode-selector/README.md image/README.md ota/README.md config/README.md
git commit -m "docs: scaffold integrator component directories with orientation READMEs"
```

---

### Task 3: Top-level README + submodule-presence check script

Give the repo a front door: what it is, how to clone it, the pinning/release policy, and a one-command check that the composition is intact. The check script is the phase's executable verification.

**Files:**
- Create: `/home/zeb/dev/mpi-station/README.md`
- Create: `/home/zeb/dev/mpi-station/scripts/check-submodules.sh`

**Interfaces:**
- Consumes: the submodules from Task 1.
- Produces: `scripts/check-submodules.sh` — exit 0 iff all three submodules (and their nested libmk3) are present and at expected pins.

- [ ] **Step 1: Write `scripts/check-submodules.sh`**

```bash
#!/usr/bin/env bash
# Verify the mpi-station composition is intact: all submodules present, no gaps.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
check() { # path expected_short_sha
  local path="$1" want="$2"
  if [[ ! -e "$path/.git" ]]; then
    echo "MISSING: $path (run: git submodule update --init --recursive)"; fail=1; return
  fi
  local got; got="$(git -C "$path" rev-parse --short HEAD)"
  if [[ "$got" != "$want"* ]]; then
    echo "PIN DRIFT: $path at $got, expected $want"; fail=1
  else
    echo "OK: $path @ $got"
  fi
}

check external/libmk3        24c5cc0
check external/mixxx-mk3     e80d138
check external/maschinepi-te ff7cc6e
# nested libmk3 in each consumer
check external/mixxx-mk3/external/mk3     24c5cc0
check external/maschinepi-te/external/mk3 24c5cc0

exit $fail
```

- [ ] **Step 2: Make it executable and run it**

```bash
cd /home/zeb/dev/mpi-station
chmod +x scripts/check-submodules.sh
./scripts/check-submodules.sh
```
Expected: six `OK:` lines, exit 0. (If pins were bumped in a later release, update the expected shas in the script alongside the bump.)

- [ ] **Step 3: Write the top-level `README.md`**

```markdown
# mpi-station

Integrator/delivery repo for the **MK3 dual-mode** rig: one Raspberry Pi 4 +
Native Instruments Maschine MK3 that boots into **either** the MaschinePI DAW
**or** MixxxDJ, chosen at boot by holding Shift on the MK3 (or keyboard).

This repo owns what neither app repo should: the mutually-exclusive systemd
targets, the `mk3-mode-selector` binary, the fused RPi OS Lite image build, and
the generalized OTA tooling. It composes releases by pinning three submodules.

## Layout

| Path | Owns | Phase |
|---|---|---|
| `external/libmk3` | Shared C MK3 driver (single source of truth) | 1 (done) |
| `external/mixxx-mk3` | Mixxx provisioning + screen-daemon + mappings | — |
| `external/maschinepi-te` | MaschinePI DAW app + pi-tools | — |
| `systemd/` | Mode targets + selector service | 3 |
| `mode-selector/` | `mk3-mode-selector` binary | 4 |
| `image/` | Fused image build | 2b |
| `ota/` | Over-the-air update tooling | 5 |
| `config/` | Mode config store | 3/4 |
| `docs/specs/` | Authoritative design | — |
| `docs/plans/` | Per-phase implementation plans | — |

## Clone

```bash
git clone --recursive git@github.com:dkzeb/mpi-station.git
cd mpi-station && ./scripts/check-submodules.sh
```

If you cloned without `--recursive`:
`git submodule update --init --recursive`.

## Release / pinning policy

Each submodule is pinned to a specific commit. A release is composed by bumping
those pins **together** and tagging here; on-device OTA pulls this integrator
repo (advancing the pins as a set), never each component's own branch. This
guarantees reproducible, known-good combinations across both modes.

## Status

Phase 1 (libmk3 unification) done. This repo is the Phase 2 scaffold. See
`docs/plans/` for the roadmap and per-phase plans, and
`docs/specs/2026-07-21-mk3-dual-mode-shared-base-design.md` for the full design.

Pin note: `external/mixxx-mk3` currently points at branch
`agent/libmk3-unification` (`e80d138`), the first ref that consumes libmk3 as a
submodule. Re-pin to `master` once that PR merges.
```

- [ ] **Step 4: Commit**

```bash
cd /home/zeb/dev/mpi-station
git add README.md scripts/check-submodules.sh
git commit -m "docs: add top-level README and submodule-presence check"
```

---

### Task 4: Migration inventory — code to move here from the app repos

The spec's migration note: the mode-switching/selector/target/OTA code being
prototyped in `maschinepi-te` (and the OTA scripts living in `mixxx-mk3`) is
**not** long-term app code — its home is this integrator repo. Produce a concrete
inventory so the executing agent of Phases 3–5 knows exactly what to move, from
where, to where.

**Files:**
- Create: `/home/zeb/dev/mpi-station/docs/migration-inventory.md`

**Interfaces:**
- Consumes: the submodules from Task 1 (read-only; the inventory is produced by grepping the pinned checkouts).
- Produces: `docs/migration-inventory.md` — a per-item table feeding Phases 3–5.

- [ ] **Step 1: Survey the app repos for integrator-bound code**

Grep the pinned submodule checkouts for mode-switch / selector / target / OTA
artifacts. Suggested search seeds (run inside `external/maschinepi-te` and
`external/mixxx-mk3`):

```bash
cd /home/zeb/dev/mpi-station
grep -rniE "mode-selector|systemctl isolate|maschinepi\.target|mixxx\.target|mode-selector\.target" external/maschinepi-te --include=*.{sh,c,cpp,service,target,md} 2>/dev/null
grep -rniE "mk3-update|mk3-check-update|ExecStartPre|zenity" external/mixxx-mk3 --include=*.{sh,service,py,md} 2>/dev/null
ls external/mixxx-mk3/pi-setup/*.sh external/maschinepi-te/pi-tools/*.sh 2>/dev/null
```

- [ ] **Step 2: Write `docs/migration-inventory.md`**

Record a table with columns: **item → current location (repo:path) → destination (mpi-station dir) → migration action → phase**. Cover at minimum:
- Any mode-selector / `systemctl isolate` prototype code in `maschinepi-te` → `mode-selector/` + `systemd/` (Phases 3–4).
- Mixxx OTA scripts `pi-setup/mk3-update.sh`, `pi-setup/mk3-check-update.sh` → `ota/` (generalize per-mode) (Phase 5).
- Mixxx provisioner `pi-setup/mk3-pi-setup.sh` → referenced by `image/` build, adapted non-interactive (Phase 2b).
- MaschinePI pi-gen stage `pi-tools/` → base option for `image/` (Phase 2b).
- The "MaschinePI has no OTA entrypoint" gap → new `ota/` work item (Phase 5).

For each item note whether it is **moved** (home changes to mpi-station) or
**referenced in place** (stays in the app repo, invoked by the integrator).
Include a one-line rationale per row.

- [ ] **Step 3: Commit**

```bash
cd /home/zeb/dev/mpi-station
git add docs/migration-inventory.md
git commit -m "docs: inventory app-repo code to migrate into the integrator"
```

---

## Phase-2 exit check

Confirm all of:
- `git clone --recursive` of `dkzeb/mpi-station` lands all three submodules + nested libmk3 at the expected pins (`./scripts/check-submodules.sh` exits 0).
- Component directories (`systemd/`, `mode-selector/`, `image/`, `ota/`, `config/`) exist with orientation READMEs.
- Top-level README documents the layout, clone flow, and pinning policy.
- `docs/migration-inventory.md` lists every integrator-bound item with source, destination, and phase.
- The spec is present at `docs/specs/2026-07-21-mk3-dual-mode-shared-base-design.md`.

Scaffold done → Phase 2b (image build) can begin. No image, units, or binaries were produced in this phase — that is intentional.

## Self-Review notes

- **Scope:** deliberately narrow — composition + docs only. Image fusion (2b), targets (3), selector (4), OTA (5) are each their own plan; this plan only stands up their home and pins the inputs. This keeps Phase 2 independently testable (a clean recursive clone) without dragging in pi-gen/Mixxx provisioning.
- **Pinning exactness:** all three pins are concrete commits resolved at scaffold time. The one soft spot — `mixxx-mk3` pointing at an unmerged branch (`e80d138`) rather than `master` — is called out in Global Constraints, the README, and here, with the explicit re-pin action once the PR merges.
- **Nested submodules:** `mixxx-mk3` and `maschinepi-te` both carry their own `external/mk3` libmk3 submodule; every clone/update step uses `--recursive`, and the check script verifies the nested pins resolve to canonical `24c5cc0` — proving the "one libmk3" premise holds through the composition.
- **No app-repo mutation:** mpi-station only references the app repos by commit; nothing here pushes into them.
