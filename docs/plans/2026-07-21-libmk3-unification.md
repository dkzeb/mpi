# libmk3 Unification Implementation Plan (Phase 1 of MK3 dual-mode)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `dkzeb/libmk3` the single source of truth for the MK3 driver so both MaschinePI and MixxxDJ (and, later, the mode-selector) build against one library — eliminating Mixxx's stale vendored copy.

**Architecture:** `maschinepi-te` already consumes libmk3 as a submodule (`external/mk3` → `git@github.com:dkzeb/libmk3.git`, currently pinned at `24c5cc0`) and is the newest version. `mixxx-mk3` carries a stale *vendored copy* (no submodule) that its screen-daemon, `mk3_cli`, and audio tools build against. This phase audits the drift, ports any Mixxx-only behavior upstream into `dkzeb/libmk3`, then replaces Mixxx's copy with a submodule pinned to the canonical ref, and rebuilds the Mixxx tooling against it.

**Where the work happens:** All libmk3 source edits happen in the **standalone clone `/home/zeb/dev/libmk3`** (remote `dkzeb/libmk3`), NOT through `mpi-te/external/mk3` — mpi-te has unrelated work in flight and stays untouched except for a one-line submodule-pin bump at the end. The clone has been prepared: `master` is clean at canonical `24c5cc0`; prior local experiments (LED-probe diagnostic tools, indexed-color cap removal) are preserved on branch `wip/led-probe-experiments`. mpi-te is used only as the read-only *verification harness* — its parity tests are the correctness gate.

**Tech Stack:** C11 (`libmk3`), CMake, `libusb-1.0`, GoogleTest (mpi-te parity tests), git submodules.

## Global Constraints

- Canonical libmk3 repo: **`git@github.com:dkzeb/libmk3.git`**, working checkout **`/home/zeb/dev/libmk3`**. All shared driver changes land there, never in a consumer's tree (never in `mpi-te/external/mk3` or `mixxx-mk3/external/mk3`).
- Canonical baseline = the ref `maschinepi-te` currently pins (`external/mk3` @ `24c5cc0`) or newer — never regress below it. `/home/zeb/dev/libmk3` `master` is already at this ref.
- Do not disturb mpi-te's in-flight work: mpi-te is touched only to run parity tests (read-only) and to bump its submodule pin once, at the end.
- libmk3 is **C11**, public API prefixed `mk3_`, opaque `mk3_t`, `goto cleanup` error pattern (per `mixxx-mk3/CLAUDE.md`). Preserve these conventions.
- MK3 USB identity is fixed: vendor `0x17CC`, product `0x1600`, HID iface 4, display iface 5.
- The mpi-te parity tests (gtest suites `Mk3DisplayParityTest`, `Mk3HidMapParityTest`, `Mk3InputReportParityTest` — 18 tests total — in files `tests/Mk3*ParityTests.cpp`) are the correctness gate for canonical libmk3 — they must stay green throughout.
- Do not create or push the future integrator repo in this phase; that is Phase 2.

## Phase roadmap (context — each later phase gets its own plan)

1. **libmk3 unification (this plan).**
2. Integrator repo `mpi-station` + fused RPi OS Lite image build.
3. systemd `maschinepi.target` / `mixxx.target` / `mode-selector.target` + `isolate` switching.
4. `mk3-mode-selector` binary (Shift detection via libmk3 + evdev, MK3 menu, per-mode branding).
5. OTA generalization + selector update-available notification.

Full design: `docs/superpowers/specs/2026-07-21-mk3-dual-mode-shared-base-design.md`.

---

### Task 1: Establish the canonical baseline (known-good reference)

Prove canonical libmk3 builds and the parity tests pass *before* touching Mixxx, so any later regression is attributable.

**Files:**
- Read: `/home/zeb/dev/libmk3/*` (canonical libmk3 working checkout)
- Read: `tests/Mk3DisplayParityTests.cpp`, `tests/Mk3HidMapParityTests.cpp`, `tests/Mk3InputReportParityTests.cpp` (in mpi-te — the verification harness)

**Interfaces:**
- Produces: the verified canonical ref `CANON_REF` (the exact commit SHA of `/home/zeb/dev/libmk3` `master`) that Mixxx will pin to in Task 4.

- [x] **Step 1: Record the canonical libmk3 ref** — `CANON_REF = 24c5cc0`. Confirmed `/home/zeb/dev/libmk3` master, mpi-te's pin, and this worktree's `external/mk3` all match.

