# Slime — Project Plan (creation to shipping)

## Status (updated 2026-10-24 — paused, app is live)

| Phase | State |
|---|---|
| 0 Toolchain | ✅ emulator, two AVDs, Godot 4.7.2 + templates, debug + release keystores |
| 1 Skeleton | ✅ repo, Makefile, presets, CLAUDE.md |
| 2 Slime | ✅ v2 **moldable lump** (thickness field): craters, strands, pinch ridges, spread thin; shapes persist and slowly slump; 60 fps on the Fire-class emulator |
| 3 Features | ✅ paint-style colour mixing (Kubelka-Munk), 10 kinds each with its own voice, pour animation, bubbles, beads/stars that sink, 4 stamps, knife, rolling pin, glue growth, 8-step undo, 6 themes, 6 scents, jar shelf, snapshot to Pictures, make-slime opening with hand cue, portrait + landscape |
| 3e Sound | ✅ layered synthesis over CC0 OpenGameArt recordings (`art/cc0/LICENSE.md`), stereo kneading bed, Slime bus |
| 4 Release prep | ✅ v1.0.0 / versionCode 2, icons, promo, 10 screenshots, privacy page, `store/checklist.md`; tested by Adam on an onn. kids tablet and installed on a Fire 7 (Fire OS 8) |
| 5 Amazon | ✅ **LIVE 2026-10-24** — "Squish! Slime for Kids" by DadBuilt Apps, free, Fire tablets, audience 0–12. Submitted 2026-10-18 |
| 5b Windows | ✅ `make export-windows` single-file exe (untested on real Windows; copied to Adam's USB stick 2026-10-19) |
| 6 Google Play | ⏳ **Closed test approved by Google 2026-10-27** (personal account, app created, listing + all declarations done, AAB v2 on the Alpha track, testers via Google Group `squish-tester@googlegroups.com`). Next: share group link + opt-in link → 12 testers × 14 days → Apply for production → Teacher Approved opt-in |
| 7 Growth | ⏳ `docs/launch-plan.md`. daddit forbids promotion (rule 3); use r/kindlefire, r/SideProject, r/godot, Common Sense Media submission, OT emails, friends' honest ratings |
| 8 Shop | ⏸ 99c unlock built and hidden (`store.gd`); decision: stay free, revisit only if installs justify a billing afternoon |

**Paused 2026-10-27.** Google approved the closed test the same day. Next: send `https://groups.google.com/g/squish-tester` plus the "Join on the web" link from the Testers tab to friends (and r/AndroidClosedTesting if short). Also due before production: refresh the store screenshots (current ones predate glue/knife/roller/undo).

See `store/listing.md` for the exact submission steps and listing text.


Written 2026-10-17. A touch slime toy for Adam's kids on Fire tablets (Amazon Kids) and
Android tablets running Google Kids Space. Pick a colour, then squish, stretch and poke the
slime with a finger.

Two decisions drive everything below:

1. **Engine: Godot 4.7 (brew cask).** Rythem is HaxeFlixel and its Android build needs the
   NDK 28 / hxcpp patches documented in Rythem's CLAUDE.md. Godot exports Android with no
   native compile step at all (prebuilt templates + Gradle), draws deformable polygons
   natively, and runs on this Mac's existing SDK + brew JDK 17. Same Android SDK, same
   `adb`, same emulator images work for both projects.
2. **Shipping is a store problem, not a build problem.** Kids profiles on both tablet
   families only show *store-installed* apps. Sideloaded APKs stay in the parent profile.
   So the plan ships to the Amazon Appstore (free account, no tester gate) and to Google
   Play (US$25 account, 12-tester/14-day closed test before production).

---

## Phase 0 — Toolchain (half a day)

What is already on this Mac (checked 2026-10-17):

| Piece | State |
|---|---|
| Apple M2, macOS 27 | arm64 — use `arm64-v8a` emulator images |
| `~/Library/Android/sdk` | platform-tools 37.0.1, build-tools 35.0.0, platforms android-35, NDK 28 |
| `openjdk@17` (brew) | installed, **not** on PATH / JAVA_HOME — `/opt/homebrew/opt/openjdk@17` |
| `sdkmanager`, `avdmanager` (brew `android-commandlinetools`) | work once JAVA_HOME is set |
| Emulator package, system images, AVDs | **none** — must install |
| Godot | not installed — `brew install --cask godot` (4.7.2) |

Steps:

1. Put the JDK and SDK on the shell env permanently (`~/.zshrc`):
   ```
   export JAVA_HOME=/opt/homebrew/opt/openjdk@17
   export ANDROID_HOME=$HOME/Library/Android/sdk
   export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
   ```
2. Install the emulator, cmdline-tools inside the SDK (Godot looks for them there), and
   two system images — a modern one and one matching Fire OS 8 (Android 11 / API 30):
   ```
   sdkmanager --sdk_root=$ANDROID_HOME "emulator" "cmdline-tools;latest" \
     "platforms;android-36" "build-tools;36.0.0" \
     "system-images;android-36;google_apis;arm64-v8a" \
     "system-images;android-30;google_apis;arm64-v8a"
   ```
3. Create two AVDs sized like the real tablets:
   - `slime-firehd10` — API 30, 1920×1200 @ 224 dpi, 3 GB RAM (Fire HD 10 2023)
   - `slime-kids-tab` — API 36, 10.1" tablet profile (Lenovo/Nokia Kids Space class)
   Fire HD 8 is 1280×800; test that resolution too via a third AVD or by resizing.
4. `brew install --cask godot`, open it once, Editor → Manage Export Templates → download
   the 4.7.2 templates. Editor Settings → Export → Android: set Java SDK path to
   `/opt/homebrew/opt/openjdk@17` and Android SDK path to `~/Library/Android/sdk`.
   Create the debug keystore Godot asks for.
5. Smoke test: export Godot's blank project as an APK, `adb install` it on
   `slime-firehd10`. Done when the grey Godot screen shows on the emulator.
6. Enable ADB on one real Fire tablet (Settings → Device Options → tap Serial Number 7×
   → Developer Options → Enable ADB) so real-device tests are one `adb install` away.

**Exit criteria:** `make run-fire` (emulator) and `make run-device` both launch an APK.

## Phase 1 — Project skeleton (1 day)

- `git init`, push to **H60Ninja** (personal account, per global CLAUDE.md). Repo name `Slime`.
- Godot project: landscape + portrait both allowed (kids rotate tablets), base
  resolution 1920×1080, stretch mode `canvas_items`, aspect `expand`.
- Package name `com.h60ninja.slime` (must be identical on both stores forever).
- `minSdk 30` (Fire OS 8 floor; drops Fire OS 7 devices from 2019 and earlier — if the
  kids have an older Fire, set `minSdk 28`), `targetSdk 36` (Google Play requirement after
  2026-08-31; Amazon only needs 30).
- Scenes: `Main` (colour picker overlay + slime), `Slime` (the sim), `ColorPicker`.
- `Makefile`: `run-mac`, `export-apk`, `run-fire`, `run-device`, `export-aab`.
- CLAUDE.md for the repo recording the toolchain facts above.

## Phase 2 — The slime (core, 1–2 weeks)

**Simulation: 2D mass-spring blob with pressure.** This is the standard "soft body" model
and is what makes slime feel like slime rather than a rubber ball.

- 48–64 point masses on a ring. Each point has position, previous position (Verlet
  integration — stable and cheap), and mass.
- Springs: neighbour-to-neighbour (shape), neighbour+2 (bending resistance), and
  every point to the centroid (keeps volume, weak). Tune stiffness low and damping
  high — that's the "goo" feel. Add a *rest-shape spring* that slowly pulls points back
  to a blob so it heals after being stretched (adjustable "stickiness").
- Pressure term: compute area each frame; push points outward along their normal
  proportional to (restArea − area). Stops it collapsing when squeezed.
- Fixed timestep 120 Hz, 2–4 sub-steps per frame, so behaviour is identical on a
  60 Hz Fire HD and a 90/120 Hz Google tablet.
- Table collision: the slime sits on an invisible floor with friction so it slumps.

**Touch ("molding"):**

- Multi-touch (`InputEventScreenTouch` / `ScreenDrag`); kids use two hands. Track up to
  5 fingers.
- A finger inside the blob is a soft circular obstacle: points within radius r are pushed
  out of the circle each sub-step (poke/dent). Dragging it drags material.
- A finger that *starts* on the edge grabs the 3 nearest points with a spring (stretch,
  pull). Release → points snap back with damping, wobble, heal.
- Pinch (two fingers): squeeze between two obstacles.
- Long-press anywhere outside: flatten/pat sound.

**Rendering:**

- Pass the ring through Catmull-Rom (or Chaikin ×2) to get a smooth outline, fill with
  `draw_polygon` / `Polygon2D`.
- Shader: base colour from picker, inner darker gradient, moving specular highlight,
  rim light, subtle translucency. Sparkle/glitter variant = noise + sparkle sprites
  masked by the polygon.
- Glossy "wet" look matters more than physics accuracy for kids — budget time for it.
- Optional later: drop shadow, little bubbles that pop when pressed.

**Audio (kid-essential):** squish, stretch, pop, splat — generated or CC0 (freesound).
Pitch-shift by deformation speed. Mute button.

**Performance target:** 60 fps on Fire HD 8 (MediaTek MT8169, 2 GB RAM). Profile on the
API 30 emulator *and* the real Fire — the emulator on M2 is far faster than the tablet.

**Exit criteria:** kids can play with one green blob on the Fire for 10 minutes without
it exploding, tearing, or freezing. (Watch them — that is the real test.)

## Phase 3 — Colour picker & toy features (1 week)

- Big, no-text UI: 10–12 colour buttons (ages 3–8 can't read; icons only).
- Custom colour: big hue wheel + brightness slider; "random" dice button.
- Styles: glossy / glitter / clear ("jelly") / metallic / glow-in-dark.
- Mix-ins: beads, foam balls, stars (sprites that ride on the surface).
- Reset button (new blob), sizes: small / medium / big.
- Persist last colour + style in `user://settings.cfg`.
- Everything is reversible and nothing can be "lost" — no save slots, no failure state.
- No text, no links, no ads, no network, no analytics. This is also what makes the
  Families-policy review trivial.

## Phase 4 — Polish & kid-proofing (3–5 days)

- Immersive fullscreen, keep screen awake while touching.
- Handle rotation and `MainLoop` pause/resume (home button) without losing the blob.
- 48 ms haptic tick on pop (optional; many Fire tablets have no vibrator — check first).
- Test on all three AVDs + the real tablets; test with the tablet in a case (edge touches).
- App icon (adaptive, 512 px), splash, store screenshots (Phase 5 needs 3+ per store).
- Privacy policy page (required by both stores even with zero data collection). Host as a
  GitHub Pages page in the repo: "Slime collects no data."

## Phase 5 — Shipping, Fire tablets (Amazon Appstore)

Why the store: Amazon Kids profiles only list apps installed from the Appstore on the
parent account. Sideloaded APKs are not shareable (2017 How-To-Geek workaround with a
microSD card and GoToApp exists but is a hack).

1. Create an Amazon developer account (free) — **personal account (H60Ninja email), not
   the Vehlo one.**
2. Developer Console → Add New App → Android. Upload the APK (Amazon takes APK, not AAB).
   Category: Games › Kids. Content rating questionnaire: "no violence, no ads, no data".
3. Device support: tick Fire tablets only (Fire TV not needed).
4. Target audience: declare child-directed. Amazon asks for a COPPA attestation.
5. Submit. Review is typically 1–3 days.
6. On each Fire tablet, parent profile: install from Appstore → Settings → Profiles &
   Family Library → child → Add Content → Games & Apps → toggle Slime on.
7. Updates: bump `versionCode`, upload new APK, kids get it automatically.

Pre-store testing on real Fire: plain `adb install` on the parent profile is fine for
verifying — just not for the kids' profile.

## Phase 6 — Shipping, Google tablets (Google Play → Kids Space)

Why the store: Kids Space's "Add more apps" is the Play Store under the child's Family
Link account. There is no supported way to surface a sideloaded APK inside Kids Space.

1. Google Play developer account, US$25, **personal account**. Verification needs ID and
   takes a few days. Register as an individual.
2. Play Console → create app → upload a signed **AAB** (Godot export preset: AAB, release
   keystore — back the keystore + password up somewhere permanent; losing it means a new
   package name forever).
3. **Closed test gate:** personal accounts created after Nov 2023 must run a closed test
   with ≥12 opted-in testers for 14 consecutive days before production access. Plan for
   this up front: a Google Group of family/friends with Gmail accounts; they install from
   the opt-in link and must actually open the app. Start this the day the Phase 2 build
   is stable — the clock can run while Phases 3–4 happen.
4. App content declarations: target audience *children (5 and under / 6–8)*, Families
   policy self-certification, Data safety "no data collected", privacy policy URL,
   content rating (IARC) questionnaire, ads = none. Target audience "children" means the
   app cannot use any SDK that isn't Families-certified — Godot with no plugins is fine.
5. Apply for production once the console unlocks it; release to production.
6. Optionally opt in to **Teacher Approved** so it appears in Kids Space's discovery. Not
   required: the parent can approve it from Family Link / the Kids Space parent menu
   regardless.
7. On the tablet: Kids Space → Parent Menu → Add more apps → search Slime → approve.

**Interim option for the Google tablets (before production access):** a parent-owned
account on the tablet can install the closed-test build, but Kids Space only shows apps
installed under the *child's* account, so this is for testing only. Whether a Family
Link child account can be added as a closed-test tester is undocumented — try it on day
one of the closed test; if it works, the kids get the app weeks earlier.

## Phase 7 — Maintenance

- Google raises the target API every August (36 now, 37 next year). One Godot upgrade +
  re-export per year keeps both stores happy.
- Keep a `CHANGELOG.md`; kid-requested features go in GitHub issues on H60Ninja/Slime.

---

## Suggested order & rough effort

| # | Phase | Effort | Blocks |
|---|---|---|---|
| 0 | Toolchain + emulators | ½ day | everything |
| 1 | Skeleton + repo | 1 day | 2 |
| 2 | Slime sim + rendering + touch | 1–2 weeks | 3, closed test |
| 6a | Open Play + Amazon accounts, start closed test | 1 hour + 14 days wall clock | 6 |
| 3 | Colours & styles | 1 week | 4 |
| 4 | Polish, kid-proofing, store assets | 3–5 days | 5, 6 |
| 5 | Amazon Appstore submit | 1 hour + review | — |
| 6 | Google Play production | 1 hour + review | closed test done |

Fire tablets can realistically have the app within ~3 weeks; Google tablets ~2 weeks after
that because of the 14-day test gate.

## Open questions for Adam

1. Which exact tablets? (Fire HD 8 vs 10, which year; which Google tablet.) Sets `minSdk`
   and the performance floor.
2. Ages of the kids — decides whether any text at all is allowed in the UI.
3. Do you have ~12 friends/family with Gmail willing to install a test build? If not, the
   Play route needs an organisation account (D-U-N-S number, exempt from the tester gate).
