# ota/ — generalized over-the-air update tooling (Phase 5)

The image is a seed, not the source of truth. The device carries on-device Git
checkouts (this integrator repository plus submodules) and updates in place via
`git pull`, with no reflash. This generalizes the existing Mixxx mechanism in
`external/mixxx-mk3/pi-setup/mk3-update.sh` and `mk3-check-update.sh`.

- OTA pulls the integrator repository, advancing pinned submodules together,
  then runs each mode's idempotent reprovision entrypoint.
- MaschinePI needs a new Mixxx-equivalent update entrypoint; it currently ships
  a pi-gen-baked binary with no OTA path.
- The pre-boot update check and prompt must work headlessly. Its render/input
  backend therefore needs to be swappable between libmk3 and Xvfb/zenity.
- The mode selector hosts the check and surfaces the update indicator.

See the design spec section “OTA updates (no reflash)”.
