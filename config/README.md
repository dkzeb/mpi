# config/ — mode config store (Phases 3–4)

A small file at `/var/lib/mk3-mode/config` holds:

- `default_mode` — the target name used when Shift is not held.
- A slot table mapping menu slot to target name and display label, so adding a
  third mode is a data change rather than a code change.

The selector reads it at boot. Until the Phase 4 hardware menu lands, use
`sudo mpi-mode-switch --set-default {maschinepi|mixxx}` to update it.

See the design spec section “Config store”.
