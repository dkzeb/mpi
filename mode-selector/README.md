# mode-selector/ — the mk3-mode-selector binary (Phase 4)

The integrator-owned, mode-agnostic C binary:

- Owns the MK3 at boot via the `external/libmk3` submodule (render + input).
- Renders the menu on every boot and keeps retrying until a cold MK3 enumerates.
- D1 = MusicPI and D2 = Mixxx; the encoder scrolls; “set default” persists
  to the config store.
- During first-boot storage preparation, renders milestone progress across both
  MK3 screens and releases the controller before the boot menu starts.
- Issues `systemctl isolate <target>` for the chosen mode.
- Surfaces an “update available” indicator (Phase 5) before either app starts.

It builds against `external/libmk3` directly, rather than MusicPI's JUCE
layer, to stay small. The menu has no timeout. D1/D2 activate their modes
directly, the navigation encoder and push select/activate, and D8 stores the
highlighted mode as the next default.
Keyboard arrows, number keys, Enter, and D provide the equivalent bench path.

See the design spec sections “Boot flow” and “Mode selector UX (MK3)”.
