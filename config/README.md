# config/ — mode config store (Phases 3–4)

A small file at `/var/lib/mk3-mode/config` holds:

- `default_mode` — the target name used when Shift is not held.
- A slot table mapping menu slot to target name and display label, so adding a
  third mode is a data change rather than a code change.

The selector reads it at boot; the “set default” menu action writes it.

See the design spec section “Config store”.
