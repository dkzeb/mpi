# mode-selector/ — the mk3-mode-selector binary (Phase 4)

The integrator-owned, mode-agnostic C binary:

- Owns the MK3 at boot via the `external/libmk3` submodule (render + input).
- Reads Shift (MK3 Shift or keyboard Shift via evdev) in a short poll window.
- If Shift is held, renders a menu on the MK3 screens; D1 = MaschinePI and
  D2 = Mixxx; the encoder scrolls; “set default” persists to the config store.
- Issues `systemctl isolate <target>` for the chosen mode.
- Surfaces an “update available” indicator (Phase 5) before either app starts.

It builds against `external/libmk3` directly, rather than MaschinePI's JUCE
layer, to stay small. It is invisible unless Shift is held and has no timeout
once summoned. D1/D2 activate their modes directly, the navigation encoder and
push select/activate, and D8 stores the highlighted mode as the next default.
Keyboard arrows, number keys, Enter, and D provide the equivalent bench path.

See the design spec sections “Boot flow” and “Mode selector UX (MK3)”.
