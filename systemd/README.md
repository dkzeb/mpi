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
claims them) is validated here via `Conflicts=` and explicit ordering.

See the design spec sections “Systemd targets” and “Build / packaging”.