```bash
cd /home/zeb/dev/libmk3 && git rev-parse --short master   # CANON_REF (expected 24c5cc0)
# Confirm it matches what mpi-te already pins:
cd /home/zeb/dev/mpi-te && git submodule status external/mk3
```
Expected: both show `24c5cc0`. Record it as `CANON_REF` for Tasks 3–4.

- [x] **Step 2: Build the mpi-te test suite** — built in the isolated worktree (`.claude/worktrees/admiring-ritchie-adfc6f`) to avoid disturbing in-flight main-repo work; `./mpi build headless` exit 0.

```bash
cd /home/zeb/dev/mpi-te && ./mpi build headless
```
Expected: build succeeds.

- [x] **Step 3: Run the MK3 parity tests (the correctness gate)** — 18/18 PASS (`Mk3DisplayParityTest` 3, `Mk3HidMapParityTest` 3, `Mk3InputReportParityTest` 12). NOTE: gtest suite names are **singular** (`...ParityTest`, not `...Tests`); the `.cpp` filenames are plural.

```bash
build/maschinepi_tests_artefacts/Release/maschinepi_tests \
  --gtest_filter='Mk3DisplayParityTest.*:Mk3HidMapParityTest.*:Mk3InputReportParityTest.*'
```
Expected: PASS. This is the green baseline the rest of the phase must preserve.

- [x] **Step 4: No commit** (read-only baseline). `CANON_REF = 24c5cc0` recorded.

---

### Task 2: Audit the drift (canonical vs Mixxx vendored copy) — DONE

**Result (audit committed as `96262d8` in mixxx-mk3, `docs/libmk3-drift-audit.md`):** 948-line diff across 14 common driver files; `mk3.c` byte-identical; canonical is a **strict superset**. **Zero category-(b) genuine gaps** — every `mk3_` symbol Mixxx's C consumers use (17 total) resolves compatibly against canonical, so Task 3 is SKIPPED. Category-(a) Mixxx-side punch list for Task 5: (1) pad press/release now event-nibble-driven, not pressure-threshold — re-verify on hardware; (2) `micInGain`/`headphoneVolume`/`masterVolume` emit absolute 12-bit-masked deltas, not endless-encoder wrap; (3) LED value caps (63 brightness / 71 index) removed → raw pass-through; (4) `mk3_output_map.c` pad-LED addresses re-ordered HW→physical (p1→38 … p16→29), transparent to name-agnostic C callers; (5) `pedalConnected` bits moved `0x01/0x02`→`0x03/0x40`, `pedalSwitch` added. **Key finding:** Mixxx's mapping JS (`Native-Instruments-Maschine-MK3.js`) does NOT link the C driver — it drives HID via Mixxx's own `controller.send()` with private tables — so the C-side LED rename / pedal-bit moves force no JS change during the swap. All C consumers (`screen-daemon`, `mk3_cli`, `mk3_test`) are build-compatible.

