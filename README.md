# Slime

A touch slime toy for little kids on Android tablets (Fire tablets and Google Kids
Space tablets). A lump of slime on a table: press craters into it, drag it into strands,
pinch up ridges, pour in colours (they fall from the palette and splash) and swirl them
together like paint (yellow + blue makes green), pop the bubbles that rise under your finger, stamp stars and hearts, sprinkle
beads and stars, switch between ten slime kinds, slice it, and keep favourites in jars. First run walks through making the
slime: pour glue, pick a colour, pour activator, stir. No text, no ads, no internet.

**Controls (all icons):** right column = colours (tap to pour a drop, swirl to mix).
Left column = slime kind: shiny · clear · metal · cloud · crunchy · butter · fluffy ·
glow-in-the-dark (lights go off) · holographic · magic (colour changes as you knead).
Bottom row = new lump · bowl (make slime from scratch) · themes (ice cream, unicorn,
galaxy, rainbow, lemonade, mint: one tap sets colours, kind, add-ins and scent) · sparkle ·
beads · stars · star stamp · heart stamp · knife (drag to slice) · camera (saves to the
tablet's Pictures) · jars (shelf of six: tap an empty jar to save, a full one to reopen,
hold to overwrite) · scent (strawberry, lemon, blueberry, mint, chocolate, bubblegum: little
puffs rise where you touch). A wet kneading sound follows how fast you move. Works in
landscape and portrait; Android back closes overlays instead of quitting.

**First run** is a guided make-slime opening: a cartoon hand shows what to tap, the four
steps (glue, colour, activator, stir) are icons across the top, the colour bottles sit right
under the bowl, and a go button in the corner skips straight to a lump.

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
