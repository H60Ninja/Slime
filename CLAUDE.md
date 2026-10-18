# Slime

Touch slime toy for Adam's kids. Godot 4.7.2 (GDScript), Android only for now (Fire
tablets via Amazon Appstore, Google tablets via Play). Personal project: GitHub **H60Ninja**,
never the Vehlo account. See `PLAN.md` for the phase plan and store notes.

## Layout
- `game/` — the Godot project (`project.godot`). Scripts in `game/scripts/`, generated
  sounds in `game/assets/sfx/` (from `art/make_sfx.py`, stdlib only, deterministic).
- `build/` — exported APK/AAB (git-ignored).
- `game/android/` — Godot Gradle build template, 1.2 GB, git-ignored; `make android-template` reinstalls it (needed only for `make export-aab`).
- `store/` — listing text, submission steps, screenshots.
- `Makefile` — `run-mac`, `export-apk`, `emu-fire`, `emu-kids`, `install`, `run-fire`, `logs`.

## Toolchain on this Mac (set up 2026-10-17)
- Godot: `/Applications/Godot.app` (brew cask), export templates 4.7.2 installed.
- JDK 17: `/opt/homebrew/opt/openjdk@17` (not on PATH; Makefile sets JAVA_HOME).
- Android SDK `~/Library/Android/sdk`: platform-tools, build-tools 35/36, platforms 35/36,
  emulator, cmdline-tools, system images android-30 + android-36 (arm64 google_apis).
- AVDs: `slime-firehd10` (API 30 = Fire OS 8, 1920x1200) and `slime-kids-tab` (API 36).
- Debug keystore: `~/.android/debug.keystore` (standard public debug creds).
- Release keystore: `~/.android/slime-release.jks`, alias `slime`, password in the login Keychain (service `slime-release-keystore`); the Makefile passes it to Godot through `GODOT_ANDROID_KEYSTORE_RELEASE_*`. Back it up.
- Renderer is **gl_compatibility**: Vulkan fails in the emulator and is riskier on Fire GPUs.

## How the slime works (v2)
`game/scripts/slime.gd` holds an 80x52 `PackedFloat32Array` of thickness. Per physics tick each
finger runs `_press` (mass-conserving crater + rim) and `_smear` (backward advection within the
finger radius); `_relax` diffuses every 3rd tick; mass is renormalised every 4th tick. The field is
uploaded as a FORMAT_RF texture and `game/shaders/slime.gdshader` reconstructs it with a cubic
B-spline (16 texelFetch, no float-filtering dependency) and lights it. Feel knobs are the
`@export`s at the top of slime.gd: `press_rate`, `smear_strength`, `slump`, `finger_px`.

Colour lives in a second interleaved RGB float array `_c` (FORMAT_RGBF texture), advected
with the slime in `_smear` (thickness-weighted) and blended by `_mix`. `drop()` pours a colour
at the centroid; `stamp()` presses a star/heart polygon in. `scripts/addins.gd` holds beads and
stars that `advect`/`push_out` with the fingers. Styles are shader-uniform sets in
`Slime.STYLES`. `scripts/bubbles.gd` spawns/pops bubbles (hooked from the finger loop in slime.gd); `scripts/pour.gd` is the falling-drop animation main.gd spawns on a palette tap, calling `slime.drop()` on landing. UI buttons are drawn in code (`ui.gd` IconControl) — no image assets, no text.

## Rules
- No internet permission, no analytics, no ads, no text in the UI (kids may not read).
- `minSdk` 30 (Fire OS 8), `targetSdk` 36 (Google Play requirement from 2026-08-31).
- Package name `com.h60ninja.slime` — must never change once published.