Produce a concrete, per-file reconciliation report. **Direction of reconciliation: canonical (the DAW's libmk3) is authoritative — Mixxx conforms to it, not the reverse.** The public-API audit is already known (canonical is a superset: it adds `mk3_input_poll_ex`, `mk3_touchstrip_callback_t` + setter, and has `mk3_display_disable_partial_rendering`). This task identifies every place Mixxx's vendored copy diverges so we know exactly what Mixxx-side changes (screen-daemon, mapping JS, tooling) are needed to run on canonical.

**Files:**
- Read: `/home/zeb/dev/libmk3/*` (canonical)
- Read: `/home/zeb/dev/mixxx-mk3/external/mk3/*` (stale vendored)
- Create: `/home/zeb/dev/mixxx-mk3/docs/libmk3-drift-audit.md` (the report — deliverable)

**Interfaces:**
- Produces: `libmk3-drift-audit.md` classifying every divergence as one of:
  - **(a) canonical differs → adopt canonical.** Default outcome. If Mixxx code relied on the old behavior, that reliance is fixed *in Mixxx* (Task 5), not by changing canonical.
  - **(b) genuine gap → adapt Mixxx, or (rarely) port upstream.** Mixxx calls a symbol/behavior canonical doesn't provide. Preferred fix: change Mixxx to canonical's API (Task 5). Only port upstream into libmk3 (Task 3) if the capability is genuinely required *and* canonical has no equivalent — the exceptional case.
  - **(c) cosmetic/whitespace → ignore.**

- [x] **Step 1: Generate the full per-file diff**

```bash
CANON=/home/zeb/dev/libmk3
MIXXX=/home/zeb/dev/mixxx-mk3/external/mk3
for f in mk3.c mk3.h mk3_display.c mk3_display.h mk3_input.c mk3_input.h \
         mk3_input_map.c mk3_input_map.h mk3_internal.h \
         mk3_output.c mk3_output.h mk3_output_map.c mk3_output_map.h CMakeLists.txt; do
  echo "===== $f ====="; diff -u "$MIXXX/$f" "$CANON/$f"
done > /tmp/libmk3-drift.diff
wc -l /tmp/libmk3-drift.diff
```
Expected: a diff file (`-` lines = Mixxx, `+` lines = canonical).

- [x] **Step 2: Classify each divergence**

Read `/tmp/libmk3-drift.diff`. For each hunk, decide (a) adopt-canonical, (b) genuine-gap, or (c) cosmetic — remembering canonical wins by default. Pay special attention to the heavy files — `mk3_display.c` (~140 lines), `mk3_input.c` (~203), `mk3_output.c`/`mk3_output_map.c` (~88/43) — identifying behavior the Mixxx screen-daemon relies on that canonical changed or removed: display region/diffing behavior, RGB565 handling, input report parsing, and LED map names used by `mapping/Native-Instruments-Maschine-MK3.js`. Each such item becomes a Mixxx-side change in Task 5 (not a canonical change), unless it is a true (b) gap.

- [x] **Step 3: Cross-check Mixxx's actual libmk3 usage**

Confirm which symbols Mixxx actually calls, so the audit focuses on the real surface:
```bash
cd /home/zeb/dev/mixxx-mk3
grep -rn "mk3_" screen-daemon/ external/mpi-tools/ 2>/dev/null | grep -oE "mk3_[a-z_]+" | sort -u
```
Expected: a list of used symbols; verify each exists (compatibly) in canonical.

- [x] **Step 4: Write the audit report**

Write `/home/zeb/dev/mixxx-mk3/docs/libmk3-drift-audit.md` with a table: file → divergence class → action. Separate the two work streams: **(a) Mixxx-side changes** needed to run on canonical (feed Task 5) and **(b) genuine gaps** that need an upstream libmk3 port (feed Task 3). If no (b) gaps are found, state "no upstream ports required; Mixxx adapts to canonical" — the expected outcome.

- [x] **Step 5: Commit the audit (in mixxx-mk3)**

```bash
cd /home/zeb/dev/mixxx-mk3
git add docs/libmk3-drift-audit.md
git commit -m "docs: audit libmk3 drift vs canonical dkzeb/libmk3"
```

---

### Task 3: Port a genuine gap upstream into dkzeb/libmk3 (exceptional — usually skipped) — SKIPPED

**SKIPPED per Task 2 result:** the audit found zero category-(b) gaps (canonical is a strict superset for Mixxx's used surface). No upstream libmk3 port is needed; `CANON_REF` stays `24c5cc0`. Mixxx adapts to canonical in Task 5.

**Only** if Task 2 found a category-(b) genuine gap — a capability Mixxx truly requires that canonical lacks with no equivalent. This is the exception, not the norm: canonical is authoritative, so the default is that Mixxx conforms (Task 5), not that canonical grows to match Mixxx. If the audit found only (a)/(c) items, skip to Task 4 and note "no upstream ports; Mixxx adapts to canonical."

**Files:**
- Modify (in the canonical libmk3 checkout): `/home/zeb/dev/libmk3/<file(s) named by the audit>`
- Re-verify: mpi-te parity tests

**Interfaces:**
- Consumes: category-(b) list from `libmk3-drift-audit.md`.
- Produces: a new canonical libmk3 commit on `dkzeb/libmk3` that includes the ported behavior; this becomes the new `CANON_REF` for Task 4.

- [ ] **Step 1: Work on a feature branch of the standalone libmk3 clone**

```bash
cd /home/zeb/dev/libmk3
git checkout master && git checkout -b feat/mixxx-parity
```

- [ ] **Step 2: Apply each ported change**

For each category-(b) item in the audit, edit the named canonical file to add the behavior *additively* (preserve existing signatures; add new functions rather than changing old ones, matching how touchstrip/`poll_ex` were added). Keep C11 + `goto cleanup` conventions.

- [ ] **Step 2b: Commit + push the libmk3 feature branch**

```bash
cd /home/zeb/dev/libmk3
git add -A && git commit -m "feat: port Mixxx-required MK3 behavior for driver unification"
git push -u origin feat/mixxx-parity
FEAT_SHA=$(git rev-parse HEAD)   # commit under test
```

- [ ] **Step 3: Verify via mpi-te parity gate (point mpi-te's submodule at the feature commit)**

The parity tests live in mpi-te and build against *its* submodule, so bump that pin to the feature commit to test it:
```bash
cd /home/zeb/dev/mpi-te/external/mk3 && git fetch origin && git checkout "$FEAT_SHA" && cd /home/zeb/dev/mpi-te
./mpi build headless && \
build/maschinepi_tests_artefacts/Release/maschinepi_tests \
  --gtest_filter='Mk3DisplayParityTest.*:Mk3HidMapParityTest.*:Mk3InputReportParityTest.*'
```
Expected: PASS (ported changes must not break MaschinePI parity). If it fails, fix in `/home/zeb/dev/libmk3`, re-push, re-checkout, re-test.

- [ ] **Step 4: Merge the libmk3 PR, then bump mpi-te's pin to the merged ref**

Open + merge the PR on `dkzeb/libmk3`; record the merged master SHA as the new `CANON_REF`. Then pin mpi-te to it (a legitimate one-line mpi-te change — does not disturb mpi-te's in-flight source work):
```bash
cd /home/zeb/dev/libmk3 && git checkout master && git pull --ff-only origin master   # now at new CANON_REF
cd /home/zeb/dev/mpi-te/external/mk3 && git fetch origin && git checkout "$(cd /home/zeb/dev/libmk3 && git rev-parse master)"
cd /home/zeb/dev/mpi-te && git add external/mk3 && git commit -m "chore: bump libmk3 to unified ref"
```
(If no ports were needed, this whole task is skipped and `CANON_REF` stays as Task 1's SHA.)

---

### Task 4: Convert mixxx-mk3/external/mk3 from vendored copy to submodule — DONE

**Result (committed `1d9276c` on branch `agent/libmk3-unification`):** `external/mk3` is now a git submodule pinned to `CANON_REF` (`24c5cc0`); 14 vendored files removed (16 files changed, +4/-1233). `.gitmodules` points at `git@github.com:dkzeb/libmk3.git`. Committed with a plain (non-`-a`) commit so the unrelated MK1 `CMakeLists.txt` change stayed unstaged/untouched. `master` and MK1 work preserved. Not pushed.

Replace the pasted source with a real submodule pinned to `CANON_REF`.

**Files:**
- Delete: `/home/zeb/dev/mixxx-mk3/external/mk3/*` (the vendored copy)
- Create: `/home/zeb/dev/mixxx-mk3/.gitmodules`
- Modify: `/home/zeb/dev/mixxx-mk3/external/mk3` (now a submodule gitlink)

**Interfaces:**
- Consumes: `CANON_REF` (Task 1 or Task 3).
- Produces: `mixxx-mk3` with `external/mk3` as a submodule at `CANON_REF`.

- [x] **Step 1: Remove the vendored copy from git**

```bash
cd /home/zeb/dev/mixxx-mk3
git rm -r external/mk3
```

- [x] **Step 2: Add libmk3 as a submodule at the same path**

```bash
git submodule add git@github.com:dkzeb/libmk3.git external/mk3
cd external/mk3 && git checkout <CANON_REF> && cd ../..
git add .gitmodules external/mk3
```

- [x] **Step 3: Verify the pin**

```bash
git submodule status external/mk3
```
Expected: shows `external/mk3` pinned at `CANON_REF` (no `-`/`+` prefix once checked out).

- [x] **Step 4: Commit**

```bash
git commit -m "refactor: consume libmk3 as submodule instead of vendored copy"
```

---

### Task 5: Adapt Mixxx to canonical libmk3 + rebuild its tooling — DONE (build-verified; no source changes)

**Result:** Configure (`cmake -S . -B build -DCAPTURE_BACKEND=x11`) and build (`--target mk3-screen-daemon mk3_cli`) both **succeed against the submodule** — confirming the audit's finding that canonical is a strict superset and every C consumer is build-compatible with **zero source changes**. Step 0 required no C-side edits: the audit's category-(a) items are either behavioral (pad/knob semantics → hardware re-verify in Task 6) or JS-only (`Native-Instruments-Maschine-MK3.js` drives HID via Mixxx's own `controller.send()`, never linking the C driver). Both binaries built: `build/screen-daemon/mk3-screen-daemon`, `build/external/mpi-tools/mk3_cli/mk3_cli`. **No commit** — the only tracked working-tree diff is the user's unrelated MK1 `CMakeLists.txt` change (left untouched). Behavioral parity still pending hardware (Task 6).

**This is where "Mixxx conforms to canonical" happens.** Apply every (a) Mixxx-side change from the Task 2 audit — update `screen-daemon`, the mapping JS, and tooling so they build and behave correctly against canonical's API/behavior — then compile. Additive API changes (touchstrip, `poll_ex`) are backward-compatible; the real work is any place canonical *changed or removed* behavior the Mixxx side assumed (display diffing/RGB565, input parsing, LED map names). Canonical does not change to accommodate Mixxx.

**Files:**
- Read/Modify: `/home/zeb/dev/mixxx-mk3/CMakeLists.txt`, `/home/zeb/dev/mixxx-mk3/external/mk3/CMakeLists.txt`, `screen-daemon/*`, `external/mpi-tools/*`, and (if the audit flagged them) `mapping/Native-Instruments-Maschine-MK3.js` / other consumers.

**Interfaces:**
- Consumes: the submodule from Task 4 + the (a) Mixxx-side change list from the Task 2 audit.
- Produces: working `mk3-screen-daemon` + `mk3_cli` binaries built on, and behaviorally aligned with, canonical libmk3.

- [x] **Step 0: Apply the Mixxx-side changes from the audit**

For each (a) item in `libmk3-drift-audit.md`, edit the named Mixxx consumer to match canonical's API/behavior (e.g. renamed LED map names, changed display-diffing assumptions, input-report field shifts). These are the changes that make Mixxx work on the shared driver.

- [x] **Step 1: Confirm the Mixxx CMake references the submodule path**

```bash
cd /home/zeb/dev/mixxx-mk3
grep -rn "external/mk3\|libmk3\|add_subdirectory" CMakeLists.txt external/mk3/CMakeLists.txt
```
Expected: the build adds `external/mk3` (now the submodule) — path is unchanged, so this should already resolve. Fix the path if the vendored copy was referenced by a different mechanism.

- [x] **Step 2: Clean build the Mixxx MK3 tooling**

```bash
rm -rf build && mkdir build && cd build
cmake .. -DCAPTURE_BACKEND=x11
cmake --build . --target mk3-screen-daemon mk3_cli -j"$(nproc)"
```
Expected: builds succeed. A missing/renamed symbol is a drift item the audit should have caught — go back, apply the Mixxx-side fix (Step 0), and re-run. Adapt Mixxx to canonical; do not change canonical.

- [x] **Step 3: Commit the Mixxx-side conforming changes + build glue**

```bash
cd /home/zeb/dev/mixxx-mk3
git add CMakeLists.txt external/mk3/CMakeLists.txt screen-daemon external/mpi-tools mapping 2>/dev/null || true
git commit -m "refactor: conform Mixxx MK3 tooling to canonical libmk3" || echo "no changes to commit"
```

---

### Task 6: Hardware smoke verification (gated on MK3 access) — DONE (PASS)

**Result (2026-07-21, MK3 on USB `17cc:1600`; recorded in `mixxx-mk3` commit `e80d138`, `docs/libmk3-drift-audit.md` "Hardware verification" section):** Ran the Mixxx tooling built on the canonical submodule against real hardware. **PASS.** Display text (L/R) + color render + clear all exit 0 and visually confirmed by the user. Input (`mk3_test --input`): all 16 pads clean press+release — **presses at pressure 102/106/154 (well below the old 256 threshold) registered**, empirically confirming event-nibble pad detection (audit item a1); knobs k2–k8 report absolute 12-bit values + deltas (a2); 4D nav wheel 0–15 wrap + full button map (HID re-order a4 is name-compatible). LED output (`mk3_test --output`): mono + indexed LEDs incl. `color_index 65` on pad `p6` sent **unclamped** — confirms raw pass-through (a3) and physical pad-LED addressing (a4), user-confirmed visually. **Not exercised:** pedal bits (a5 — no pedal attached); touchstrip slide input (covered by mpi-te parity test); full screen-daemon+Xvfb (optional, deferred).

Compilation proves the API; this proves behavior on the device. Requires an MK3 plugged in. If no hardware is available, mark as blocked and hand off — do not fake it.

**Files:** none (runtime verification)

- [x] **Step 1: Verify canonical libmk3 drives the MK3 (via mpi-te or the Mixxx `mk3_cli`)**

```bash
# From the Mixxx build, render text to confirm display path:
/home/zeb/dev/mixxx-mk3/build/external/mpi-tools/mk3_cli/mk3_cli --text "unified" --target left
```
Expected: text appears on the MK3 left screen. Then confirm input:
```bash
/home/zeb/dev/mixxx-mk3/build/external/mpi-tools/mk3_test --input   # if built; press pads/knobs, observe events
```

- [x] **Step 2: Run the Mixxx screen-daemon end-to-end (optional, needs Xvfb+Mixxx)**

Boot the Mixxx setup and confirm the two MK3 screens mirror the display and controls are live, per `mk3-pi-setup.sh` boot sequence. Confirms no display-diffing/RGB565 regression from the driver swap.

- [x] **Step 3: Record results** in `libmk3-drift-audit.md` (append a "hardware verification" section: pass/fail per check).

---

### Task 7: Finalize — update Mixxx docs to reflect the submodule

**Files:**
- Modify: `/home/zeb/dev/mixxx-mk3/CLAUDE.md` (the `libmk3 (external/mk3/)` section now describes a submodule of `dkzeb/libmk3`, not in-tree source)

- [x] **Step 1: Update the CLAUDE.md libmk3 section**

Edit the `### libmk3 (external/mk3/)` section to state that `external/mk3` is a git submodule of `dkzeb/libmk3` (canonical, shared with MaschinePI), and that changes go upstream, not in-tree.

- [x] **Step 2: Commit**

```bash
cd /home/zeb/dev/mixxx-mk3
git add CLAUDE.md
git commit -m "docs: libmk3 is now a shared submodule of dkzeb/libmk3"
```

- [x] **Step 3: Phase-1 exit check**

**Status — Phase 1 COMPLETE:**
- ✅ mpi-te parity tests green (Task 1): 18/18 at `CANON_REF = 24c5cc0`.
- ✅ Submodule pinned at `CANON_REF` (Task 4): `mixxx-mk3` commit `1d9276c`, `external/mk3` → `dkzeb/libmk3@24c5cc0`.
- ✅ Mixxx tooling builds on the submodule (Task 5): `mk3-screen-daemon` + `mk3_cli` + `mk3_test` compile+link clean, zero source changes.
- ✅ Hardware smoke PASS (Task 6): display, pads (event-nibble, sub-256), knobs (absolute-delta), nav, buttons, LEDs (raw pass-through `color_index 65`) all verified on-device; recorded in commit `e80d138`. Only pedal bits (a5) unverified (no pedal).
- ✅ Docs updated (Task 7): `mixxx-mk3` commit `f349256`.

All commits are on `mixxx-mk3` branch `agent/libmk3-unification`, **pushed to `origin` (`dkzeb/mixxx-mk3`)**. The submodule pin `24c5cc0` is the canonical `dkzeb/libmk3` master HEAD, so a fresh `git submodule update --init` resolves to the canonical tip. mpi-te untouched (no submodule-pin bump needed: it already pins `24c5cc0`). **Phase 1 done → Phase 2 (integrator repo `mpi-station`) can begin.**

---

## Self-Review notes

- **Reconciliation direction:** canonical (the DAW's libmk3) is authoritative; Mixxx conforms to it. Divergences are fixed on the Mixxx side (Task 5) by default; porting upstream into libmk3 (Task 3) is the exceptional case, reserved for a genuine capability gap. This preserves the DAW's QA'd MK3 behavior (e.g. the correct indexed-LED passthrough already in canonical `24c5cc0`) as the single source of truth.
- **Spec coverage:** implements the spec's "libmk3 unification & cleanup (foundational)" section in full — canonicalize on `dkzeb/libmk3` (Task 1), audit drift (Task 2), exceptional upstream port (Task 3), convert Mixxx to submodule (Task 4), adapt Mixxx to canonical (Task 5), one libmk3 backs both (Tasks 5–6). Other spec sections are explicitly out of scope for this phase (see roadmap).
- **No unit-test-code steps** were fabricated: libmk3 correctness is verified by the *existing* mpi-te parity suite and by real builds/hardware, which is the established pattern here — not by inventing new GoogleTest cases for a C library that has none in-tree.
- **Conditional Task 3** is explicit about its skip condition to avoid a dangling "port TBD."
