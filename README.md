# Slime

A touch slime toy for little kids on Android tablets (Fire tablets and Google Kids
Space tablets). Pick a colour, then squish, stretch, poke and smear the slime with
your fingers. No text, no ads, no internet.

- Godot 4.7 / GDScript. The slime is a lump on a table simulated as a thickness field on
  an 80x52 grid: fingers press (crater + displaced rim), smear (semi-Lagrangian advection
  along the stroke), pile and spread; a slow diffusion lets shapes soften over minutes and
  total slime is conserved. A canvas shader reconstructs the surface with a cubic
  B-spline and lights it from its slopes (diffuse, specular, rim, translucency, glitter).
- `PLAN.md` — the phase plan and store notes. `CLAUDE.md` — toolchain facts for this Mac.
- `docs/privacy.md` — privacy policy (nothing is collected).

```sh
make run-mac      # play on the Mac with the mouse
make emu-fire     # boot the Fire HD 10 class emulator
make run-fire     # export the APK, install and launch it
make run-device   # same, to a USB tablet with ADB enabled
```
