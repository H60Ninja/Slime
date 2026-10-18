# Slime

A touch slime toy for little kids on Android tablets (Fire tablets and Google Kids
Space tablets). Pick a colour, then squish, stretch, poke and smear the slime with
your fingers. No text, no ads, no internet.

- Godot 4.7 / GDScript. The slime is a 64-point soft body (position-based dynamics with
  edge, bend, area and shape-memory constraints) rendered as layered smoothed polygons.
- `PLAN.md` — the phase plan and store notes. `CLAUDE.md` — toolchain facts for this Mac.
- `docs/privacy.md` — privacy policy (nothing is collected).

```sh
make run-mac      # play on the Mac with the mouse
make emu-fire     # boot the Fire HD 10 class emulator
make run-fire     # export the APK, install and launch it
make run-device   # same, to a USB tablet with ADB enabled
```
